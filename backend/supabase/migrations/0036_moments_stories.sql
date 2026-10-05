-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Momentos como historias (2026-10-05)
--
-- Las fotos del perfil dicen QUIÉN eres; los Momentos, QUÉ estás haciendo ahora.
--   · Un Momento dura 24 h (como una historia). Si su autor lo fija («Keep on
--     profile», `pinned`), sigue en el perfil con anillo neutro.
--   · Ya no lleva título: actividad + lugar + texto corto opcional (`note`).
--   · Se registra quién ha visto cada Momento → anillo de color (sin ver, < 24 h)
--     o neutro (visto o antiguo).
--   · El Circle marca a quien tiene un Momento reciente sin ver (`moment_ring`).
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.moments alter column title drop not null;
alter table public.moments drop constraint if exists moments_title_check;
alter table public.moments add constraint moments_title_check check (title is null or char_length(trim(title)) <= 60);

create table if not exists public.moment_views (
  moment_id uuid not null references public.moments(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (moment_id, viewer_id)
);
alter table public.moment_views enable row level security;
drop policy if exists moment_views_own on public.moment_views;
create policy moment_views_own on public.moment_views for all to authenticated
  using (viewer_id = auth.uid()) with check (viewer_id = auth.uid());

-- Los Momentos visibles de una persona: últimos 24 h + los fijados, con «visto» para mí.
create or replace function public.moments_of(target uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', m.id, 'user_id', m.user_id, 'media', m.media, 'title', m.title,
           'activity', m.activity, 'area', m.area, 'happened_at', m.created_at,
           'note', m.note, 'pinned', m.pinned,
           'viewed', exists (select 1 from public.moment_views v where v.moment_id = m.id and v.viewer_id = auth.uid())
         ) order by m.created_at asc), '[]'::jsonb)
    from public.moments m
   where m.user_id = target
     and public.can_see_user(target)
     and (m.created_at > now() - interval '24 hours' or m.pinned)
$$;
revoke all on function public.moments_of(uuid) from public, anon;
grant execute on function public.moments_of(uuid) to authenticated;

create or replace function public.mark_moment_viewed(moment uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.moment_views (moment_id, viewer_id) values (moment, auth.uid())
  on conflict do nothing
$$;
revoke all on function public.mark_moment_viewed(uuid) from public, anon;
grant execute on function public.mark_moment_viewed(uuid) to authenticated;

-- Anillo en el Circle: 'unseen' (hay un Momento de < 24 h que no he visto), 'seen' o null.
create or replace function public.moment_ring(target uuid, viewer uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when not exists (select 1 from public.moments where user_id = target and created_at > now() - interval '24 hours') then null
    when exists (select 1 from public.moments m where m.user_id = target and m.created_at > now() - interval '24 hours'
                   and not exists (select 1 from public.moment_views v where v.moment_id = m.id and v.viewer_id = viewer)) then 'unseen'
    else 'seen'
  end
$$;
revoke all on function public.moment_ring(uuid, uuid) from public, anon, authenticated;

-- «Hoy» = un Momento de las últimas 24 h (antes: el día natural de Bali).
create or replace function public.activity_today(uid uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select activity from public.moments
   where user_id = uid and created_at > now() - interval '24 hours'
   order by created_at desc limit 1
$$;
revoke all on function public.activity_today(uuid) from public, anon, authenticated;

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
    'moment_ring', public.moment_ring(p.id, viewer),
    'days_left', days_left,
    'first_time', first_time
  );
end;
$$;
revoke all on function public.circle_card(public.profiles, uuid, boolean, boolean) from public, anon, authenticated;
