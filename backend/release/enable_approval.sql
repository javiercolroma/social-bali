-- Encender la aprobación manual cuando la 1.1 esté en la tienda (ejecutar UNA vez):
--   backend/run-sql.sh <ref> backend/release/enable_approval.sql
-- Todo el que ya estaba dentro sigue dentro; a partir de aquí, los nuevos quedan pendientes.
update public.profiles set membership = 'approved' where membership = 'pending';
update public.app_settings set value = 'true' where key = 'require_approval';
select (select value from public.app_settings where key = 'require_approval') as require_approval,
       count(*) filter (where membership = 'approved') as approved from public.profiles;
