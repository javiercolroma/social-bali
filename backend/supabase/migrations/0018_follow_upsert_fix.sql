
-- El upsert de follow (insert on conflict update) necesita que el SEGUIDOR pueda
-- actualizar su propia fila (re-seguir tras pending/accepted fallaba en silencio).
drop policy if exists follows_update_self on public.follows;
create policy follows_update_self on public.follows for update to authenticated
  using (follower_id = auth.uid()) with check (follower_id = auth.uid());
