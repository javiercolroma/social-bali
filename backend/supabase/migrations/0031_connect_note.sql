-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Conectar con una nota propia (2026-10-01)
--
-- Fuera los motivos predefinidos (train · surf · coffee): al conectar se escribe
-- una nota personal opcional y quien la recibe la ve con la solicitud. Se conserva
-- «interested» (citas, solo visible si es mutuo). Los motivos viejos siguen siendo
-- válidos para no romper solicitudes ya enviadas ni builds anteriores.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.connection_requests drop constraint if exists connection_requests_reason_check;
alter table public.connection_requests add constraint connection_requests_reason_check
  check (reason in ('connect', 'interested', 'train', 'surf', 'coffee'));

alter table public.connection_requests add column if not exists note text;
alter table public.connection_requests drop constraint if exists connection_requests_note_len;
alter table public.connection_requests add constraint connection_requests_note_len
  check (note is null or char_length(note) <= 200);

-- Igual que send_connection (0026) + nota. La versión de 2 argumentos se queda para
-- las builds anteriores.
create or replace function public.send_connection(target uuid, reason text, note text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  uid  uuid := auth.uid();
  mine public.connection_requests;
  rev  public.connection_requests;
  n    text := nullif(trim(note), '');
begin
  if uid is null then raise exception 'not authenticated'; end if;
  if target = uid then raise exception 'cannot connect with yourself'; end if;
  if reason not in ('connect', 'interested', 'train', 'surf', 'coffee') then raise exception 'invalid reason'; end if;
  if n is not null and char_length(n) > 200 then raise exception 'note too long'; end if;
  if not exists (select 1 from public.profiles where id = target) then raise exception 'unknown profile'; end if;
  if public.is_blocked_pair(uid, target) then raise exception 'blocked'; end if;

  if reason = 'interested' and not (
       public.is_adult(uid) and public.is_adult(target)
       and exists (select 1 from public.profiles where id = uid and 'dating' = any(coalesce(intents, '{}')))
       and exists (select 1 from public.profiles where id = target and 'dating' = any(coalesce(intents, '{}')))) then
    raise exception 'interested requires both members to be open to dating';
  end if;

  if public.are_connected(uid, target) then return 'connected'; end if;

  select * into rev from public.connection_requests
   where from_id = target and to_id = uid and status = 'pending';
  if found and (rev.reason <> 'interested' or reason = 'interested') then
    update public.connection_requests set status = 'accepted', responded_at = now() where id = rev.id;
    insert into public.connection_requests (from_id, to_id, reason, note, status, responded_at)
      values (uid, target, reason, n, 'accepted', now())
      on conflict (from_id, to_id) do update
        set reason = excluded.reason, note = excluded.note, status = 'accepted', responded_at = now();
    return 'connected';
  end if;

  select * into mine from public.connection_requests where from_id = uid and to_id = target;
  if found and mine.status = 'declined' then
    return 'pending';   -- rechazo silencioso: no se reabre
  end if;

  insert into public.connection_requests (from_id, to_id, reason, note)
    values (uid, target, reason, n)
    on conflict (from_id, to_id) do update set reason = excluded.reason, note = excluded.note;
  return 'pending';
end;
$$;
revoke all on function public.send_connection(uuid, text, text) from public, anon;
grant execute on function public.send_connection(uuid, text, text) to authenticated;
