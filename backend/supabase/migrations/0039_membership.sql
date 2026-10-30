-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Puerta de entrada: solicitud → aprobación manual → dentro (2026-10-30)
--
-- «Apply to join. Not everyone gets in.» Cada perfil nuevo queda PENDIENTE hasta que un
-- admin lo aprueba a mano (o canjea un código de invitación). Mientras tanto no aparece
-- en ningún Circle, no se le puede escribir y no ve a nadie.
--
-- Interruptor `require_approval` (app_settings): apagado hasta que la 1.1 esté en la
-- tienda (la 1.0 no tiene pantalla de «solicitud recibida»). Al encenderlo, ejecutar
-- backend/release/enable_approval.sql, que aprueba a todo el que entró antes.
-- Criterios de aprobación (PRODUCT.md): lifestyle fit, perfil real y completo, encaje
-- con la comunidad. NUNCA el atractivo físico.
-- ─────────────────────────────────────────────────────────────────────────────

insert into public.app_settings (key, value) values ('require_approval', 'false') on conflict (key) do nothing;

alter table public.profiles add column if not exists membership text not null default 'pending'
  check (membership in ('pending', 'approved', 'declined'));
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists invited_by uuid references public.profiles(id) on delete set null;
alter table public.profiles add column if not exists reviewed_at timestamptz;
-- Quien ya estaba dentro, sigue dentro.
update public.profiles set membership = 'approved' where membership = 'pending';
create index if not exists profiles_membership_idx on public.profiles (membership, created_at);

-- Códigos: `approves` = entra directamente (invitación); `grants_days` > 0 = además abre
-- el Circle desde fuera de Bali. `owner_id` = código personal de un miembro.
alter table public.access_codes add column if not exists approves boolean not null default true;
alter table public.access_codes add column if not exists owner_id uuid references public.profiles(id) on delete cascade;
create index if not exists access_codes_owner_idx on public.access_codes (owner_id);

create or replace function public.require_approval()
returns boolean language sql stable security definer set search_path = public
as $$ select coalesce((select value::boolean from public.app_settings where key = 'require_approval'), false) $$;
revoke all on function public.require_approval() from public, anon, authenticated;

