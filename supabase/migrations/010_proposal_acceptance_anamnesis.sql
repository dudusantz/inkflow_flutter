-- Aceite de proposta: anamnese assinada + agendamento + evento no chat.
-- Tudo acontece na mesma transação para não existir proposta aceita sem sessão.

ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS proposal_id uuid REFERENCES public.messages (id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS appointments_proposal_id_key
  ON public.appointments (proposal_id)
  WHERE proposal_id IS NOT NULL;

-- O projeto remoto já possui `anamneses` para o fluxo legado de sessões.
-- Mantemos aquela tabela intacta e vinculamos o novo aceite diretamente ao agendamento.
CREATE TABLE IF NOT EXISTS public.appointment_anamneses (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id uuid NOT NULL UNIQUE REFERENCES public.appointments (id) ON DELETE CASCADE,
  artist_id      uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  client_id      uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  answers        jsonb NOT NULL,
  signature_name text NOT NULL,
  has_risk       boolean NOT NULL DEFAULT false,
  signed_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT appointment_anamneses_answers_object CHECK (jsonb_typeof(answers) = 'object'),
  CONSTRAINT appointment_anamneses_signature_present CHECK (length(trim(signature_name)) >= 3)
);

ALTER TABLE public.appointment_anamneses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "appointment_anamneses_select_participants" ON public.appointment_anamneses;
CREATE POLICY "appointment_anamneses_select_participants"
  ON public.appointment_anamneses FOR SELECT
  TO authenticated
  USING (auth.uid() = artist_id OR auth.uid() = client_id);

REVOKE ALL ON public.appointment_anamneses FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.appointment_anamneses FROM authenticated;
GRANT SELECT ON public.appointment_anamneses TO authenticated;

-- O evento de aceite só pode ser criado pela função transacional abaixo.
-- Isso impede um cliente modificado de marcar a proposta como aceita sem
-- enviar a anamnese e sem criar o agendamento.
DROP POLICY IF EXISTS "messages_insert_as_sender" ON public.messages;
CREATE POLICY "messages_insert_as_sender"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND content NOT LIKE '[INKFLOW_PROPOSAL_ACCEPTED]%'
  );

