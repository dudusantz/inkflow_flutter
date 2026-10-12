-- 012 — Comprovantes privados para recebimentos.

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS receipt_path text;
