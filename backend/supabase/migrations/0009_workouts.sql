-- Entrenos (plantillas/rutinas) creados por el usuario, para que sobrevivan a
-- cerrar sesión / reinstalar / cambiar de dispositivo (antes eran solo locales y
-- se perdían al hacer logout, que borra todo el estado local).
create table if not exists public.workouts (
  id text primary key,                    -- id de la app ("w-…"); upsert por id
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Mi entreno',
  description text default '',
  block text default 'Otros',
  exercises jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.workouts enable row level security;

drop policy if exists "workouts_owner_all" on public.workouts;
create policy "workouts_owner_all" on public.workouts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists workouts_user_idx on public.workouts(user_id, updated_at desc);