CREATE OR REPLACE FUNCTION public.accept_proposal_with_anamnesis(
  p_proposal_id uuid,
  p_answers jsonb,
  p_signature_name text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_client_id uuid := auth.uid();
  v_message public.messages%ROWTYPE;
  v_proposal jsonb;
  v_start_at timestamptz;
  v_local_start timestamp;
  v_local_end timestamp;
  v_duration_minutes integer;
  v_appointment_id uuid;
  v_client_name text;
  v_has_risk boolean;
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = 'P0001';
  END IF;
  IF p_answers IS NULL OR jsonb_typeof(p_answers) <> 'object' THEN
    RAISE EXCEPTION 'INVALID_ANAMNESIS' USING ERRCODE = 'P0001';
  END IF;
  IF jsonb_typeof(p_answers -> 'hasAllergies') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'usesMedication') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hasDisease') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'isPregnantOrBreastfeeding') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'usesAnticoagulants') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hasDiabetes') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hasHeartCondition') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hasBloodDisorder') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hasSkinCondition') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hasHealingIssue') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hasFaintingHistory') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'isImmunosuppressed') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(p_answers -> 'hadRecentProcedure') IS DISTINCT FROM 'boolean'
    OR p_answers ->> 'acceptedDeclaration' IS DISTINCT FROM 'true'
    OR (p_answers ->> 'hasAllergies' = 'true' AND trim(COALESCE(p_answers ->> 'allergies', '')) = '')
    OR (p_answers ->> 'usesMedication' = 'true' AND trim(COALESCE(p_answers ->> 'medications', '')) = '')
    OR (p_answers ->> 'hasDisease' = 'true' AND trim(COALESCE(p_answers ->> 'diseases', '')) = '')
    OR (p_answers ->> 'hasSkinCondition' = 'true' AND trim(COALESCE(p_answers ->> 'skinConditionDetails', '')) = '')
    OR (p_answers ->> 'hadRecentProcedure' = 'true' AND trim(COALESCE(p_answers ->> 'recentProcedureDetails', '')) = '')
    OR octet_length(p_answers::text) > 20000
  THEN
    RAISE EXCEPTION 'INVALID_ANAMNESIS' USING ERRCODE = 'P0001';
  END IF;
  v_has_risk := (p_answers ->> 'isPregnantOrBreastfeeding')::boolean
    OR (p_answers ->> 'usesAnticoagulants')::boolean
    OR (p_answers ->> 'hasDiabetes')::boolean
    OR (p_answers ->> 'hasHeartCondition')::boolean
    OR (p_answers ->> 'hasBloodDisorder')::boolean
    OR (p_answers ->> 'hasSkinCondition')::boolean
    OR (p_answers ->> 'hasHealingIssue')::boolean
    OR (p_answers ->> 'hasFaintingHistory')::boolean
    OR (p_answers ->> 'isImmunosuppressed')::boolean
    OR (p_answers ->> 'hadRecentProcedure')::boolean;
  IF p_signature_name IS NULL OR length(trim(p_signature_name)) < 3 THEN
    RAISE EXCEPTION 'INVALID_SIGNATURE' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_proposal_id::text, 0));

  SELECT * INTO v_message
  FROM public.messages
  WHERE id = p_proposal_id
    AND receiver_id = v_client_id
    AND content LIKE '[INKFLOW_PROPOSAL]%';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROPOSAL_NOT_FOUND' USING ERRCODE = 'P0001';
  END IF;

  SELECT id INTO v_appointment_id
  FROM public.appointments
  WHERE proposal_id = p_proposal_id
    AND client_id = v_client_id;
  IF FOUND THEN
    RETURN v_appointment_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.messages
    WHERE sender_id = v_message.sender_id
      AND receiver_id = v_message.receiver_id
      AND content = '[INKFLOW_PROPOSAL_CANCELLED]' || p_proposal_id::text
  ) OR EXISTS (
    SELECT 1 FROM public.messages
    WHERE sender_id = v_message.receiver_id
      AND receiver_id = v_message.sender_id
      AND content = '[INKFLOW_PROPOSAL_REJECTED]' || p_proposal_id::text
  ) THEN
    RAISE EXCEPTION 'PROPOSAL_UNAVAILABLE' USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    v_proposal := substring(
      v_message.content FROM length('[INKFLOW_PROPOSAL]') + 1
    )::jsonb;
    v_duration_minutes := COALESCE((v_proposal ->> 'durationMinutes')::integer, 60);
    v_start_at := COALESCE(
      (v_proposal ->> 'startsAt')::timestamptz,
      (
        (v_proposal ->> 'date')::date + (v_proposal ->> 'time')::time
      ) AT TIME ZONE 'America/Sao_Paulo'
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'INVALID_PROPOSAL' USING ERRCODE = 'P0001';
  END;

  IF v_duration_minutes < 15 OR v_duration_minutes > 720 THEN
    RAISE EXCEPTION 'INVALID_PROPOSAL_DURATION' USING ERRCODE = 'P0001';
  END IF;
  IF v_start_at <= now() THEN
    RAISE EXCEPTION 'PROPOSAL_EXPIRED' USING ERRCODE = 'P0001';
  END IF;

  v_local_start := v_start_at AT TIME ZONE 'America/Sao_Paulo';
  v_local_end := v_local_start + make_interval(mins => v_duration_minutes);
  IF v_local_start::date <> v_local_end::date THEN
    RAISE EXCEPTION 'INVALID_PROPOSAL_DURATION' USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(NULLIF(trim(name), ''), 'Cliente') INTO v_client_name
  FROM public.profiles
  WHERE id = v_client_id;

  INSERT INTO public.appointments (
    proposal_id,
    artist_id,
    client_id,
    client_name,
    date,
    time,
    end_time,
    style,
    price,
    status,
    anamnesis_status,
    reminder_enabled
  ) VALUES (
    p_proposal_id,
    v_message.sender_id,
    v_client_id,
    COALESCE(v_client_name, 'Cliente'),
    v_local_start::date,
    v_local_start::time,
    v_local_end::time,
    COALESCE(NULLIF(trim(v_proposal ->> 'service'), ''), 'Tatuagem'),
    COALESCE((v_proposal ->> 'amount')::numeric, 0),
    'CONFIRMADO',
    CASE WHEN v_has_risk THEN 'risco' ELSE 'ok' END,
    true
  )
  RETURNING id INTO v_appointment_id;

  INSERT INTO public.appointment_anamneses (
    appointment_id,
    artist_id,
    client_id,
    answers,
    signature_name,
    has_risk
  ) VALUES (
    v_appointment_id,
    v_message.sender_id,
    v_client_id,
    p_answers,
    trim(p_signature_name),
    v_has_risk
  );

  INSERT INTO public.messages (sender_id, receiver_id, content)
  VALUES (
    v_client_id,
    v_message.sender_id,
    '[INKFLOW_PROPOSAL_ACCEPTED]' || p_proposal_id::text
  );

  RETURN v_appointment_id;
EXCEPTION
  WHEN exclusion_violation THEN
    RAISE EXCEPTION 'APPOINTMENT_CONFLICT' USING ERRCODE = 'P0001';
END;
$$;

REVOKE ALL ON FUNCTION public.accept_proposal_with_anamnesis(uuid, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_proposal_with_anamnesis(uuid, jsonb, text) TO authenticated;
