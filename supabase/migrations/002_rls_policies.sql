-- ============================================================================
-- 002 — Controle de acesso (RLS) para profiles, messages e appointments
--
-- Execute no Supabase Dashboard -> SQL Editor, DEPOIS de 001_rf02_artist_profile.sql.
-- O script e idempotente: pode ser reexecutado sem efeitos colaterais.
--
-- Antes desta migration o banco nao tinha nenhuma policy versionada. O app
-- compensava filtrando dados no cliente (ex.: baixava a tabela `messages`
-- inteira e filtrava em Dart), o que expunha conversas e PII de todos os
-- usuarios a qualquer portador da anon key.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabelas auxiliares (defensivo: o schema original foi criado manualmente
--    pelo dashboard e nao existia em migration)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  content     text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.appointments (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id        uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  client_id        uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  client_name      text,
  date             date NOT NULL,
  time             time NOT NULL,
  end_time         time NOT NULL,
  style            text,
  price            numeric DEFAULT 0,
  status           text NOT NULL DEFAULT 'CONFIRMADO',
  anamnesis_status text NOT NULL DEFAULT 'pendente',
  reminder_enabled boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS client_id        uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS price            numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status           text DEFAULT 'CONFIRMADO',
  ADD COLUMN IF NOT EXISTS anamnesis_status text DEFAULT 'pendente',
  ADD COLUMN IF NOT EXISTS reminder_enabled boolean DEFAULT true;

-- Chave estavel da conversa, independente de quem enviou.
--
-- O realtime do Supabase so aceita um filtro de igualdade por stream, o que
-- tornava impossivel expressar "sender = eu OU receiver = eu" no servidor — dai
-- o filtro em Dart no codigo original. Com esta coluna gerada o app assina
-- exatamente uma conversa.
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS conversation_key text
  GENERATED ALWAYS AS (
    least(sender_id::text, receiver_id::text) || ':' ||
    greatest(sender_id::text, receiver_id::text)
  ) STORED;

CREATE INDEX IF NOT EXISTS messages_conversation_idx
  ON public.messages (sender_id, receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS messages_conversation_key_idx
  ON public.messages (conversation_key, created_at DESC);
CREATE INDEX IF NOT EXISTS appointments_artist_date_idx
  ON public.appointments (artist_id, date);
CREATE INDEX IF NOT EXISTS appointments_client_date_idx
  ON public.appointments (client_id, date);

-- ---------------------------------------------------------------------------
-- 2. profiles — cada usuario le e escreve apenas a propria linha
--
-- A vitrine publica de tatuadores NAO passa por esta tabela: usa a view
-- `artist_directory` (secao 3), que projeta somente colunas nao sensiveis.
-- Assim `cpf`, `date_of_birth`, `guardian_cpf` e `phone` deixam de ser
-- alcancaveis por outros usuarios mesmo via chamada direta na API REST.
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role IN ('CLIENT', 'ARTIST'));

-- `cpf` e `rating` sao imutaveis pelo cliente: CPF e identidade verificada no
-- cadastro e rating e derivado de avaliacoes, nao autodeclarado.
REVOKE UPDATE (cpf, rating) ON public.profiles FROM authenticated;

-- ---------------------------------------------------------------------------
-- 3. artist_directory — projecao publica e explicita dos tatuadores
--
-- SECURITY DEFINER (padrao de view no Postgres) e intencional aqui: a view e a
-- unica porta de entrada para dados de terceiros e ja lista, coluna a coluna,
-- exatamente o que pode ser divulgado.
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.artist_directory;
CREATE VIEW public.artist_directory AS
SELECT
  p.id,
  p.name,
  p.avatar_url,
  p.styles,
  p.city,
  p.state,
  p.rating,
  p.min_price,
  p.hourly_rate,
  p.portfolio_urls,
  p.portfolio_url
FROM public.profiles p
WHERE p.role = 'ARTIST';

GRANT SELECT ON public.artist_directory TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. chat_directory — nome e avatar de quem ja conversa com voce
--
-- A inbox precisa resolver o nome do interlocutor. Em vez de liberar leitura
-- de `profiles`, a view so revela contatos com quem existe historico de
-- mensagens envolvendo o usuario autenticado.
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.chat_directory;
CREATE VIEW public.chat_directory AS
SELECT DISTINCT
  p.id,
  p.name,
  p.avatar_url
FROM public.profiles p
JOIN public.messages m
  ON (m.sender_id = p.id AND m.receiver_id = auth.uid())
  OR (m.receiver_id = p.id AND m.sender_id = auth.uid());

GRANT SELECT ON public.chat_directory TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. messages — apenas remetente e destinatario
-- ---------------------------------------------------------------------------

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_participants" ON public.messages;
CREATE POLICY "messages_select_participants"
  ON public.messages FOR SELECT
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- WITH CHECK em sender_id impede forjar mensagem em nome de terceiro.
DROP POLICY IF EXISTS "messages_insert_as_sender" ON public.messages;
CREATE POLICY "messages_insert_as_sender"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = sender_id);

