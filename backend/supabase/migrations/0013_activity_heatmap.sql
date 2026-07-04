-- Mapa de calor de actividad con PRIVACIDAD:
--  - El cliente sube solo una celda redondeada a 0,05° (~5 km), nunca coordenadas exactas.
--  - El RPC devuelve celdas AGREGADAS (celda → nº de usuarios activos en 30 días), sin ids.
alter table public.profiles add column if not exists geo_cell_lat double precision;
alter table public.profiles add column if not exists geo_cell_lon double precision;
alter table public.profiles add column if not exists active_at timestamptz;

create or replace function public.activity_heatmap()
returns table (cell_lat double precision, cell_lon double precision, users bigint)
language sql stable security definer set search_path = public as $$
  select geo_cell_lat, geo_cell_lon, count(*)::bigint
  from profiles
  where active_at > now() - interval '30 days'
    and geo_cell_lat is not null and geo_cell_lon is not null
  group by geo_cell_lat, geo_cell_lon;
$$;
revoke all on function public.activity_heatmap() from public, anon;
grant execute on function public.activity_heatmap() to authenticated;

create or replace function public.active_users_count()
returns bigint language sql stable security definer set search_path = public as $$
  select count(*)::bigint from profiles where active_at > now() - interval '30 days';
$$;
revoke all on function public.active_users_count() from public, anon;
grant execute on function public.active_users_count() to authenticated;
