-- Informações públicas adicionais do perfil profissional.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS bio text,
  ADD COLUMN IF NOT EXISTS experience_years integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS studio_name text,
  ADD COLUMN IF NOT EXISTS instagram text;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_experience_years_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_experience_years_check
  CHECK (experience_years >= 0 AND experience_years <= 80);

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
  p.portfolio_url,
  p.bio,
  p.experience_years,
  p.studio_name,
  p.instagram
FROM public.profiles p
WHERE p.role = 'ARTIST';

GRANT SELECT ON public.artist_directory TO authenticated;
