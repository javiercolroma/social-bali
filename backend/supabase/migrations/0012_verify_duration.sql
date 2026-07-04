-- Anti-fake, regla FINAL v2 (iterada en dispositivo real): un entreno cuenta si
--   · tiene al menos 1 serie completada, y
--   · dura al menos 60 s en total, y
--   · la MEDIA es ≥ 20 s por serie completada.
-- (El agujero: con 0 series, "elapsed >= sets*20" pasaba trivialmente y un entreno
-- de 2 segundos se podía guardar.) Sin topes de series/XP.
create or replace function public.recompute_verified() returns trigger
language plpgsql as $$
begin
  new.verified := (new.sets >= 1 and new.elapsed >= greatest(60, new.sets * 20));
  return new;
end;
$$;
