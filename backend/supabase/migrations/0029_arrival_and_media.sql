-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Llegada a Bali + fotos y vídeos (decisiones del 2026-09-30)
--
-- 1. Te puedes registrar desde cualquier sitio (con tu fecha de llegada), pero
--    hasta que tu UBICACIÓN confirme que estás en Bali:
--      · no apareces en el Circle de nadie;
--      · no puedes usar el Circle ni conectar ("Your circle opens when you land").
--    Al llegar, entras con la etiqueta JUST ARRIVED.
--    «Estar en Bali» = la app te ha situado dentro de Bali en los últimos 7 días.
-- 2. El perfil pasa a ser una galería densa: hasta 9 fotos, vídeos cortos o Live
--    Photos (`media`), con la foto de perfil aparte.
-- 3. El registro solo pide el nombre: si una app vieja o un fallo deja
--    `handle` vacío, el servidor pone uno interno (nunca se enseña).
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── Llegada ─────────────────────────────────────────────────────────────────
alter table public.profiles add column if not exists arrival_date    date;          -- declarada (antes de llegar)
alter table public.profiles add column if not exists arrived_at      timestamptz;   -- primera vez situado en Bali
alter table public.profiles add column if not exists last_in_bali_at timestamptz;   -- última vez situado en Bali

-- Caja que contiene Bali, Nusa Penida/Lembongan y las Gili no (están en Lombok).
create or replace function public.point_in_bali(lat double precision, lon double precision)
returns boolean
language sql
immutable
as $$ select lat between -8.90 and -8.05 and lon between 114.40 and 115.72 $$;

create or replace function public.is_in_bali(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select last_in_bali_at > now() - interval '7 days'
                     from public.profiles where id = uid), false)
$$;
revoke all on function public.is_in_bali(uuid) from public, anon, authenticated;

-- La presencia ya ajustaba la posición a ~110 m (0028); ahora además marca la llegada.
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
  if public.point_in_bali(lat, lon) then
    update public.profiles
       set active_at = now(), last_in_bali_at = now(), arrived_at = coalesce(arrived_at, now())
     where id = uid;
  else
    update public.profiles set active_at = now() where id = uid;
  end if;
end;
$$;

-- Mi estado para la app: ¿puedo entrar al Circle? Si no, cuándo llego.
create or replace function public.my_arrival()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'in_bali', public.is_in_bali(p.id),
    'arrival_date', p.arrival_date,
    'arrived_at', p.arrived_at
  ) from public.profiles p where p.id = auth.uid()
$$;
revoke all on function public.my_arrival() from public, anon;
grant execute on function public.my_arrival() to authenticated;

-- ─── Handle interno ──────────────────────────────────────────────────────────
create or replace function public.ensure_handle() returns trigger
language plpgsql as $$
begin
  if new.handle is null or trim(new.handle) = '' then
    new.handle := 'u-' || substr(md5(new.id::text || clock_timestamp()::text), 1, 10);
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_ensure_handle on public.profiles;
create trigger profiles_ensure_handle before insert or update of handle on public.profiles
  for each row execute function public.ensure_handle();

-- ─── Fotos y vídeos ──────────────────────────────────────────────────────────
-- [{ "kind": "photo" | "video" | "live", "url": "...", "video_url": "..." (live), "w": 1080, "h": 1350 }]
-- `w`/`h` sirven para la rejilla tipo Pinterest (alturas distintas sin descargar nada).
alter table public.profiles add column if not exists media jsonb;
alter table public.profiles drop constraint if exists profiles_media_max;
alter table public.profiles add constraint profiles_media_max
  check (media is null or (jsonb_typeof(media) = 'array' and jsonb_array_length(media) <= 9));
alter table public.profiles drop constraint if exists profiles_photos_max;
alter table public.profiles add constraint profiles_photos_max
  check (photos is null or cardinality(photos) <= 9);

-- Bucket propio para fotos y vídeos del perfil, con límites (50 MB; imagen o vídeo).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 52428800,
        array['image/jpeg','image/png','image/heic','video/mp4','video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public read media" on storage.objects;
create policy "public read media" on storage.objects for select using (bucket_id = 'media');
drop policy if exists "own write media" on storage.objects;
create policy "own write media" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "own update media" on storage.objects;
create policy "own update media" on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "own delete media" on storage.objects;
create policy "own delete media" on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);

