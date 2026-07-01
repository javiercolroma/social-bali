-- Forge Loop — estado "leído" de mensajes (para el contador de no leídos).

alter table public.messages add column if not exists read boolean not null default false;

-- El destinatario puede marcar como leídos sus mensajes recibidos.
drop policy if exists messages_update_recipient on public.messages;
create policy messages_update_recipient on public.messages for update
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
