-- ─────────────────────────────────────────────────────────────────────────────
-- CLUB SOCIAL · Your Circle (ver PRODUCT.md)
--
-- El Discover pasa a ser una REJILLA de 12-15 personas al día con sensación de
-- proximidad: distancia («80 m», «1,2 km»), «online» y señales de novedad (NEW,
-- NEW IN CANGGU, HERE FOR 2 WEEKS).
--
-- Decisiones (2026-09-30):
--   · Se enseña la distancia, NUNCA un pin ni coordenadas.
--   · «Online» = tiene la app abierta ahora. Cada persona puede desactivar su
--     distancia y su online (`show_distance`, `show_online`).
--
-- Privacidad de la ubicación (lo que le costó caro a Grindr: trilateración):
--   1. La posición se AJUSTA en el servidor a una cuadrícula de 0,001° (~110 m)
--      antes de guardarse. Redondear solo la distancia no basta: con tres medidas
--      desde sitios distintos se triangula el punto exacto. Ajustando la posición,
--      lo máximo que se averigua es la celda.
--   2. `presence` no tiene NINGUNA política de lectura: ningún cliente lee
--      coordenadas, ni las suyas. La distancia la calcula `your_circle()` y solo
--      devuelve un número.
--   3. Solo se actualiza con la app abierta (permiso «When In Use»).
--
-- El mazo sigue siendo DIARIO (quién está en tu Circle hoy no cambia al moverte);
-- la distancia y el online se recalculan en cada carga.
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── Presencia (privada) ─────────────────────────────────────────────────────
create table if not exists public.presence (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  lat          double precision,   -- ya ajustada a la cuadrícula; null = sin ubicación
  lon          double precision,
  located_at   timestamptz,
  last_seen_at timestamptz not null default now()
);
alter table public.presence enable row level security;
-- Sin políticas: solo se escribe y se lee a través de las funciones de abajo.

-- ─── Preferencias de privacidad y llegada a la zona ─────────────────────────
alter table public.profiles add column if not exists show_distance boolean not null default true;
alter table public.profiles add column if not exists show_online   boolean not null default true;
-- Desde cuándo está en su barrio actual: alimenta «NEW IN CANGGU».
alter table public.profiles add column if not exists area_since timestamptz;

create or replace function public.touch_area_since() returns trigger
language plpgsql as $$
begin
  if new.neighborhood is distinct from (case when tg_op = 'UPDATE' then old.neighborhood end) then
    new.area_since := case when new.neighborhood is null then null else now() end;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_area_since on public.profiles;
create trigger profiles_area_since
  before insert or update of neighborhood on public.profiles
  for each row execute function public.touch_area_since();

-- Perfiles que ya tenían barrio: no son «nuevos en la zona».
update public.profiles set area_since = created_at
 where neighborhood is not null and area_since is null;

-- ─── Escritura de presencia ──────────────────────────────────────────────────
-- Con ubicación (al abrir la app y al moverse con ella abierta).
create or replace function public.update_presence(lat double precision, lon double precision)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  step constant double precision := 0.001;   -- ~110 m
begin
  if uid is null then raise exception 'not authenticated'; end if;
  if lat is null or lon is null or abs(lat) > 90 or abs(lon) > 180 then
    raise exception 'invalid coordinates';
  end if;
  insert into public.presence (user_id, lat, lon, located_at, last_seen_at)
    values (uid, round(lat / step) * step, round(lon / step) * step, now(), now())
    on conflict (user_id) do update
      set lat = excluded.lat, lon = excluded.lon, located_at = now(), last_seen_at = now();
  update public.profiles set active_at = now() where id = uid;
end;
$$;

-- Sin ubicación: «sigo aquí» para el online (latido con la app abierta).
create or replace function public.heartbeat()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not authenticated'; end if;
  insert into public.presence (user_id, last_seen_at) values (uid, now())
    on conflict (user_id) do update set last_seen_at = now();
  update public.profiles set active_at = now() where id = uid;
end;
$$;

