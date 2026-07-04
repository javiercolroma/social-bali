-- Anti-fake, regla FINAL (iterada con el usuario): ÚNICO criterio = duración.
-- Media de al menos 20 s por serie completada en la sesión. Sin tope de series
-- ni de XP (decisión de producto: las sesiones largas legítimas no se penalizan).
-- El cliente muestra la pantalla final normal con un aviso "no se guardará" y
-- no ofrece el guardado de sesiones implausibles.
create or replace function public.recompute_verified() returns trigger
language plpgsql as $$
begin
  new.verified := (new.elapsed >= new.sets * 20);
  return new;
end;
$$;
