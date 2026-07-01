# Backend de Forge Loop (Supabase)

Reemplaza los datos demo/bots locales por usuarios reales: auth (Apple/Google),
perfiles, follows, feed, ranking/liga y (más adelante) chat en tiempo real y fotos.

Todo el lado iOS está **gateado**: mientras no rellenes las credenciales en
`ios/GymSwipeIOS/BackendConfig.swift`, la app sigue funcionando 100% en local
(UserDefaults). En cuanto las pongas, empieza a usar Supabase.

## 1. Crear el proyecto (≈10 min)

1. Entra en https://supabase.com → **New project** (elige región cercana, p. ej. `eu-west`).
2. Cuando esté listo, ve a **Project Settings → API** y copia:
   - **Project URL** (`https://xxxx.supabase.co`)
   - **anon public** key
3. Pégalos en `ios/GymSwipeIOS/BackendConfig.swift` (`supabaseURL`, `supabaseAnonKey`).

## 2. Crear el esquema

En **SQL Editor**, pega y ejecuta, en orden:
1. `supabase/migrations/0001_init.sql` (tablas + RLS + triggers)
2. `supabase/migrations/0002_storage.sql` (buckets de fotos)

## 3. Configurar los proveedores de login

En **Authentication → Providers**:

- **Apple**: actívalo. Con Sign in with Apple nativo en iOS, Supabase solo necesita
  tu **Services ID / Bundle ID** (`com.javiercolroma.gymswipeios`) en la lista de
  *Authorized Client IDs*. El iOS usa `signInWithIdToken` con nonce (ya implementado).
- **Google**: actívalo y pega el **iOS client ID** (el mismo `.apps.googleusercontent.com`
  que usas en `AuthConfig.swift`) en *Authorized Client IDs*. iOS envía el `idToken`.

No hace falta configurar URLs de redirect web: el login es nativo y usa **ID tokens**.

## 4. Probar

Compila y entra con Apple o Google. Deberías ver una fila nueva en
**Table Editor → profiles** (la app hace `upsert` del perfil al entrar / tras el onboarding).

## Modelo de datos (resumen)

| Tabla | Para qué |
|-------|----------|
| `profiles` | Identidad pública (1:1 con `auth.users`). Legible por todos, editable solo por ti. |
| `follows` | Seguir / solicitud (cuentas privadas requieren aceptar). |
| `workout_sessions` | Entrenos guardados (feed + insumo del ranking). `items` en JSONB. Visibilidad por RLS. |
| `player_stats` | Resumen server-authoritative (xp, coins, streak, gym_score, league_tier) para ranking/liga. |
| `kudos` / `comments` | Likes y comentarios del feed. |

## Roadmap de migración (local → servidor)

- [x] **Fase 0** — Esquema + RLS + SDK iOS + config gateada.
- [x] **Backend provisionado** — proyecto `xdczilodphmejbzvfdye`: migraciones aplicadas (6 tablas + RLS + buckets) y **proveedor Apple activo** (`external_apple_client_id = com.javiercolroma.gymswipeios`). Credenciales en `BackendConfig.swift`.
- [~] **Fase 1** — Auth real (Apple/Google → Supabase) + upsert de perfil. *Apple: cableado y backend listo; falta la prueba interactiva de login con un Apple ID real. Google: pendiente del OAuth Client ID.*
- [ ] **Fase 2** — Guardar/leer `workout_sessions` (tu histórico vive en el servidor).
- [ ] **Fase 3** — Follows reales + feed (sustituye bots/demo).
- [ ] **Fase 4** — Ranking de amigos + Liga desde datos reales (vistas/RPC por XP semanal).
- [ ] **Fase 5** — Storage de fotos (avatar + entreno), Realtime para chat.
- [ ] **Fase 6** — Anti-trampas v2: el servidor sella timestamps y recalcula `verified`.