create or replace function public.is_member(uid uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select not public.require_approval()
      or coalesce((select membership = 'approved' from public.profiles where id = uid), false)
$$;
revoke all on function public.is_member(uuid) from public, anon, authenticated;

create or replace function public.is_admin(uid uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select coalesce((select is_admin from public.profiles where id = uid), false) $$;
revoke all on function public.is_admin(uuid) from public, anon, authenticated;

-- Código personal de invitación «BALI-XXXX» (3 usos) para cada miembro aprobado.
create or replace function public.ensure_invite_code(member uuid)
returns text language plpgsql security definer set search_path = public
as $$
declare c text;
begin
  select code into c from public.access_codes where owner_id = member;
  if found then return c; end if;
  loop
    -- 4 letras/dígitos legibles (sin 0/O/1/I), a partir de md5(random()).
    c := 'BALI-' || upper(translate(substr(md5(random()::text || clock_timestamp()::text), 1, 4), '01', 'KZ'));
    exit when not exists (select 1 from public.access_codes where code = c);
  end loop;
  insert into public.access_codes (code, label, grants_days, max_uses, approves, owner_id)
    values (c, 'Invite', 0, 3, true, member);
  return c;
end;
$$;
revoke all on function public.ensure_invite_code(uuid) from public, anon, authenticated;

-- Mi situación: pendiente / dentro / no admitido, admin, mi código y usos que le quedan.
create or replace function public.my_membership()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  p   public.profiles;
  c   public.access_codes;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  select * into p from public.profiles where id = uid;
  if not found then return jsonb_build_object('status', 'none'); end if;
  if p.membership = 'approved' then
    perform public.ensure_invite_code(uid);
    select * into c from public.access_codes where owner_id = uid;
  end if;
  return jsonb_build_object(
    'status', case when public.require_approval() then p.membership else 'approved' end,
    'raw_status', p.membership,
    'is_admin', p.is_admin,
    'pending_count', case when p.is_admin then (select count(*) from public.profiles where membership = 'pending') else 0 end,
    'invite_code', c.code,
    'invites_left', case when c.code is null then null else greatest(0, c.max_uses - c.uses) end,
    'applied_at', p.created_at
  );
end;
$$;
revoke all on function public.my_membership() from public, anon;
grant execute on function public.my_membership() to authenticated;

-- Canjear un código: invita (aprueba) y/o abre el Circle desde fuera de Bali.
create or replace function public.redeem_access_code(code text)
returns boolean language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  c   public.access_codes;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  select * into c from public.access_codes
   where access_codes.code = upper(trim(redeem_access_code.code))
     and (expires_at is null or expires_at > now())
     and (max_uses is null or uses < max_uses)
     and owner_id is distinct from uid;
  if not found then return false; end if;
  update public.access_codes set uses = uses + 1 where access_codes.code = c.code;
  if c.grants_days > 0 then
    update public.profiles
       set bali_override_until = greatest(coalesce(bali_override_until, now()), now()) + make_interval(days => c.grants_days)
     where id = uid;
  end if;
  if c.approves then
    update public.profiles
       set membership = 'approved', reviewed_at = now(), invited_by = coalesce(invited_by, c.owner_id)
     where id = uid and membership <> 'approved';
  end if;
  return true;
end;
$$;

-- Solicitudes pendientes (solo admin): la tarjeta completa para decidir con criterio.
create or replace function public.pending_applications()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  if not public.is_admin(uid) then raise exception 'admins only'; end if;
  return coalesce((
    select jsonb_agg(public.circle_card(p, uid, true, false) || jsonb_build_object('applied_at', p.created_at) order by p.created_at)
      from public.profiles p where p.membership = 'pending'), '[]'::jsonb);
end;
$$;
revoke all on function public.pending_applications() from public, anon;
grant execute on function public.pending_applications() to authenticated;

create or replace function public.review_application(target uuid, approve boolean)
returns void language plpgsql security definer set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  if not public.is_admin(uid) then raise exception 'admins only'; end if;
  update public.profiles
     set membership = case when approve then 'approved' else 'declined' end, reviewed_at = now()
   where id = target;
  if approve then perform public.ensure_invite_code(target); end if;
end;
$$;
revoke all on function public.review_application(uuid, boolean) from public, anon;
grant execute on function public.review_application(uuid, boolean) to authenticated;

-- Volver a solicitar tras una negativa (una vez editado el perfil).
create or replace function public.reapply()
returns void language sql security definer set search_path = public
as $$ update public.profiles set membership = 'pending', reviewed_at = null where id = auth.uid() and membership = 'declined' $$;
revoke all on function public.reapply() from public, anon;
grant execute on function public.reapply() to authenticated;

-- ─── Puertas ─────────────────────────────────────────────────────────────────
-- Ver a alguien: los dos dentro (los admins ven a los pendientes para revisarlos).
create or replace function public.can_see_user(target uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select not public.is_blocked_pair(auth.uid(), target)
     and (public.is_member(auth.uid()) or public.is_admin(auth.uid()))
     and (public.is_member(target) or public.is_admin(auth.uid()))
$$;

-- Escribir: los dos dentro, además de las reglas de 0032.
create or replace function public.can_message_to(recipient uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select auth.uid() is not null
     and recipient <> auth.uid()
     and public.is_member(auth.uid()) and public.is_member(recipient)
     and not public.is_blocked_pair(auth.uid(), recipient)
     and public.is_in_bali(auth.uid())
     and (
       exists (select 1 from public.messages m
                where (m.sender_id = auth.uid() and m.recipient_id = recipient)
                   or (m.sender_id = recipient and m.recipient_id = auth.uid()))
       or (select count(distinct m.recipient_id) from public.messages m
            where m.sender_id = auth.uid() and m.created_at > now() - interval '24 hours'
              and not exists (select 1 from public.messages e
                               where e.created_at < m.created_at
                                 and ((e.sender_id = m.sender_id and e.recipient_id = m.recipient_id)
                                   or (e.sender_id = m.recipient_id and e.recipient_id = m.sender_id)))) < 20
     )
$$;

-- Buscador: solo miembros.
create or replace function public.search_members(q text)
returns jsonb language plpgsql stable security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  term text := trim(coalesce(q, ''));
begin
  if uid is null then raise exception 'not authenticated'; end if;
  if char_length(term) < 2 or not public.is_member(uid) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(c order by (c->>'online')::boolean desc nulls last, c->>'name')
      from (
        select public.circle_card(p, uid,
                 public.is_adult(uid) and exists (select 1 from public.profiles m where m.id = uid and 'dating' = any(coalesce(m.intents, '{}'))),
                 false) as c
          from public.profiles p
         where p.id <> uid and public.is_member(p.id)
           and p.name ilike '%' || replace(replace(term, '%', ''), '_', '') || '%'
           and not public.is_blocked_pair(uid, p.id)
         limit 25
      ) s
  ), '[]'::jsonb);
end;
$$;

-- Your Circle: pendiente/no admitido → locked con el motivo; y solo se proponen miembros.
create or replace function public.your_circle()
returns jsonb language plpgsql security definer set search_path = public
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
  cards        jsonb;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  select * into me from public.profiles where id = uid;
  if not found then
    return jsonb_build_object('day', d, 'position', 0, 'area', null, 'locked', false, 'profiles', '[]'::jsonb);
  end if;
  if not public.is_member(uid) then
    return jsonb_build_object('day', d, 'position', 0, 'area', me.neighborhood, 'locked', true,
                              'reason', me.membership, 'profiles', '[]'::jsonb);
  end if;
  if not public.is_in_bali(uid) then
    return jsonb_build_object('day', d, 'position', 0, 'area', me.neighborhood, 'locked', true,
                              'reason', 'not_in_bali', 'arrival_date', me.arrival_date, 'profiles', '[]'::jsonb);
  end if;

  viewer_dates := 'dating' = any(coalesce(me.intents, '{}')) and public.is_adult(uid);
  my_intents := case when viewer_dates then coalesce(me.intents, '{}')
                     else array_remove(coalesce(me.intents, '{}'), 'dating') end;
  select * into deck from public.discover_decks where user_id = uid and day = d;
  if not found then
    with eligible as (
      select p.*,
        exists (select 1 from public.discover_decks dd
                 where dd.user_id = uid and dd.day > d - 14 and p.id = any(dd.profile_ids)) as seen_recently,
        public.presence_distance_m(uid, p.id) as dist
      from public.profiles p
      where p.id <> uid
        and public.is_member(p.id)
        and public.is_in_bali(p.id)
        and (nullif(trim(p.bio), '') is not null or cardinality(p.sports) > 0)
        and not (p.stay_kind = 'until' and p.stay_until is not null and p.stay_until < d)
        and not public.is_blocked_pair(uid, p.id)
        and not public.are_connected(uid, p.id)
    ),
    scored as (
      select e.id, e.seen_recently,
        (case when e.dist is not null and e.dist < 1000 then 30
              when e.dist is not null and e.dist < 3000 then 22
              when e.dist is not null and e.dist < 10000 then 10
              when e.neighborhood is not null and e.neighborhood = me.neighborhood then 25
              when e.neighborhood = any(launch) then 10 else 0 end)
        + least(30, 10 * coalesce(cardinality(array(
              select unnest(e.sports) intersect select unnest(me.sports))), 0))
        + case when (case when viewer_dates then e.intents else array_remove(e.intents, 'dating') end)
                    && my_intents then 15 else 0 end
        + case when e.arrived_at > now() - interval '3 days' then 15
               when e.created_at > now() - interval '7 days' then 12
               when e.area_since > now() - interval '7 days' and e.neighborhood = me.neighborhood then 8
               else 0 end
        + case when e.active_at > now() - interval '2 days' then 12
               when e.active_at > now() - interval '7 days' then 8
               else 3 end
        + least(8, 2 * coalesce(jsonb_array_length(e.media), cardinality(e.photos), 0))
        + (('x' || substr(md5(uid::text || e.id::text || d::text), 1, 6))::bit(24)::int % 10)
        as score
      from eligible e
    )
    select coalesce(array_agg(id order by seen_recently, score desc, id), '{}') into ids
      from (select id, seen_recently, score from scored
             order by seen_recently, score desc, id limit 15) top;
    insert into public.discover_decks(user_id, day, profile_ids) values (uid, d, ids)
      on conflict (user_id, day) do nothing;
    select * into deck from public.discover_decks where user_id = uid and day = d;
  end if;

  select coalesce(jsonb_agg(
           public.circle_card(p, uid, viewer_dates,
             not exists (select 1 from public.discover_decks dd
                          where dd.user_id = uid and dd.day < d and p.id = any(dd.profile_ids)))
           order by t.ord), '[]'::jsonb)
    into cards
    from unnest(deck.profile_ids) with ordinality as t(pid, ord)
    join public.profiles p on p.id = t.pid
   where not public.is_blocked_pair(uid, p.id) and public.is_member(p.id);

  return jsonb_build_object('day', d, 'position', deck.position, 'area', me.neighborhood,
                            'locked', false, 'profiles', cards);
end;
$$;

-- Perfil de otra persona: misma regla de visibilidad que el resto.
create or replace function public.club_profile(target uuid)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  uid          uuid := auth.uid();
  p            public.profiles;
  viewer_dates boolean;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  if not public.can_see_user(target) then return null; end if;
  select * into p from public.profiles where id = target;
  if not found then return null; end if;
  viewer_dates := public.is_adult(uid)
    and exists (select 1 from public.profiles where id = uid and 'dating' = any(coalesce(intents, '{}')));
  return public.circle_card(p, uid, viewer_dates, false)
         || jsonb_build_object('membership', case when public.is_admin(uid) then p.membership end);
end;
$$;
