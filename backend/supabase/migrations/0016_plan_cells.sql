
-- Distancia en Partner: el plan hereda la CELDA (~5 km) del perfil del autor al
-- publicarse (trigger). Nunca coordenadas exactas.
alter table public.training_plans add column if not exists cell_lat double precision;
alter table public.training_plans add column if not exists cell_lon double precision;
create or replace function public.plan_inherit_cell() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select geo_cell_lat, geo_cell_lon into new.cell_lat, new.cell_lon
  from profiles where id = new.user_id;
  return new;
end;
$$;
drop trigger if exists plan_cell on public.training_plans;
create trigger plan_cell before insert on public.training_plans
  for each row execute function public.plan_inherit_cell();
