-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Momentos: el perfil como identidad viva (2026-10-01)
--
-- Cada actividad compartida es un post LIGERO y editorial que extiende el perfil:
-- una foto o vídeo (siempre 4:5 en la app), título corto, tipo de actividad, zona,
-- cuándo fue y una nota breve opcional. Algunos se fijan como Highlights.
-- Un momento de HOY alimenta la etiqueta del Circle («SURF TODAY», «TRAINING TODAY»).
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.moments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  media       jsonb not null,                   -- un MediaItem: {kind, url, video_url, w, h}
  title       text not null check (char_length(trim(title)) between 1 and 60),
  activity    text not null,                    -- surf · gym · running · coffee · sunset…
  area        text,                             -- barrio (rawValue de Neighborhood)
  happened_at timestamptz not null default now(),
  note        text check (note is null or char_length(note) <= 140),
  pinned      boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists moments_user_idx on public.moments (user_id, happened_at desc);

alter table public.moments enable row level security;

drop policy if exists moments_select on public.moments;
create policy moments_select on public.moments for select to authenticated
  using (not public.is_blocked_pair(auth.uid(), user_id));
drop policy if exists moments_insert on public.moments;
create policy moments_insert on public.moments for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists moments_update on public.moments;
create policy moments_update on public.moments for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists moments_delete on public.moments;
create policy moments_delete on public.moments for delete to authenticated
  using (user_id = auth.uid());

-- Como mucho 6 Highlights por persona.
create or replace function public.moments_pin_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.pinned and (select count(*) from public.moments
                      where user_id = new.user_id and pinned and id <> new.id) >= 6 then
    raise exception 'up to 6 highlights' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;
drop trigger if exists moments_pin_limit on public.moments;
create trigger moments_pin_limit before insert or update of pinned on public.moments
  for each row execute function public.moments_pin_limit();

-- Actividad de HOY (día de Bali) de una persona, la más reciente.
create or replace function public.activity_today(uid uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select activity from public.moments
   where user_id = uid and (happened_at at time zone 'Asia/Makassar')::date = public.bali_today()
   order by happened_at desc limit 1
$$;
revoke all on function public.activity_today(uuid) from public, anon, authenticated;

-- La celda del Circle lleva la actividad de hoy; la etiqueta «hoy» va justo después
-- de JUST ARRIVED: es la prueba de que esa persona está viviendo Bali ahora.
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
  today     text := public.activity_today(p.id);
  badge     text;
begin
  select neighborhood into me_area from public.profiles where id = viewer;
  dist := case when p.show_distance then public.presence_distance_m(viewer, p.id) end;
  days_left := case when p.stay_kind = 'until' and p.stay_until is not null
                    then p.stay_until - public.bali_today() end;

  badge := case
    when p.arrived_at > now() - interval '3 days' then 'just_arrived'
    when today is not null then 'today'
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
    'activity_today', today,
    'days_left', days_left,
    'first_time', first_time
  );
end;
$$;
revoke all on function public.circle_card(public.profiles, uuid, boolean, boolean) from public, anon, authenticated;

-- La política no puede llamar a is_blocked_pair (revocada a propósito: no debe
-- revelar bloqueos). Envoltorio que solo responde «¿puedo ver a esta persona?».
create or replace function public.can_see_user(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$ select not public.is_blocked_pair(auth.uid(), target) $$;
revoke all on function public.can_see_user(uuid) from public, anon;
grant execute on function public.can_see_user(uuid) to authenticated;

drop policy if exists moments_select on public.moments;
create policy moments_select on public.moments for select to authenticated
  using (public.can_see_user(user_id));
