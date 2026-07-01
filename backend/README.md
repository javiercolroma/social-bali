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
- [x] **Fase 1** — Auth real + upsert de perfil. **Email/contraseña VALIDADO end-to-end** (test con 2 usuarios reales: signup → insertar sesión/perfil/follow → feed cruzado por RLS → visibilidad `onlyMe` respetada). Apple: cableado y backend listo, falta la prueba interactiva con un Apple ID real. Google: pendiente del OAuth Client ID (paso del usuario). ⚠️ **`mailer_autoconfirm` está ON** (email usable al instante, sin verificación) — cómodo para bring-up/tests; antes de lanzar, valorar activar confirmación de email o pasar a magic-link.
- [x] **Fase 2** — `workout_sessions` en el servidor: cada entreno guardado se sube (`upsertSession`, `id` UUID compartido local↔servidor); al iniciar sesión/arrancar se fusiona el histórico (`syncSessionsFromBackend`, server como fuente de verdad + sube las locales que falten). Shape validado contra el esquema en vivo (PostgREST acepta la fila; RLS la bloquea solo por `auth.uid()`). Falta la foto (llega con Storage, Fase 5).
- [~] **Fase 3** — Capa de grafo social + feed **construida y validada** (`Backend`: `setFollow`/`unfollow`/`fetchFollowing`/`fetchFollowers`/`searchProfiles`/`fetchProfiles`/`fetchFeed`; `FollowRow`; el feed se apoya en la RLS para filtrar a lo visible). Validado contra el esquema en vivo (insert de follow → RLS 42501; selects → 200). **Falta enchufarlo a la UI**, que hoy usa datos demo/bots — se hará cuando (a) el login Apple esté probado end-to-end y (b) haya ≥2 usuarios reales para que no salga vacío.
- [~] **Fase 4** — Ranking/Liga real: **motor construido y validado** (RPC `weekly_xp_leaderboard`: XP de la semana ISO por usuario, solo verificado; `Backend.fetchWeeklyLeaderboard` + `LeaderRow`). Validado por REST (200). Falta enchufarlo a `RankingView`/`LeagueView` (hoy usan bots) — cuando haya usuarios reales.
- [ ] **Fase 5** — Storage de fotos (avatar + entreno), Realtime para chat.
- [x] **Fase 6** — Anti-trampas v2: **trigger `recompute_verified`** en `workout_sessions` (before insert/update) recalcula `verified` en el servidor con la misma heurística (≥20 s/serie, ≤60 series, XP ≤600) → el cliente ya no puede marcar `verified=true` a mano. Validado: sesión rápida enviada como `true` → el server la deja en `false`; la legítima queda `true`. (Mejora futura: timestamps por serie para blindar `elapsed`.)
