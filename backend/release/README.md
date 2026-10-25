# Salida a producción (hecho el 2026-10-25)

1. Ficheros de la cuenta de prueba: borrados por la API de Storage (prefijo `5eed0000-…/` del bucket `media`).
2. `run-sql.sh <ref> release/go_live.sql`: `require_bali = true`, fuera perfiles `is_seed` + `test.viewer`, códigos de acceso.
3. Códigos: `APPLEREVIEW` (revisión de Apple, 90 días, caduca en 1 año) y `FOUNDER` (365 días, 10 usos).
   Añadir más: `insert into access_codes (code, label, grants_days, max_uses) values ('CODE', 'para quién', 30, 5);`