-- Al pasar a segundo plano: deja de salir online al momento, sin esperar 5 minutos.
create or replace function public.go_offline()
returns void
language sql
security definer
set search_path = public
as $$
  update public.presence set last_seen_at = now() - interval '10 minutes'
   where user_id = auth.uid();
$$;

-- ─── Lectura derivada (nunca coordenadas) ────────────────────────────────────
-- Distancia en metros entre dos personas, redondeada: 50 m por debajo de 1 km,
-- 100 m por encima. null si falta la ubicación de alguna o es de hace > 24 h.
create or replace function public.presence_distance_m(a uuid, b uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select case
    when d < 1000 then greatest(50, (round(d / 50) * 50)::int)
    else (round(d / 100) * 100)::int
  end
  from (
    select 2 * 6371000 * asin(sqrt(
             power(sin(radians(pb.lat - pa.lat) / 2), 2)
             + cos(radians(pa.lat)) * cos(radians(pb.lat)) * power(sin(radians(pb.lon - pa.lon) / 2), 2)
           )) as d
      from public.presence pa, public.presence pb
     where pa.user_id = a and pb.user_id = b
       and pa.lat is not null and pb.lat is not null
       and pa.located_at > now() - interval '24 hours'
       and pb.located_at > now() - interval '24 hours'
  ) x
$$;

create or replace function public.is_online(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select last_seen_at > now() - interval '5 minutes'
                     from public.presence where user_id = uid), false)
$$;

