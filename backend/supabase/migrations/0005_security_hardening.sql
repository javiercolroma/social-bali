-- Forge Loop — endurecimiento de seguridad (hallazgos de la revisión adversarial)

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Privacidad de follows: al seguir a una cuenta PRIVADA, el servidor fuerza
--    status='pending' (el cliente no puede auto-aceptarse). El dueño acepta luego
--    con un UPDATE (follows_update_target lo permite). Cuentas públicas: 'accepted'.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.enforce_follow_privacy() returns trigger
language plpgsql security definer set search_path = public as $$
declare priv boolean;
begin
  if new.follower_id <> new.following_id then
    select is_private into priv from public.profiles where id = new.following_id;
    if coalesce(priv, false) then
      new.status := 'pending';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists follows_privacy on public.follows;
create trigger follows_privacy before insert on public.follows
  for each row execute function public.enforce_follow_privacy();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) Likes/comentarios respetan la visibilidad de la sesión (antes: legibles/insertables
--    por cualquiera). `can_see_session` replica la lógica de sessions_select_visible.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.can_see_session(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.workout_sessions s where s.id = sid and (
      s.user_id = auth.uid()
      or (s.visibility = 'all' and exists (
            select 1 from public.profiles p where p.id = s.user_id and p.is_private = false))
      or (s.visibility in ('all','followers') and exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid() and f.following_id = s.user_id and f.status = 'accepted'))
    )
  );
$$;

drop policy if exists kudos_select_all on public.kudos;
drop policy if exists kudos_select on public.kudos;
create policy kudos_select on public.kudos for select using (public.can_see_session(session_id));
drop policy if exists kudos_insert_self on public.kudos;
drop policy if exists kudos_insert on public.kudos;
create policy kudos_insert on public.kudos for insert
  with check (user_id = auth.uid() and public.can_see_session(session_id));

drop policy if exists comments_select_all on public.comments;
drop policy if exists comments_select on public.comments;
create policy comments_select on public.comments for select using (public.can_see_session(session_id));
drop policy if exists comments_insert_self on public.comments;
drop policy if exists comments_insert on public.comments;
create policy comments_insert on public.comments for insert
  with check (user_id = auth.uid() and public.can_see_session(session_id));
