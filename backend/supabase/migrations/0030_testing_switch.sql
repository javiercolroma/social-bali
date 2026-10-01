-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Interruptor de pruebas: «hay que estar en Bali» (2026-10-01)
--
-- Mientras se prueba la app desde fuera de Bali, la puerta de llegada (0029) se
-- puede apagar sin tocar código: `require_bali = false` → todo el mundo cuenta
-- como «en Bali» (Circle, conectar) y el Circle no filtra por ubicación.
-- ANTES DE ABRIR A GENTE REAL:
--   update public.app_settings set value = 'true' where key = 'require_bali';
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.app_settings (
  key   text primary key,
  value text not null
);
alter table public.app_settings enable row level security;
-- Sin políticas: solo lo leen las funciones del servidor.

insert into public.app_settings (key, value) values ('require_bali', 'false')
  on conflict (key) do nothing;

create or replace function public.require_bali()
returns boolean
language sql
stable
security definer
set search_path = public
as $$ select coalesce((select value::boolean from public.app_settings where key = 'require_bali'), true) $$;
revoke all on function public.require_bali() from public, anon, authenticated;

create or replace function public.is_in_bali(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not public.require_bali()
      or coalesce((select last_in_bali_at > now() - interval '7 days'
                     from public.profiles where id = uid), false)
$$;
revoke all on function public.is_in_bali(uuid) from public, anon, authenticated;
