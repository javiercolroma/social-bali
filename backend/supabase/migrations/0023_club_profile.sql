-- ─────────────────────────────────────────────────────────────────────────────
-- CLUB SOCIAL · Fase 1 «Identidad» (ver PRODUCT.md)
--
-- El perfil deja de describir solo al ATLETA (sexo, edad, gimnasio) y pasa a
-- describir a la PERSONA: bio, deportes, barrio de Bali, de dónde es, cuánto se
-- queda y qué tipo de conexiones busca. Sin estos campos, Discover solo puede
-- enseñar tarjetas vacías.
--
-- Todo NULLABLE: hay perfiles reales en producción (TestFlight) que no tienen
-- nada de esto. La app los trata como «perfil incompleto», no como error.
-- ─────────────────────────────────────────────────────────────────────────────

-- Bio de una línea: lo que da personalidad a la tarjeta de Discover.
alter table public.profiles add column if not exists bio text;

-- Deportes (rawValue de `Sport`). text[] y no jsonb a propósito: permite cruzar
-- intereses con el operador de solapamiento `&&` en el matching de Discover.
alter table public.profiles add column if not exists sports text[];

-- Barrio DECLARADO dentro de Bali (Canggu, Pererenan, Uluwatu…). No se deriva del
-- GPS: la presencia se redondea a celdas de ~5,5 km y esos barrios caben en 3 km,
-- así que serían indistinguibles. Declararlo es más privado Y más preciso.
alter table public.profiles add column if not exists neighborhood text;

-- De dónde eres (≠ dónde estás). Las columnas `country`/`city` que ya existían
-- siguen significando ubicación actual; no se tocan para no romper datos.
alter table public.profiles add column if not exists home_city text;
alter table public.profiles add column if not exists home_country text;

-- Situación en Bali: 'livingHere' | 'longTerm' | 'until' (+ fecha si aplica).
-- Es información crítica del producto, no un detalle del perfil.
alter table public.profiles add column if not exists stay_kind text;
alter table public.profiles add column if not exists stay_until date;

-- Qué conexiones busca: 'training' | 'friends' | 'dating' (multi-selección).
-- NO crea comunidades separadas: solo afina Discover.
alter table public.profiles add column if not exists intents text[];

-- ─── Índices para Discover ───────────────────────────────────────────────────
-- Discover filtra por zona y cruza deportes/intenciones. GIN porque son arrays y
-- la consulta usa solapamiento (`sports && '{surf,yoga}'`).
create index if not exists profiles_neighborhood_idx on public.profiles(neighborhood);
create index if not exists profiles_sports_idx       on public.profiles using gin(sports);
create index if not exists profiles_intents_idx      on public.profiles using gin(intents);
-- Para no proponer a quien ya se ha ido de la isla.
create index if not exists profiles_stay_until_idx   on public.profiles(stay_until);

-- ─── Nota sobre RLS ──────────────────────────────────────────────────────────
-- No se añaden políticas: estas columnas viven en `public.profiles`, que ya tiene
-- RLS y sus políticas desde 0001_init.sql. Son campos de perfil público dentro
-- del club, con la misma visibilidad que el nombre o el avatar.
