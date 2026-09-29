-- ─────────────────────────────────────────────────────────────────────────────
-- CLUB SOCIAL · Fase 2 · Discover — «Today's People» (ver PRODUCT.md)
--
-- 10-15 perfiles al día, curados, con final explícito (principio 6: escasez, no
-- swipe infinito). La selección se calcula AQUÍ y se guarda por día:
--   · es la misma en cualquier dispositivo y no se regenera reinstalando;
--   · el orden no se puede manipular desde un cliente.
-- El «día» es el de Bali (Asia/Makassar, UTC+8), no el del móvil.
-- ─────────────────────────────────────────────────────────────────────────────

-- Perfiles de PRUEBA (ver backend/supabase/seed/). Se borran de una vez antes de
-- abrir a gente real: `delete from auth.users where id in (select id from
-- public.profiles where is_seed)` — el borrado en cascada se lleva el resto.
alter table public.profiles add column if not exists is_seed boolean not null default false;

create or replace function public.bali_today()
returns date
language sql
stable
as $$ select (now() at time zone 'Asia/Makassar')::date $$;

-- El mazo de cada persona para cada día. `position` = cuántos ha visto ya
-- (para retomar donde lo dejó, también en otro dispositivo).
create table if not exists public.discover_decks (
  user_id     uuid not null references auth.users(id) on delete cascade,
  day         date not null,
  profile_ids uuid[] not null default '{}',
  position    int not null default 0,
  created_at  timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.discover_decks enable row level security;
drop policy if exists discover_decks_select_self on public.discover_decks;
create policy discover_decks_select_self on public.discover_decks
  for select using (user_id = auth.uid());
-- Sin políticas de escritura: solo se escribe a través de las funciones de abajo.

-- Una tarjeta, tal y como la ve `viewer`. «dating» solo se muestra a quien también
-- lo busca (y puede: 18+). Alguien que solo quiere entrenar no ve señales de citas.
create or replace function public.discover_card(p public.profiles, viewer_dates boolean)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', p.id, 'handle', p.handle, 'name', p.name, 'avatar_url', p.avatar_url,
    'country', p.country, 'city', p.city, 'gym', p.gym, 'is_private', p.is_private,
    'gym_score', p.gym_score, 'bio', p.bio, 'sports', p.sports,
    'neighborhood', p.neighborhood, 'home_city', p.home_city, 'home_country', p.home_country,
    'stay_kind', p.stay_kind, 'stay_until', p.stay_until,
    'intents', case when viewer_dates then p.intents else array_remove(p.intents, 'dating') end
  )
$$;

-- El mazo de hoy: lo crea la primera vez y después siempre devuelve el mismo.
create or replace function public.todays_people()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid          uuid := auth.uid();
  d            date := public.bali_today();
  me           public.profiles;
  viewer_dates boolean;
  my_intents   text[];
  launch       text[] := array['canggu','berawa','pererenan','uluwatu','bingin','pecatu'];
  deck         public.discover_decks;
  ids          uuid[];
