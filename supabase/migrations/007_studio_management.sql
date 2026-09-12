-- 007 — Gestão financeira e cadastro fiscal do estúdio
-- Execute depois de 006_artist_career_start_year.sql.

CREATE TABLE IF NOT EXISTS public.payments (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id      uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  appointment_id uuid REFERENCES public.appointments (id) ON DELETE SET NULL,
  description    text NOT NULL DEFAULT 'Pagamento de sessão',
  amount         numeric(12,2) NOT NULL CHECK (amount > 0),
  method         text NOT NULL CHECK (method IN ('PIX', 'DINHEIRO', 'CARTAO', 'TRANSFERENCIA', 'OUTRO')),
  status         text NOT NULL DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'PARCIAL', 'PAGO', 'ESTORNADO', 'CANCELADO')),
  paid_at        timestamptz,
  notes          text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expenses (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id    uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  description  text NOT NULL,
  category     text NOT NULL DEFAULT 'OUTROS',
  amount       numeric(12,2) NOT NULL CHECK (amount > 0),
  expense_date date NOT NULL DEFAULT current_date,
  notes        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.artist_fiscal_profiles (
  artist_id             uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  person_type           text NOT NULL DEFAULT 'PF' CHECK (person_type IN ('PF', 'PJ')),
  tax_id                text,
  legal_name            text,
  trade_name            text,
  municipal_registration text,
  fiscal_address        text,
  tax_rate              numeric(5,2) CHECK (tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 100)),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payments_artist_paid_at_idx
  ON public.payments (artist_id, paid_at DESC);
CREATE INDEX IF NOT EXISTS payments_appointment_idx
  ON public.payments (appointment_id);
CREATE INDEX IF NOT EXISTS expenses_artist_date_idx
  ON public.expenses (artist_id, expense_date DESC);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.artist_fiscal_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_artist_all" ON public.payments;
CREATE POLICY "payments_artist_all" ON public.payments
  FOR ALL TO authenticated
  USING (auth.uid() = artist_id)
  WITH CHECK (
    auth.uid() = artist_id
    AND (
      appointment_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.id = appointment_id AND a.artist_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "expenses_artist_all" ON public.expenses;
CREATE POLICY "expenses_artist_all" ON public.expenses
  FOR ALL TO authenticated
  USING (auth.uid() = artist_id)
  WITH CHECK (auth.uid() = artist_id);

DROP POLICY IF EXISTS "fiscal_profile_artist_all" ON public.artist_fiscal_profiles;
CREATE POLICY "fiscal_profile_artist_all" ON public.artist_fiscal_profiles
  FOR ALL TO authenticated
  USING (auth.uid() = artist_id)
  WITH CHECK (auth.uid() = artist_id);

REVOKE ALL ON public.payments FROM anon;
REVOKE ALL ON public.expenses FROM anon;
REVOKE ALL ON public.artist_fiscal_profiles FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expenses TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.artist_fiscal_profiles TO authenticated;
