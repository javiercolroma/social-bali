-- Eliminación de cuenta in-app (App Store Guideline 5.1.1(v): obligatoria si hay registro).
-- El usuario autenticado borra SU PROPIA fila de auth.users; las cascadas hacen el resto:
--   auth.users → profiles (CASCADE) → sessions/follows/messages/kudos/comments/blocks/player_stats (CASCADE)
--   auth.users → workouts (CASCADE)
-- (Los archivos de Storage se borran desde el cliente, best-effort, antes de llamar aquí.)
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = auth.uid();
end; $$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
