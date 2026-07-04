-- Partner REAL: planes de entrenamiento de usuarios reales.
-- Ver todos (authenticated), crear/borrar solo los propios. Aceptar = chat real.

create table if not exists public.training_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  when_text text not null default '',
  place text not null default '',
  spots text not null default '',
  note text,
  created_at timestamptz not null default now()
);
alter table public.training_plans enable row level security;
drop policy if exists plans_select_all on public.training_plans;
create policy plans_select_all on public.training_plans for select to authenticated using (true);
drop policy if exists plans_insert_own on public.training_plans;
create policy plans_insert_own on public.training_plans for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists plans_delete_own on public.training_plans;
create policy plans_delete_own on public.training_plans for delete to authenticated using (auth.uid() = user_id);
create index if not exists plans_created_idx on public.training_plans(created_at desc);
