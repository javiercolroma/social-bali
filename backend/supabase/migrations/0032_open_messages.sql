-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Chat directo, sin solicitud previa (decisión del 2026-10-01)
--
-- Tipo Grindr: en una comunidad privada cualquier miembro puede escribir a otro.
-- Se sustituye la regla de 0026 («solo entre conectados») por:
--   · nadie escribe a quien le ha bloqueado (ni a quien ha bloqueado);
--   · hay que estar en Bali (respeta el interruptor require_bali de 0030);
--   · freno anti-spam: como mucho 20 conversaciones NUEVAS al día por persona.
-- `connection_requests` se queda (histórico), pero la app ya no la usa.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.can_message_to(recipient uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
     and recipient <> auth.uid()
     and not public.is_blocked_pair(auth.uid(), recipient)
     and public.is_in_bali(auth.uid())
     and (
       -- Conversación ya empezada (por cualquiera de los dos): siempre se puede seguir.
       exists (select 1 from public.messages m
                where (m.sender_id = auth.uid() and m.recipient_id = recipient)
                   or (m.sender_id = recipient and m.recipient_id = auth.uid()))
       -- Conversación nueva: máximo 20 al día.
       or (select count(distinct m.recipient_id) from public.messages m
            where m.sender_id = auth.uid() and m.created_at > now() - interval '24 hours'
              and not exists (select 1 from public.messages e
                               where e.created_at < m.created_at
                                 and ((e.sender_id = m.sender_id and e.recipient_id = m.recipient_id)
                                   or (e.sender_id = m.recipient_id and e.recipient_id = m.sender_id)))) < 20
     )
$$;
revoke all on function public.can_message_to(uuid) from public, anon;
grant execute on function public.can_message_to(uuid) to authenticated;

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert with check (
  sender_id = auth.uid() and public.can_message_to(recipient_id)
);
