-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Códigos de acceso (salida a producción, 2026-10-25)
--
-- El Circle exige estar en Bali (require_bali = true desde el lanzamiento). Un código
-- de acceso lo abre desde fuera durante un tiempo: para el equipo de revisión de
-- Apple, para el equipo y para invitados. Se canjea desde la pantalla de llegada.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.access_codes (
  code        text primary key,                 -- se guarda en MAYÚSCULAS
  label       text,                             -- para qué es («App Review», «Founder»)
  grants_days int  not null default 30,         -- cuánto abre el Circle cada canje
  max_uses    int,                              -- null = sin límite
  uses        int  not null default 0,
  expires_at  timestamptz,
  created_at  timestamptz not null default now()
);
alter table public.access_codes enable row level security;
-- Sin políticas: solo se leen desde la función de abajo.

alter table public.profiles add column if not exists bali_override_until timestamptz;

create or replace function public.redeem_access_code(code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  c   public.access_codes;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  select * into c from public.access_codes
   where access_codes.code = upper(trim(redeem_access_code.code))
     and (expires_at is null or expires_at > now())
     and (max_uses is null or uses < max_uses);
  if not found then return false; end if;
  update public.access_codes set uses = uses + 1 where access_codes.code = c.code;
  update public.profiles
     set bali_override_until = greatest(coalesce(bali_override_until, now()), now()) + make_interval(days => c.grants_days)
   where id = uid;
  return true;
end;
$$;
revoke all on function public.redeem_access_code(text) from public, anon;
grant execute on function public.redeem_access_code(text) to authenticated;

-- «Estar en Bali» = ubicado en Bali en los últimos 7 días, o con un código vigente.
create or replace function public.is_in_bali(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not public.require_bali()
      or coalesce((select last_in_bali_at > now() - interval '7 days'
                       or bali_override_until > now()
                     from public.profiles where id = uid), false)
$$;
revoke all on function public.is_in_bali(uuid) from public, anon, authenticated;
