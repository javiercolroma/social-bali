-- Forge Loop — esquema inicial del backend (Supabase / Postgres)
-- Ejecuta este archivo en el SQL Editor de tu proyecto Supabase (o vía CLI).
-- Diseñado para reemplazar los datos demo/bots locales por usuarios reales.
--
-- Modelo: perfiles (1:1 con auth.users) · follows estilo Instagram (con solicitudes)
--         · sesiones de entreno · stats de jugador (para ranking/liga) · likes · comentarios.

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────────
-- PERFILES  (identidad pública; 1:1 con auth.users)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  handle      text unique,
  name        text,
  avatar_url  text,
  sex         text,
  birthdate   date,
  country     text,
  city        text,
  gym         text,
  is_private  boolean not null default false,
  instagram   text,
  tiktok      text,
  twitter     text,
  goal        text,
  level       text,
  weekly_days text,
  motivation  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- FOLLOWS  (seguir/solicitud; cuentas privadas requieren aceptación)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.follows (
  follower_id  uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  status       text not null default 'accepted' check (status in ('pending','accepted')),
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create index if not exists follows_following_idx on public.follows (following_id, status);

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIONES DE ENTRENO  (feed real + insumo del ranking)
--   items = jsonb con [SessionExercise] (mismo shape que el modelo Swift)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.workout_sessions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  name       text not null,
  note       text,
  date       timestamptz not null default now(),
  elapsed    int not null default 0,
  exercises  int not null default 0,
  sets       int not null default 0,
  volume     double precision not null default 0,
  xp         int not null default 0,
  photo_url  text,
  avg_hr     int,
  max_hr     int,
  location   text,
  visibility text not null default 'all' check (visibility in ('all','followers','onlyMe')),
  verified   boolean not null default true,   -- anti-trampas (ver README): el servidor puede recalcularlo
  items      jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists sessions_user_date_idx on public.workout_sessions (user_id, date desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- STATS DE JUGADOR  (resumen server-authoritative para ranking/liga)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.player_stats (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  xp          int not null default 0,
  coins       int not null default 0,
  streak      int not null default 0,
  gym_score   int not null default 0,
  league_tier int not null default 0,
  updated_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- LIKES (kudos) y COMENTARIOS del feed
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.kudos (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, session_id)
);

create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  parent_id  uuid references public.comments(id) on delete cascade,
  text       text not null,
  created_at timestamptz not null default now()
);
create index if not exists comments_session_idx on public.comments (session_id, created_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at automático
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists stats_touch on public.player_stats;
create trigger stats_touch before update on public.player_stats
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.profiles         enable row level security;
alter table public.follows          enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.player_stats     enable row level security;
alter table public.kudos            enable row level security;
alter table public.comments         enable row level security;

-- Perfiles: identidad básica legible por todos; solo tú te editas.
drop policy if exists profiles_select_all on public.profiles;
create policy profiles_select_all on public.profiles for select using (true);
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert with check (id = auth.uid());
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- Follows: ves los que te involucran; tú creas/borras tus follows; el seguido acepta.
drop policy if exists follows_select_involved on public.follows;
create policy follows_select_involved on public.follows for select
  using (follower_id = auth.uid() or following_id = auth.uid());
drop policy if exists follows_insert_self on public.follows;
create policy follows_insert_self on public.follows for insert with check (follower_id = auth.uid());
drop policy if exists follows_update_target on public.follows;
create policy follows_update_target on public.follows for update using (following_id = auth.uid());
drop policy if exists follows_delete_self on public.follows;
create policy follows_delete_self on public.follows for delete
  using (follower_id = auth.uid() or following_id = auth.uid());

-- Sesiones: dueño siempre; público 'all' si el autor NO es privado; o si le sigues (aceptado).
drop policy if exists sessions_select_visible on public.workout_sessions;
create policy sessions_select_visible on public.workout_sessions for select using (
  user_id = auth.uid()
  or (visibility = 'all' and exists (
        select 1 from public.profiles p where p.id = user_id and p.is_private = false))
  or (visibility in ('all','followers') and exists (
        select 1 from public.follows f
        where f.follower_id = auth.uid() and f.following_id = user_id and f.status = 'accepted'))
);
drop policy if exists sessions_insert_self on public.workout_sessions;
create policy sessions_insert_self on public.workout_sessions for insert with check (user_id = auth.uid());
drop policy if exists sessions_update_self on public.workout_sessions;
create policy sessions_update_self on public.workout_sessions for update using (user_id = auth.uid());
drop policy if exists sessions_delete_self on public.workout_sessions;
create policy sessions_delete_self on public.workout_sessions for delete using (user_id = auth.uid());

-- Stats: legibles por todos (ranking); solo tú los escribes.
drop policy if exists stats_select_all on public.player_stats;
create policy stats_select_all on public.player_stats for select using (true);
drop policy if exists stats_insert_self on public.player_stats;
create policy stats_insert_self on public.player_stats for insert with check (user_id = auth.uid());
drop policy if exists stats_update_self on public.player_stats;
create policy stats_update_self on public.player_stats for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Kudos / comentarios: legibles; tú creas/borras lo tuyo. (v1 simple; se puede endurecer luego.)
drop policy if exists kudos_select_all on public.kudos;
create policy kudos_select_all on public.kudos for select using (true);
drop policy if exists kudos_insert_self on public.kudos;
create policy kudos_insert_self on public.kudos for insert with check (user_id = auth.uid());
drop policy if exists kudos_delete_self on public.kudos;
create policy kudos_delete_self on public.kudos for delete using (user_id = auth.uid());

drop policy if exists comments_select_all on public.comments;
create policy comments_select_all on public.comments for select using (true);
drop policy if exists comments_insert_self on public.comments;
create policy comments_insert_self on public.comments for insert with check (user_id = auth.uid());
drop policy if exists comments_delete_self on public.comments;
create policy comments_delete_self on public.comments for delete using (user_id = auth.uid());
