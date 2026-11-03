-- Push notifications, delivery log and automatic 24-hour reminders.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  endpoint    text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  p256dh      text NOT NULL,
  auth_key    text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS push_subscriptions_user_idx
  ON public.push_subscriptions (user_id);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_subscriptions_manage_own" ON public.push_subscriptions;
CREATE POLICY "push_subscriptions_manage_own"
  ON public.push_subscriptions FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.push_notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_key       text NOT NULL UNIQUE,
  user_id         uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  kind            text NOT NULL,
  title           text NOT NULL,
  body            text NOT NULL,
  route           text NOT NULL,
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'retry', 'sent', 'failed')),
  attempts        integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  sent_at         timestamptz,
  last_error      text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS push_notifications_pending_idx
  ON public.push_notifications (next_attempt_at)
  WHERE status IN ('pending', 'retry');

ALTER TABLE public.push_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_notifications FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.enqueue_message_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_kind text := 'message';
  v_title text := 'Nova mensagem';
  v_body text := 'Você recebeu uma nova mensagem no InkFlow.';
BEGIN
  IF NEW.content LIKE '[INKFLOW_PROPOSAL]%' THEN
    v_kind := 'proposal';
    v_title := 'Nova proposta';
    v_body := 'Você recebeu uma nova proposta de agendamento.';
  ELSIF NEW.content LIKE '[INKFLOW_PROPOSAL_ACCEPTED]%' THEN
    v_kind := 'proposal_accepted';
    v_title := 'Proposta aceita';
    v_body := 'O cliente aceitou a proposta e preencheu a anamnese.';
  ELSIF NEW.content LIKE '[INKFLOW_PROPOSAL_REJECTED]%' THEN
    v_kind := 'proposal_rejected';
    v_title := 'Proposta recusada';
    v_body := 'O cliente recusou a proposta.';
  ELSIF NEW.content LIKE '[INKFLOW_PROPOSAL_CANCELLED]%' THEN
    v_kind := 'proposal_cancelled';
    v_title := 'Proposta cancelada';
    v_body := 'A proposta não está mais disponível.';
  END IF;

  INSERT INTO public.push_notifications (
    event_key, user_id, kind, title, body, route
  ) VALUES (
    'message:' || NEW.id::text,
    NEW.receiver_id,
    v_kind,
    v_title,
    v_body,
    '/chat?contactId=' || NEW.sender_id::text
  ) ON CONFLICT (event_key) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS messages_enqueue_push ON public.messages;
CREATE TRIGGER messages_enqueue_push
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.enqueue_message_push();

CREATE OR REPLACE FUNCTION public.enqueue_due_appointment_reminders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count integer;
BEGIN
  INSERT INTO public.push_notifications (
    event_key, user_id, kind, title, body, route
  )
  SELECT
    'appointment:24h:' || a.id::text || ':' || a.client_id::text,
    a.client_id,
    'appointment_reminder',
    'Sua sessão é amanhã',
    COALESCE(NULLIF(trim(a.style), ''), 'Tatuagem') || ' às ' ||
      to_char(a.time, 'HH24:MI') || '.',
    '/schedule'
  FROM public.appointments a
  WHERE a.client_id IS NOT NULL
    AND a.reminder_enabled
    AND upper(a.status) = 'CONFIRMADO'
    AND (a.date + a.time) AT TIME ZONE 'America/Sao_Paulo'
        BETWEEN now() + interval '23 hours 59 minutes'
            AND now() + interval '24 hours 1 minute'
  ON CONFLICT (event_key) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_due_appointment_reminders() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enqueue_due_appointment_reminders() TO service_role;

-- The secret is generated inside Postgres and never committed to source.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets WHERE name = 'push_cron_secret'
  ) THEN
    PERFORM vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'push_cron_secret',
      'Authenticates the internal push worker'
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_push_cron_secret(p_secret text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, vault, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM vault.decrypted_secrets
    WHERE name = 'push_cron_secret'
      AND decrypted_secret = p_secret
  );
$$;

REVOKE ALL ON FUNCTION public.verify_push_cron_secret(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_push_cron_secret(text) TO service_role;

CREATE OR REPLACE FUNCTION public.invoke_push_worker()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, extensions, pg_temp
AS $$
DECLARE
  v_secret text;
BEGIN
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'push_cron_secret';

  PERFORM net.http_post(
    url := 'https://bqagftdpoaslqodcnlyu.supabase.co/functions/v1/process-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', v_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
END;
$$;

REVOKE ALL ON FUNCTION public.invoke_push_worker() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.run_push_cycle()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.enqueue_due_appointment_reminders();
  PERFORM public.invoke_push_worker();
END;
$$;

REVOKE ALL ON FUNCTION public.run_push_cycle() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.wake_push_worker()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.invoke_push_worker();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_notifications_wake_worker
  ON public.push_notifications;
CREATE TRIGGER push_notifications_wake_worker
  AFTER INSERT ON public.push_notifications
  FOR EACH STATEMENT EXECUTE FUNCTION public.wake_push_worker();

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'inkflow-push-worker') THEN
    PERFORM cron.unschedule('inkflow-push-worker');
  END IF;

  PERFORM cron.schedule(
    'inkflow-push-worker',
    '* * * * *',
    'SELECT public.run_push_cycle();'
  );
END;
$$;
