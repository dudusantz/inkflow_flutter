-- Guarda o ano de início da carreira para calcular a experiência dinamicamente.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS career_start_year integer;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_career_start_year_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_career_start_year_check
      CHECK (
        career_start_year IS NULL
        OR career_start_year BETWEEN 1950 AND 2100
      );
  END IF;
END $$;

CREATE OR REPLACE VIEW public.artist_directory AS
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
  p.instagram,
  p.career_start_year
FROM public.profiles p
WHERE p.role = 'ARTIST';

GRANT SELECT ON public.artist_directory TO authenticated;
