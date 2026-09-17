-- 008 — Dados complementares para documentos de serviço
ALTER TABLE public.artist_fiscal_profiles
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS postal_code text,
  ADD COLUMN IF NOT EXISTS default_service_description text,
  ADD COLUMN IF NOT EXISTS receipt_notes text;
