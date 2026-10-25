-- ─────────────────────────────────────────────────────────────────────────────
-- SALIDA A PRODUCCIÓN · ejecutar UNA vez (backend/run-sql.sh <ref> backend/release/go_live.sql)
-- 1) El Circle vuelve a exigir estar en Bali (o un código de acceso).
-- 2) Fuera los perfiles de prueba (is_seed), su cuenta test.viewer y sus ficheros.
-- 3) Códigos de acceso: revisión de Apple y fundador.
-- ─────────────────────────────────────────────────────────────────────────────
update public.app_settings set value = 'true' where key = 'require_bali';

-- Ficheros subidos por la cuenta de prueba (caras IA, demo): solo las filas; el bucket
-- se limpia solo al no quedar referencias.
delete from storage.objects where bucket_id = 'media' and name like '5eed0000-0000-4000-8000-0000000000aa/%';

-- La cascada se lleva perfil, presencia, momentos, mensajes y ajustes.
delete from auth.users where id in (select id from public.profiles where is_seed);
delete from public.discover_decks;   -- los mazos de hoy apuntaban a perfiles borrados

insert into public.access_codes (code, label, grants_days, max_uses, expires_at) values
  ('APPLEREVIEW', 'App Review (Apple)', 90, null, now() + interval '1 year'),
  ('FOUNDER',     'Equipo',             365, 10,   null)
on conflict (code) do nothing;

select (select count(*) from public.profiles) as profiles_left,
       (select value from public.app_settings where key = 'require_bali') as require_bali,
       (select count(*) from public.access_codes) as codes;