-- ---------------------------------------------------------------------------
-- 6. appointments — apenas o tatuador e o cliente da sessao
-- ---------------------------------------------------------------------------

ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "appointments_select_participants" ON public.appointments;
CREATE POLICY "appointments_select_participants"
  ON public.appointments FOR SELECT
  TO authenticated
  USING (auth.uid() = artist_id OR auth.uid() = client_id);

DROP POLICY IF EXISTS "appointments_insert_as_artist" ON public.appointments;
CREATE POLICY "appointments_insert_as_artist"
  ON public.appointments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = artist_id);

DROP POLICY IF EXISTS "appointments_update_as_artist" ON public.appointments;
CREATE POLICY "appointments_update_as_artist"
  ON public.appointments FOR UPDATE
  TO authenticated
  USING (auth.uid() = artist_id)
  WITH CHECK (auth.uid() = artist_id);

DROP POLICY IF EXISTS "appointments_delete_as_artist" ON public.appointments;
CREATE POLICY "appointments_delete_as_artist"
  ON public.appointments FOR DELETE
  TO authenticated
  USING (auth.uid() = artist_id);

-- ---------------------------------------------------------------------------
-- 7. Conflito de horario no servidor
--
-- A checagem de sobreposicao existia apenas no Dart, comparando a nova sessao
-- contra a lista ja carregada em memoria: duas gravacoes concorrentes passavam
-- pelas duas. Esta constraint torna o double booking impossivel no banco.
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE public.appointments
  DROP CONSTRAINT IF EXISTS appointments_no_overlap;

ALTER TABLE public.appointments
  ADD CONSTRAINT appointments_no_overlap
  EXCLUDE USING gist (
    artist_id WITH =,
    date WITH =,
    tsrange(date + time, date + end_time) WITH &&
  );

ALTER TABLE public.appointments
  DROP CONSTRAINT IF EXISTS appointments_time_order;

ALTER TABLE public.appointments
  ADD CONSTRAINT appointments_time_order CHECK (end_time > time);

-- ---------------------------------------------------------------------------
-- 8. Cadastro — CPF unico e fora do metadata editavel
--
-- Dois problemas do fluxo anterior:
--
-- 1. O app consultava `profiles` por CPF ANTES do login para avisar sobre
--    duplicidade. Com RLS ligado essa consulta passa a nao retornar nada — e e
--    exatamente esse o comportamento desejado, porque a consulta funcionava
--    como um oraculo: qualquer portador da anon key podia descobrir se um CPF
--    estava cadastrado. A deteccao agora vem do indice unico abaixo.
--
-- 2. CPF, data de nascimento e CPF do responsavel eram gravados em
--    `raw_user_meta_data`, que o proprio usuario altera com `updateUser`. O
--    trigger copia esses campos para `profiles` (onde o UPDATE ja esta
--    revogado) e em seguida os remove do metadata.
-- ---------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS profiles_cpf_key
  ON public.profiles (cpf)
  WHERE cpf IS NOT NULL;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, cpf, date_of_birth, guardian_cpf, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'name',
    NEW.raw_user_meta_data ->> 'cpf',
    NULLIF(NEW.raw_user_meta_data ->> 'date_of_birth', '')::date,
    NEW.raw_user_meta_data ->> 'guardian_cpf',
    'CLIENT'
  )
  ON CONFLICT (id) DO NOTHING;

  -- Sem os dados de identidade, o metadata volta a ser apenas cosmetico.
  UPDATE auth.users
     SET raw_user_meta_data =
           raw_user_meta_data - 'cpf' - 'guardian_cpf' - 'date_of_birth'
   WHERE id = NEW.id;

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    -- Mensagem estavel para o app traduzir; ver AuthRepository.parseDuplicateField.
    RAISE EXCEPTION 'cpf_already_registered' USING ERRCODE = '23505';
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
