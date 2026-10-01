-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Mensajería tipo WhatsApp (2026-10-01)
--   · responder citando un mensaje (reply_to);
--   · reacciones (una por persona y mensaje);
--   · borrar para todos (solo quien lo envió) → «This message was deleted»;
--   · ajustes por chat: fijar, silenciar, vaciar (solo para mí);
--   · «last seen» (respeta show_online). El «typing…» va por Realtime, sin tabla.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.messages add column if not exists reply_to uuid references public.messages(id) on delete set null;
alter table public.messages add column if not exists deleted boolean not null default false;
alter table public.messages add column if not exists react_sender text;      -- reacción de quien lo envió
alter table public.messages add column if not exists react_recipient text;   -- reacción de quien lo recibió

alter table public.messages drop constraint if exists messages_payload_check;
alter table public.messages add constraint messages_payload_check check (
  deleted or case kind
    when 'text'     then char_length(trim(text)) > 0
    when 'location' then lat is not null and lon is not null
    else media_url is not null
  end
);

-- Reaccionar (o quitar la reacción con null). Solo quien participa en el chat.
create or replace function public.react_message(message uuid, emoji text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m   public.messages;
begin
  if emoji is not null and char_length(emoji) > 16 then raise exception 'invalid reaction'; end if;
  select * into m from public.messages where id = message;
  if not found or m.deleted then raise exception 'message not found'; end if;
  if m.sender_id = uid then
    update public.messages set react_sender = emoji where id = message;
  elsif m.recipient_id = uid then
    update public.messages set react_recipient = emoji where id = message;
  else
    raise exception 'message not found';
  end if;
end;
$$;
revoke all on function public.react_message(uuid, text) from public, anon;
grant execute on function public.react_message(uuid, text) to authenticated;

-- Borrar para todos: solo quien lo envió. Se vacía el contenido y queda el aviso.
create or replace function public.delete_message(message uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.messages
     set deleted = true, text = '', kind = 'text', media_url = null, poster_url = null,
         lat = null, lon = null, duration = null, react_sender = null, react_recipient = null
   where id = message and sender_id = auth.uid()
$$;
revoke all on function public.delete_message(uuid) from public, anon;
grant execute on function public.delete_message(uuid) to authenticated;

-- Ajustes de cada chat, solo para mí.
create table if not exists public.chat_settings (
  user_id    uuid not null references auth.users(id) on delete cascade,
  other_id   uuid not null references public.profiles(id) on delete cascade,
  pinned     boolean not null default false,
  muted      boolean not null default false,
  cleared_at timestamptz,          -- «vaciar chat»: no ves lo anterior a esta fecha
  updated_at timestamptz not null default now(),
  primary key (user_id, other_id)
);
alter table public.chat_settings enable row level security;
drop policy if exists chat_settings_own on public.chat_settings;
create policy chat_settings_own on public.chat_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- «last seen today at 14:02» (null si esa persona oculta su actividad).
create or replace function public.last_seen(target uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select pr.last_seen_at from public.presence pr
    join public.profiles p on p.id = pr.user_id
   where pr.user_id = target and p.show_online and public.can_see_user(target)
$$;
revoke all on function public.last_seen(uuid) from public, anon;
grant execute on function public.last_seen(uuid) to authenticated;

-- Desconexión aparte de la última actividad: así «last seen» es la hora real y el
-- online se apaga al cerrar la app (antes go_offline retrasaba last_seen_at 10 min).
alter table public.presence add column if not exists offline_at timestamptz;

create or replace function public.go_offline()
returns void
language sql
security definer
set search_path = public
as $$
  update public.presence set offline_at = now() where user_id = auth.uid();
$$;

create or replace function public.is_online(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select last_seen_at > now() - interval '5 minutes'
                          and (offline_at is null or offline_at < last_seen_at)
                     from public.presence where user_id = uid), false)
$$;
revoke all on function public.is_online(uuid) from public, anon, authenticated;

-- Arreglo de los datos que dejó el go_offline anterior (last_seen_at adelantado 10 min no se puede recuperar).
