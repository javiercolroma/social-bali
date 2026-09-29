-- ─────────────────────────────────────────────────────────────────────────────
-- CLUB SOCIAL · Fotos de la persona (ver PRODUCT.md, Fase 3)
--
-- Que se VEA quién hay detrás, sin convertirlo en un Tinder de fotos posadas:
--   · la foto de perfil manda;
--   · hasta 4 fotos OPCIONALES «haciendo lo que te gusta» (`photos`);
--   · y las fotos de sus últimos entrenos públicos («momentos»), que ya existen.
-- Los ficheros van al bucket `avatars`, en la carpeta del usuario (0002/0014).
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.profiles add column if not exists photos text[];
alter table public.profiles drop constraint if exists profiles_photos_max;
alter table public.profiles add constraint profiles_photos_max
  check (photos is null or cardinality(photos) <= 4);

-- La tarjeta de Descubrir lleva ahora las fotos y los «momentos»: las fotos de sus 3
-- últimos entrenos visibles para todos. Nunca de una cuenta privada (sus entrenos
-- solo los ve quien la sigue).
create or replace function public.discover_card(p public.profiles, viewer_dates boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id, 'handle', p.handle, 'name', p.name, 'avatar_url', p.avatar_url,
    'country', p.country, 'city', p.city, 'gym', p.gym, 'is_private', p.is_private,
    'gym_score', p.gym_score, 'bio', p.bio, 'sports', p.sports,
    'neighborhood', p.neighborhood, 'home_city', p.home_city, 'home_country', p.home_country,
    'stay_kind', p.stay_kind, 'stay_until', p.stay_until,
    'intents', case when viewer_dates then p.intents else array_remove(p.intents, 'dating') end,
    'photos', p.photos,
    'moments', case when p.is_private then null else (
      select array_agg(photo_url order by date desc)
        from (select s.photo_url, s.date from public.workout_sessions s
               where s.user_id = p.id and s.photo_url is not null and s.visibility = 'all'
               order by s.date desc limit 3) m) end
  )
$$;
