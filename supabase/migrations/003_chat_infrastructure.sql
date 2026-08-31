-- Estrutura mínima e segura para conversas em tempo real.
-- Idempotente: pode ser executada novamente sem duplicar policies ou índices.

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS conversation_key text
  GENERATED ALWAYS AS (
    least(sender_id::text, receiver_id::text) || ':' ||
    greatest(sender_id::text, receiver_id::text)
  ) STORED;

CREATE INDEX IF NOT EXISTS messages_conversation_key_idx
  ON public.messages (conversation_key, created_at DESC);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_participants" ON public.messages;
CREATE POLICY "messages_select_participants"
  ON public.messages FOR SELECT
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "messages_insert_as_sender" ON public.messages;
CREATE POLICY "messages_insert_as_sender"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE OR REPLACE VIEW public.chat_directory AS
SELECT DISTINCT
  p.id,
  p.name,
  p.avatar_url
FROM public.profiles AS p
JOIN public.messages AS m
  ON (m.sender_id = p.id AND m.receiver_id = auth.uid())
  OR (m.receiver_id = p.id AND m.sender_id = auth.uid());

GRANT SELECT ON public.chat_directory TO authenticated;

-- Garante atualizações posteriores via Realtime sem falhar se a tabela já
-- estiver adicionada à publicação.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END
$$;