-- Edad (número), sin exponer la fecha de nacimiento.
create or replace function public.age_of(uid uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select extract(year from age(current_date, birthdate))::int
    from public.profile_private where id = uid and birthdate is not null
$$;

revoke all on function public.presence_distance_m(uuid, uuid) from public, anon, authenticated;
revoke all on function public.is_online(uuid) from public, anon, authenticated;
revoke all on function public.age_of(uuid) from public, anon, authenticated;

-- ─── La celda de la rejilla ──────────────────────────────────────────────────
-- Igual que `discover_card` (0027) + edad, distancia, online e indicador.
-- `badge` (uno solo, por prioridad): new · new_in_area · leaving · nearby · null.
-- `first_time`: es la primera vez que aparece en TU Circle (para «4 new»).
create or replace function public.circle_card(p public.profiles, viewer uuid, viewer_dates boolean, first_time boolean)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me_area   text;
  dist      int;
  days_left int;
  badge     text;
begin
  select neighborhood into me_area from public.profiles where id = viewer;
  dist := case when p.show_distance then public.presence_distance_m(viewer, p.id) end;
  days_left := case when p.stay_kind = 'until' and p.stay_until is not null
                    then p.stay_until - public.bali_today() end;

  badge := case
    when p.created_at > now() - interval '7 days' then 'new'
    when p.area_since > now() - interval '7 days' and p.neighborhood = me_area then 'new_in_area'
    when days_left between 0 and 20 then 'leaving'
    when dist is not null and dist < 1000 then 'nearby'
  end;

  return public.discover_card(p, viewer_dates) || jsonb_build_object(
    'age', public.age_of(p.id),
    'distance_m', dist,
    'online', p.show_online and public.is_online(p.id),
    'badge', badge,
    'days_left', days_left,
    'first_time', first_time
  );
end;
$$;
revoke all on function public.circle_card(public.profiles, uuid, boolean, boolean) from public, anon, authenticated;

-- ─── Your Circle ─────────────────────────────────────────────────────────────
-- Evolución de `todays_people()` (que se queda para las builds viejas):
--   · la proximidad real entra en el orden;
--   · «ya conectados» se mira en `connection_requests` (0026). `todays_people`
--     miraba `follows`, así que podía proponerte a alguien con quien ya conectaste.
create or replace function public.your_circle()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid          uuid := auth.uid();
  d            date := public.bali_today();
  me           public.profiles;
  viewer_dates boolean;
  my_intents   text[];
  launch       text[] := array['canggu','berawa','pererenan','uluwatu','bingin','pecatu'];
  deck         public.discover_decks;
  ids          uuid[];
  cards        jsonb;
begin
  if uid is null then raise exception 'not authenticated'; end if;

  select * into me from public.profiles where id = uid;
  if not found then
    return jsonb_build_object('day', d, 'position', 0, 'area', null, 'profiles', '[]'::jsonb);
  end if;

  viewer_dates := 'dating' = any(coalesce(me.intents, '{}')) and public.is_adult(uid);
  my_intents := case when viewer_dates then coalesce(me.intents, '{}')
                     else array_remove(coalesce(me.intents, '{}'), 'dating') end;

  select * into deck from public.discover_decks where user_id = uid and day = d;

  if not found then
    with eligible as (
      select p.*,
        exists (select 1 from public.discover_decks dd
                 where dd.user_id = uid and dd.day > d - 14 and p.id = any(dd.profile_ids)) as seen_recently,
        public.presence_distance_m(uid, p.id) as dist
      from public.profiles p
      where p.id <> uid
        and p.handle is not null
        and (nullif(trim(p.bio), '') is not null or cardinality(p.sports) > 0)
        and not (p.stay_kind = 'until' and p.stay_until is not null and p.stay_until < d)
        and not public.is_blocked_pair(uid, p.id)
        and not public.are_connected(uid, p.id)
    ),
    scored as (
      select e.id, e.seen_recently,
        -- Cerca de verdad (si hay ubicación de los dos); si no, el barrio declarado.
        (case when e.dist is not null and e.dist < 1000 then 30
              when e.dist is not null and e.dist < 3000 then 22
              when e.dist is not null and e.dist < 10000 then 10
              when e.neighborhood is not null and e.neighborhood = me.neighborhood then 25
              when e.neighborhood = any(launch) then 10 else 0 end)
        + least(30, 10 * coalesce(cardinality(array(
              select unnest(e.sports) intersect select unnest(me.sports))), 0))
        + case when (case when viewer_dates then e.intents else array_remove(e.intents, 'dating') end)
                    && my_intents then 15 else 0 end
        -- Gente nueva en la comunidad o recién llegada a tu zona (novedad = razón para volver).
        + case when e.created_at > now() - interval '7 days' then 12
               when e.area_since > now() - interval '7 days' and e.neighborhood = me.neighborhood then 8
               else 0 end
        + case when e.active_at > now() - interval '2 days' then 12
               when e.active_at > now() - interval '7 days' then 8
               when e.active_at > now() - interval '30 days' then 3 else 0 end
        + least(10, coalesce(e.gym_score, 0) / 10)
        + (('x' || substr(md5(uid::text || e.id::text || d::text), 1, 6))::bit(24)::int % 10)
        -- Nunca: atractivo físico ni nada parecido (principio 8).
        as score
      from eligible e
    )
    select coalesce(array_agg(id order by seen_recently, score desc, id), '{}') into ids
      from (select id, seen_recently, score from scored
             order by seen_recently, score desc, id limit 15) top;

    insert into public.discover_decks(user_id, day, profile_ids)
      values (uid, d, ids)
      on conflict (user_id, day) do nothing;
    select * into deck from public.discover_decks where user_id = uid and day = d;
  end if;

  select coalesce(jsonb_agg(
           public.circle_card(p, uid, viewer_dates,
             not exists (select 1 from public.discover_decks dd
                          where dd.user_id = uid and dd.day < d and p.id = any(dd.profile_ids)))
           order by t.ord), '[]'::jsonb)
    into cards
    from unnest(deck.profile_ids) with ordinality as t(pid, ord)
    join public.profiles p on p.id = t.pid
   where not public.is_blocked_pair(uid, p.id);

  return jsonb_build_object(
    'day', d,
    'position', deck.position,
    'area', me.neighborhood,
    'profiles', cards
  );
end;
$$;

-- La privacidad propia se edita desde la app (update de `profiles`, ya con RLS).

revoke all on function public.update_presence(double precision, double precision) from public, anon;
revoke all on function public.heartbeat() from public, anon;
revoke all on function public.go_offline() from public, anon;
revoke all on function public.your_circle() from public, anon;
grant execute on function public.update_presence(double precision, double precision) to authenticated;
grant execute on function public.heartbeat() to authenticated;
grant execute on function public.go_offline() to authenticated;
grant execute on function public.your_circle() to authenticated;
