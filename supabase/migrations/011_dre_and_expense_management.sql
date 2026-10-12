-- 011 — Classificação DRE, recorrência mensal e comprovantes privados.

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS dre_class text NOT NULL DEFAULT 'OPERATING_EXPENSE',
  ADD COLUMN IF NOT EXISTS receipt_path text,
  ADD COLUMN IF NOT EXISTS recurring_active boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recurrence_day smallint,
  ADD COLUMN IF NOT EXISTS recurrence_last_generated date,
  ADD COLUMN IF NOT EXISTS recurring_source_id uuid REFERENCES public.expenses (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS recurrence_month date;

UPDATE public.expenses
SET dre_class = CASE
  WHEN category = 'MATERIAIS' THEN 'VARIABLE_COST'
  WHEN category = 'IMPOSTOS' THEN 'TAX'
  WHEN category = 'EQUIPAMENTOS' THEN 'INVESTMENT'
  ELSE 'OPERATING_EXPENSE'
END
WHERE dre_class = 'OPERATING_EXPENSE';

ALTER TABLE public.expenses
  DROP CONSTRAINT IF EXISTS expenses_dre_class_valid;
ALTER TABLE public.expenses
  ADD CONSTRAINT expenses_dre_class_valid CHECK (
    dre_class IN ('VARIABLE_COST', 'OPERATING_EXPENSE', 'TAX', 'INVESTMENT')
  );

ALTER TABLE public.expenses
  DROP CONSTRAINT IF EXISTS expenses_recurrence_day_valid;
ALTER TABLE public.expenses
  ADD CONSTRAINT expenses_recurrence_day_valid CHECK (
    recurrence_day IS NULL OR recurrence_day BETWEEN 1 AND 31
  );

CREATE UNIQUE INDEX IF NOT EXISTS expenses_recurring_month_unique
  ON public.expenses (recurring_source_id, recurrence_month)
  WHERE recurring_source_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.materialize_recurring_expenses()
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  template public.expenses%ROWTYPE;
  month_cursor date;
  due_date date;
BEGIN
  FOR template IN
    SELECT *
    FROM public.expenses
    WHERE artist_id = auth.uid()
      AND recurring_active = true
      AND recurring_source_id IS NULL
  LOOP
    month_cursor := date_trunc(
      'month',
      COALESCE(template.recurrence_last_generated, template.expense_date)
    )::date + interval '1 month';

    WHILE month_cursor <= date_trunc('month', current_date)::date LOOP
      due_date := make_date(
        extract(year FROM month_cursor)::integer,
        extract(month FROM month_cursor)::integer,
        LEAST(
          COALESCE(template.recurrence_day, 1),
          extract(day FROM (month_cursor + interval '1 month - 1 day'))::integer
        )
      );

      INSERT INTO public.expenses (
        artist_id, description, category, dre_class, amount, expense_date,
        notes, recurring_source_id, recurrence_month
      ) VALUES (
        template.artist_id, template.description, template.category,
        template.dre_class, template.amount, due_date, template.notes,
        template.id, month_cursor
      )
      ON CONFLICT (recurring_source_id, recurrence_month)
        WHERE recurring_source_id IS NOT NULL DO NOTHING;

      month_cursor := (month_cursor + interval '1 month')::date;
    END LOOP;

    UPDATE public.expenses
    SET recurrence_last_generated = date_trunc('month', current_date)::date,
        updated_at = now()
    WHERE id = template.id AND artist_id = auth.uid();
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.materialize_recurring_expenses() TO authenticated;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'fiscal-documents',
  'fiscal-documents',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "fiscal_documents_upload_own" ON storage.objects;
CREATE POLICY "fiscal_documents_upload_own"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'fiscal-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "fiscal_documents_read_own" ON storage.objects;
CREATE POLICY "fiscal_documents_read_own"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'fiscal-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "fiscal_documents_delete_own" ON storage.objects;
CREATE POLICY "fiscal_documents_delete_own"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'fiscal-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
