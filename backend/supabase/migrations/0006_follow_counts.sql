-- Forge Loop — contadores públicos de seguidores/seguidos (para perfiles de otros).
-- RLS oculta las filas de follows ajenas, así que un RPC security-definer expone
-- solo los CONTADORES (info pública tipo Instagram), no las filas.

create or replace function public.follow_counts(uid uuid)
returns table (followers bigint, following bigint)
language sql stable security definer set search_path = public as $$
  select
    (select count(*) from public.follows where following_id = uid and status = 'accepted'),
    (select count(*) from public.follows where follower_id  = uid and status = 'accepted');
$$;

grant execute on function public.follow_counts(uuid) to anon, authenticated;
