-- Avances por-ejercicio (ProgressInsight) de cada sesión, calculados en el cliente al
-- guardar (comparando cada ejercicio con el historial propio) y subidos con la sesión
-- para que los SEGUIDORES los vean en el feed, igual que ven el entreno.
--
-- Retro-compatible: columna nullable jsonb; las builds antiguas ignoran la clave extra y
-- las filas previas quedan en NULL (el cliente las cura al sincronizar). Mismo tratamiento
-- que la columna `items` (jsonb con el detalle de series).
alter table public.workout_sessions
  add column if not exists insights jsonb;