begin
  if uid is null then raise exception 'not authenticated'; end if;

  select * into me from public.profiles where id = uid;
  if not found then
    -- Aún sin perfil en el servidor: no se guarda un mazo vacío para hoy.
    return jsonb_build_object('day', d, 'position', 0, 'profiles', '[]'::jsonb);
  end if;

  viewer_dates := 'dating' = any(coalesce(me.intents, '{}')) and public.is_adult(uid);
  my_intents := case when viewer_dates then coalesce(me.intents, '{}')
                     else array_remove(coalesce(me.intents, '{}'), 'dating') end;

  select * into deck from public.discover_decks where user_id = uid and day = d;

  if not found then
    with eligible as (
      select p.*,
        -- Visto en los últimos 14 días: va al final, solo si no hay gente nueva.
        exists (select 1 from public.discover_decks dd
                 where dd.user_id = uid and dd.day > d - 14 and p.id = any(dd.profile_ids)) as seen_recently
      from public.profiles p
      where p.id <> uid
        and p.handle is not null
        -- Perfil con algo que enseñar (si no, la tarjeta sale vacía).
        and (nullif(trim(p.bio), '') is not null or cardinality(p.sports) > 0)
        -- Quien ya se ha ido de Bali no se propone.
        and not (p.stay_kind = 'until' and p.stay_until is not null and p.stay_until < d)
        -- Bloqueos en cualquier dirección.
        and not exists (select 1 from public.blocks b
                         where (b.blocker_id = uid and b.blocked_id = p.id)
                            or (b.blocker_id = p.id and b.blocked_id = uid))
        -- Ya conectados: Discover es para conocer gente nueva.
        and not exists (select 1 from public.follows f
                         where f.follower_id = uid and f.following_id = p.id and f.status = 'accepted')
    ),
    scored as (
      select e.id, e.seen_recently,
        -- Cerca: mismo barrio pesa más; si no, zona de arranque (donde está la densidad).
        (case when e.neighborhood is not null and e.neighborhood = me.neighborhood then 30
              when e.neighborhood = any(launch) then 12 else 0 end)
        -- Deportes en común (10 por deporte, tope 30).
        + least(30, 10 * coalesce(cardinality(array(
              select unnest(e.sports) intersect select unnest(me.sports))), 0))
        -- Buscan algo compatible (sin contar «dating» si el que mira no lo busca).
        + case when (case when viewer_dates then e.intents else array_remove(e.intents, 'dating') end)
                    && my_intents then 15 else 0 end
        -- Actividad REAL reciente (principio 9: identidad demostrada, no declarada).
        + case when e.active_at > now() - interval '7 days' then 10
               when e.active_at > now() - interval '30 days' then 4 else 0 end
        + least(10, coalesce(e.gym_score, 0) / 10)
        -- Variación estable por persona y día, para que el mazo no sea siempre igual.
        + (('x' || substr(md5(uid::text || e.id::text || d::text), 1, 6))::bit(24)::int % 10)
        -- Nunca: atractivo físico ni nada parecido (principio 8).
        as score
      from eligible e
    )
    select coalesce(array_agg(id order by seen_recently, score desc, id), '{}') into ids
      from (select id, seen_recently, score from scored
             order by seen_recently, score desc, id limit 15) top;

    insert into public.discover_decks(user_id, day, profile_ids)
      values (uid, d, ids)
      on conflict (user_id, day) do nothing;
    select * into deck from public.discover_decks where user_id = uid and day = d;
  end if;

  -- Se devuelven en el orden del mazo; quien te bloquee o borre su cuenta después
  -- desaparece sin romper la posición del resto.
  return jsonb_build_object(
    'day', d,
    'position', deck.position,
    'profiles', coalesce((
      select jsonb_agg(public.discover_card(p, viewer_dates) order by t.ord)
        from unnest(deck.profile_ids) with ordinality as t(pid, ord)
        join public.profiles p on p.id = t.pid
       where not exists (select 1 from public.blocks b
                          where (b.blocker_id = uid and b.blocked_id = p.id)
                             or (b.blocker_id = p.id and b.blocked_id = uid))
    ), '[]'::jsonb)
  );
end;
$$;

-- Avanza la posición (solo hacia delante y nunca más allá del mazo).
create or replace function public.discover_set_position(pos int)
returns void
language sql
security definer
set search_path = public
as $$
  update public.discover_decks
     set position = greatest(position, least(pos, cardinality(profile_ids)))
   where user_id = auth.uid() and day = public.bali_today();
$$;

revoke all on function public.todays_people() from public, anon;
revoke all on function public.discover_set_position(int) from public, anon;
grant execute on function public.todays_people() to authenticated;
grant execute on function public.discover_set_position(int) to authenticated;