-- ─── La tarjeta: sin entrenos, con galería ───────────────────────────────────
-- Fuera Gym Score, gimnasio y «momentos» (fotos de entrenos): la app ya no es de fitness.
create or replace function public.discover_card(p public.profiles, viewer_dates boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id, 'handle', p.handle, 'name', p.name, 'avatar_url', p.avatar_url,
    'bio', p.bio, 'sports', p.sports,
    'neighborhood', p.neighborhood, 'home_city', p.home_city, 'home_country', p.home_country,
    'stay_kind', p.stay_kind, 'stay_until', p.stay_until,
    'intents', case when viewer_dates then p.intents else array_remove(p.intents, 'dating') end,
    'photos', p.photos,
    'media', p.media
  )
$$;

-- JUST ARRIVED manda sobre el resto de etiquetas: es la novedad más fuerte.
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
    when p.arrived_at > now() - interval '3 days' then 'just_arrived'
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

-- Your Circle: solo si estás en Bali, y solo con gente que está en Bali.
-- Fuera del orden: Gym Score (ya no existe). Dentro: galería completa (perfil cuidado).
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
    return jsonb_build_object('day', d, 'position', 0, 'area', null, 'locked', false, 'profiles', '[]'::jsonb);
  end if;

  -- Aún no estás en Bali: el Circle se abre al llegar.
  if not public.is_in_bali(uid) then
    return jsonb_build_object('day', d, 'position', 0, 'area', me.neighborhood,
                              'locked', true, 'arrival_date', me.arrival_date, 'profiles', '[]'::jsonb);
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
        and public.is_in_bali(p.id)
        and (nullif(trim(p.bio), '') is not null or cardinality(p.sports) > 0)
        and not (p.stay_kind = 'until' and p.stay_until is not null and p.stay_until < d)
        and not public.is_blocked_pair(uid, p.id)
        and not public.are_connected(uid, p.id)
    ),
    scored as (
      select e.id, e.seen_recently,
        (case when e.dist is not null and e.dist < 1000 then 30
              when e.dist is not null and e.dist < 3000 then 22
              when e.dist is not null and e.dist < 10000 then 10
              when e.neighborhood is not null and e.neighborhood = me.neighborhood then 25
              when e.neighborhood = any(launch) then 10 else 0 end)
        + least(30, 10 * coalesce(cardinality(array(
              select unnest(e.sports) intersect select unnest(me.sports))), 0))
        + case when (case when viewer_dates then e.intents else array_remove(e.intents, 'dating') end)
                    && my_intents then 15 else 0 end
        -- Novedad: recién llegados a Bali, nuevos en el club o en tu zona.
        + case when e.arrived_at > now() - interval '3 days' then 15
               when e.created_at > now() - interval '7 days' then 12
               when e.area_since > now() - interval '7 days' and e.neighborhood = me.neighborhood then 8
               else 0 end
        + case when e.active_at > now() - interval '2 days' then 12
               when e.active_at > now() - interval '7 days' then 8
               else 3 end
        -- Perfil cuidado: con galería pesa más que con una sola foto.
        + least(8, 2 * coalesce(jsonb_array_length(e.media), cardinality(e.photos), 0))
        + (('x' || substr(md5(uid::text || e.id::text || d::text), 1, 6))::bit(24)::int % 10)
        -- Nunca: atractivo físico ni nada parecido.
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

  return jsonb_build_object('day', d, 'position', deck.position, 'area', me.neighborhood,
                            'locked', false, 'profiles', cards);
end;
$$;

-- El perfil ya no lleva señales de entreno.
create or replace function public.club_profile(target uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid          uuid := auth.uid();
  p            public.profiles;
  viewer_dates boolean;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  if public.is_blocked_pair(uid, target) then return null; end if;
  select * into p from public.profiles where id = target;
  if not found then return null; end if;
  viewer_dates := public.is_adult(uid)
    and exists (select 1 from public.profiles where id = uid and 'dating' = any(coalesce(intents, '{}')));
  return public.circle_card(p, uid, viewer_dates, false);
end;
$$;

-- Conectar exige estar en Bali (quien aún no ha llegado solo puede preparar su perfil).
create or replace function public.send_connection_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Solo lo que envía la propia persona (no afecta a scripts ni al servidor).
  if new.from_id = auth.uid() and not public.is_in_bali(new.from_id) then
    raise exception 'you can connect once you are in Bali' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;
drop trigger if exists connection_requests_in_bali on public.connection_requests;
create trigger connection_requests_in_bali before insert on public.connection_requests
  for each row execute function public.send_connection_guard();
