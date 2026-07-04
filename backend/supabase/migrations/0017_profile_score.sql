-- Gym Score canónico en el perfil: cada cliente sube el SUYO (calculado de sus
-- sesiones fiables); feed/búsquedas lo leen embebido → el mismo número en toda la app.
alter table public.profiles add column if not exists gym_score int not null default 0;
