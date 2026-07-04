-- Recalibra el anti-fake: 15 s de MEDIA por serie (antes 20). Más justo con
-- superseries/EMOM y series rápidas sueltas, sin dejar pasar sesiones falseadas.
-- El cliente además BLOQUEA el guardado de sesiones implausibles (no solo las marca).
create or replace function public.recompute_verified() returns trigger
language plpgsql as $$
begin
  new.verified := (new.elapsed >= new.sets * 15 and new.sets <= 60 and new.xp <= 600);
  return new;
end;
$$;
