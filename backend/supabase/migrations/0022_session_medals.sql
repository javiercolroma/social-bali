-- Logros/medallas estilo Strava de cada sesión (oro/plata/bronce), calculados en el cliente
-- al guardar y subidos con la sesión para que los SEGUIDORES los vean en el feed.
-- Retro-compatible: columna nullable jsonb (mismo tratamiento que `insights` e `items`).
alter table public.workout_sessions
  add column if not exists medals jsonb;
