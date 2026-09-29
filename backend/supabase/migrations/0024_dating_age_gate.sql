-- ─────────────────────────────────────────────────────────────────────────────
-- CLUB SOCIAL · Fase 1 · «Dating» solo para mayores de 18 (ver PRODUCT.md, tensión #3)
--
-- Requisito de la App Store para una app con intención de citas. La app ya lo
-- impide en la interfaz; esto es la garantía del SERVIDOR, para que un cliente
-- viejo o manipulado no pueda saltárselo.
--
-- Para comprobar la edad, el servidor necesita la fecha de nacimiento. NO va en
-- `profiles` (que ya tenía una columna `birthdate` que nunca se usó): esa tabla
-- es de lectura pública dentro del club, y ocultar una columna con permisos por
-- columna rompe los upsert de la app — PostgREST devuelve la fila (`select *`)
-- y un `ON CONFLICT DO UPDATE` con RLS exige leer lo que actualiza. Probado.
-- Una tabla aparte, legible solo por su dueño, no toca nada de lo que funciona.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.profile_private (
  id         uuid primary key references auth.users(id) on delete cascade,
  birthdate  date,
  updated_at timestamptz not null default now()
);

alter table public.profile_private enable row level security;

drop policy if exists profile_private_select_self on public.profile_private;
create policy profile_private_select_self on public.profile_private
  for select using (id = auth.uid());
drop policy if exists profile_private_insert_self on public.profile_private;
create policy profile_private_insert_self on public.profile_private
  for insert with check (id = auth.uid());
drop policy if exists profile_private_update_self on public.profile_private;
create policy profile_private_update_self on public.profile_private
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ─── La regla ────────────────────────────────────────────────────────────────
-- Sin fecha de nacimiento tampoco: la edad no se presupone.
-- `security definer`: el trigger de `profiles` necesita leer la fecha aunque la
-- RLS de `profile_private` no lo dejaría en otro contexto.
create or replace function public.is_adult(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select birthdate <= (current_date - interval '18 years')::date
       from public.profile_private where id = uid),
    false);
$$;
revoke all on function public.is_adult(uuid) from public, anon, authenticated;

-- Trigger y no CHECK: la regla depende de la fecha de HOY y cruza dos tablas.
create or replace function public.enforce_dating_age()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if 'dating' = any(coalesce(new.intents, '{}')) and not public.is_adult(new.id) then
    raise exception 'dating requires being 18 or older'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_dating_age on public.profiles;
create trigger profiles_dating_age
  before insert or update of intents on public.profiles
  for each row execute function public.enforce_dating_age();

-- Y al revés: bajar la fecha por debajo de 18 teniendo «dating» activo.
create or replace function public.enforce_dating_age_on_birthdate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.birthdate is null or new.birthdate > (current_date - interval '18 years')::date)
     and exists (select 1 from public.profiles p
                  where p.id = new.id and 'dating' = any(coalesce(p.intents, '{}'))) then
    raise exception 'dating requires being 18 or older'
      using errcode = 'check_violation';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profile_private_dating_age on public.profile_private;
create trigger profile_private_dating_age
  before insert or update on public.profile_private
  for each row execute function public.enforce_dating_age_on_birthdate();
