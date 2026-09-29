-- ─────────────────────────────────────────────────────────────────────────────
-- CLUB SOCIAL · Fase 3 · Conectar con contexto (ver PRODUCT.md)
--
-- Nada de ❤️ mudo: se conecta CON UN MOTIVO — train · surf · coffee — y quien lo
-- recibe ve quién es y por qué, y decide. Si acepta, se abre el chat: la
-- conversación nace con un motivo (principio 4) y empuja a quedar (principio 5).
--
-- «interested» (citas) es distinto: solo se revela si es MUTUO. Si no, la otra
-- persona nunca lo sabe. Así nadie recibe interés romántico que no ha pedido.
--
-- Sin conexión aceptada no se puede escribir a nadie (se cierra `messages`).
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.connection_requests (
  id           uuid primary key default gen_random_uuid(),
  from_id      uuid not null references public.profiles(id) on delete cascade,
  to_id        uuid not null references public.profiles(id) on delete cascade,
  reason       text not null check (reason in ('train', 'surf', 'coffee', 'interested')),
  status       text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  unique (from_id, to_id),
  check (from_id <> to_id)
);
create index if not exists connection_requests_to_idx on public.connection_requests (to_id, status);

alter table public.connection_requests enable row level security;

-- Lectura: lo que TÚ envías, y lo que te envían… salvo «interested» pendiente
-- (esa solo aparece para el receptor cuando ya es mutua = aceptada).
-- Escritura: solo a través de las funciones de abajo.
drop policy if exists connection_requests_select on public.connection_requests;
create policy connection_requests_select on public.connection_requests for select using (
  from_id = auth.uid()
  or (to_id = auth.uid() and (reason <> 'interested' or status = 'accepted'))
);

-- ¿Hay conexión aceptada entre dos personas (en cualquier dirección)?
create or replace function public.are_connected(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.connection_requests
                  where status = 'accepted'
                    and ((from_id = a and to_id = b) or (from_id = b and to_id = a)));
$$;
revoke all on function public.are_connected(uuid, uuid) from public, anon;
grant execute on function public.are_connected(uuid, uuid) to authenticated;

create or replace function public.is_blocked_pair(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.blocks
                  where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a));
$$;
revoke all on function public.is_blocked_pair(uuid, uuid) from public, anon, authenticated;

-- Enviar. Devuelve 'connected' (ya lo estabais, o la otra persona también quería)
-- o 'pending'. Tras un rechazo devuelve 'pending' igualmente: quien envía no sabe
-- que le han dicho que no, y no puede insistir con otra solicitud.
create or replace function public.send_connection(target uuid, reason text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  uid  uuid := auth.uid();
  mine public.connection_requests;
  rev  public.connection_requests;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  if target = uid then raise exception 'cannot connect with yourself'; end if;
  if reason not in ('train', 'surf', 'coffee', 'interested') then raise exception 'invalid reason'; end if;
  if not exists (select 1 from public.profiles where id = target) then raise exception 'unknown profile'; end if;
  if public.is_blocked_pair(uid, target) then raise exception 'blocked'; end if;

  -- «interested» solo entre dos personas que lo buscan y tienen 18+ (0024).
  if reason = 'interested' and not (
       public.is_adult(uid) and public.is_adult(target)
       and exists (select 1 from public.profiles where id = uid and 'dating' = any(coalesce(intents, '{}')))
       and exists (select 1 from public.profiles where id = target and 'dating' = any(coalesce(intents, '{}')))) then
    raise exception 'interested requires both members to be open to dating';
  end if;

  if public.are_connected(uid, target) then return 'connected'; end if;

  -- ¿La otra persona ya me lo había pedido? Si su solicitud es visible para mí (no es
  -- un «interested» oculto), o las dos son «interested», pedirlo yo = aceptarla.
  select * into rev from public.connection_requests
   where from_id = target and to_id = uid and status = 'pending';
  if found and (rev.reason <> 'interested' or reason = 'interested') then
    update public.connection_requests set status = 'accepted', responded_at = now() where id = rev.id;
    insert into public.connection_requests (from_id, to_id, reason, status, responded_at)
      values (uid, target, reason, 'accepted', now())
      on conflict (from_id, to_id) do update
        set reason = excluded.reason, status = 'accepted', responded_at = now();
    return 'connected';
  end if;

  select * into mine from public.connection_requests where from_id = uid and to_id = target;
  if found and mine.status = 'declined' then
    return 'pending';   -- rechazo silencioso: no se reabre
  end if;

  insert into public.connection_requests (from_id, to_id, reason)
    values (uid, target, reason)
    on conflict (from_id, to_id) do update set reason = excluded.reason;
  return 'pending';
end;
$$;

-- Responder a una solicitud recibida. «interested» no se responde: es mutuo o no es.
create or replace function public.respond_connection(request uuid, accept boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  r   public.connection_requests;
begin
  select * into r from public.connection_requests
   where id = request and to_id = uid and status = 'pending' and reason <> 'interested';
  if not found then raise exception 'request not found'; end if;
  if accept and public.is_blocked_pair(uid, r.from_id) then raise exception 'blocked'; end if;
  update public.connection_requests
     set status = case when accept then 'accepted' else 'declined' end, responded_at = now()
   where id = r.id;
  return case when accept then 'connected' else 'declined' end;
end;
$$;

revoke all on function public.send_connection(uuid, text) from public, anon;
revoke all on function public.respond_connection(uuid, boolean) from public, anon;
grant execute on function public.send_connection(uuid, text) to authenticated;
grant execute on function public.respond_connection(uuid, boolean) to authenticated;

-- ─── Mensajes: solo entre personas conectadas ─────────────────────────────────
-- Función `security definer` y no una subconsulta en la política: la RLS de `blocks`
-- solo deja ver TUS bloqueos, así que el emisor no vería que el otro le bloqueó.
create or replace function public.can_message_to(recipient uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.are_connected(auth.uid(), recipient)
     and not public.is_blocked_pair(auth.uid(), recipient);
$$;
revoke all on function public.can_message_to(uuid) from public, anon;
grant execute on function public.can_message_to(uuid) to authenticated;

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert with check (
  sender_id = auth.uid() and public.can_message_to(recipient_id)
);
