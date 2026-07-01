-- Forge Loop — moderación de contenido (requisito App Store para UGC):
-- bloquear usuarios, reportar contenido, auto-ocultar lo muy reportado.

-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUEOS: no ves su contenido ni ellos el tuyo.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.blocks enable row level security;
drop policy if exists blocks_select on public.blocks;
create policy blocks_select on public.blocks for select using (blocker_id = auth.uid());
drop policy if exists blocks_insert on public.blocks;
create policy blocks_insert on public.blocks for insert with check (blocker_id = auth.uid());
drop policy if exists blocks_delete on public.blocks;
create policy blocks_delete on public.blocks for delete using (blocker_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- REPORTES: el usuario denuncia una publicación / comentario / usuario.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid not null references public.profiles(id) on delete cascade,
  target_type      text not null check (target_type in ('session','comment','user')),
  target_id        uuid not null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  reason           text,
  created_at       timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)   -- no denunciar 2 veces lo mismo
);
alter table public.reports enable row level security;
drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports for insert with check (reporter_id = auth.uid());
drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports for select using (reporter_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTO-OCULTAR: una sesión con ≥3 reportes distintos se oculta (revisión < 24 h).
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.workout_sessions add column if not exists hidden boolean not null default false;

create or replace function public.autohide_reported_session() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.target_type = 'session'
     and (select count(*) from public.reports where target_type = 'session' and target_id = new.target_id) >= 3 then
    update public.workout_sessions set hidden = true where id = new.target_id;
  end if;
  return new;
end $$;

drop trigger if exists reports_autohide on public.reports;
create trigger reports_autohide after insert on public.reports
  for each row execute function public.autohide_reported_session();

-- ─────────────────────────────────────────────────────────────────────────────
-- Visibilidad del feed: excluye lo OCULTO y a quien has bloqueado / te ha bloqueado.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists sessions_select_visible on public.workout_sessions;
create policy sessions_select_visible on public.workout_sessions for select using (
  user_id = auth.uid()
  or (
    hidden = false
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = user_id)
         or (b.blocker_id = user_id and b.blocked_id = auth.uid())
    )
    and (
      (visibility = 'all' and exists (
            select 1 from public.profiles p where p.id = user_id and p.is_private = false))
      or (visibility in ('all','followers') and exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid() and f.following_id = user_id and f.status = 'accepted'))
    )
  )
);
