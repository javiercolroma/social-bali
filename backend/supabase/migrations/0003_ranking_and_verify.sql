-- Forge Loop — ranking real (XP semanal) + anti-trampas v2 (verified server-authoritative)

-- ─────────────────────────────────────────────────────────────────────────────
-- Anti-trampas v2: el SERVIDOR recalcula `verified` en cada insert/update, así el
-- cliente no puede simplemente enviar verified=true. Misma heurística que la app
-- (≥20 s/serie, ≤60 series, XP ganada ≤600). Un cliente aún podría mentir sobre
-- `elapsed`, pero ya no basta con marcar el flag: la coherencia la impone el server.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.recompute_verified() returns trigger
language plpgsql as $$
begin
  new.verified := (new.elapsed >= new.sets * 20 and new.sets <= 60 and new.xp <= 600);
  return new;
end;
$$;

drop trigger if exists sessions_verify on public.workout_sessions;
create trigger sessions_verify before insert or update on public.workout_sessions
  for each row execute function public.recompute_verified();

-- ─────────────────────────────────────────────────────────────────────────────
-- Ranking / Liga real: XP de la semana ISO en curso (lunes→lunes) por usuario,
-- SOLO de sesiones verificadas. `security definer` para poder agregar sobre todos
-- (expone handle + xp semanal, no las sesiones). Ordenado, top 100.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.weekly_xp_leaderboard()
returns table (user_id uuid, handle text, name text, avatar_url text, weekly_xp bigint)
language sql stable security definer set search_path = public as $$
  select p.id, p.handle, p.name, p.avatar_url,
         coalesce(sum(s.xp) filter (
           where s.verified
             and s.date >= date_trunc('week', now())
             and s.date <  date_trunc('week', now()) + interval '7 days'
         ), 0)::bigint as weekly_xp
  from public.profiles p
  left join public.workout_sessions s on s.user_id = p.id
  group by p.id, p.handle, p.name, p.avatar_url
  order by weekly_xp desc, p.handle asc
  limit 100;
$$;

grant execute on function public.weekly_xp_leaderboard() to anon, authenticated;
