-- Forge Loop — mensajería 1:1 (con Realtime)

create table if not exists public.messages (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  text         text not null,
  created_at   timestamptz not null default now(),
  check (sender_id <> recipient_id)
);
create index if not exists messages_convo_idx on public.messages (sender_id, recipient_id, created_at);

alter table public.messages enable row level security;

-- Ves los mensajes de conversaciones en las que participas.
drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages for select
  using (sender_id = auth.uid() or recipient_id = auth.uid());

-- Solo puedes enviar como tú mismo.
drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert
  with check (sender_id = auth.uid());

-- Realtime: publica la tabla para suscripciones en vivo (idempotente).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
