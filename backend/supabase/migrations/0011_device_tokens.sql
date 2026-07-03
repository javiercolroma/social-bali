-- Tokens de dispositivo (APNs) para notificaciones push. El cliente registra su token
-- al conceder permiso; el servidor (Edge Function, pendiente de la clave APNs .p8 del
-- Apple Developer account) los usa para enviar pushes de mensajes/follows/likes.
create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'ios',
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_owner on public.device_tokens;
create policy device_tokens_owner on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists device_tokens_user_idx on public.device_tokens(user_id);
