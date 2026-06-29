# Memoria del proyecto: Gym Swipe iOS

Ultima actualizacion: 2026-06-28

> ⚠️ **MIGRACION A NATIVO (en curso).** La app iOS se esta reescribiendo a **SwiftUI 100% nativa** (Fase 1 completada). El antiguo enfoque web en `WKWebView` queda **deprecado**: el target iOS ya NO carga `WebDist` ni usa la web; ahora arranca `RootView` (SwiftUI). El codigo web en `src/` permanece en el repo pero **no lo usa la app**. La documentacion de abajo (secciones 1-24) describe la app WEB original y se conserva como referencia funcional/de producto mientras se porta a Swift.
>
> **App nativa (Swift) — archivos clave en `ios/GymSwipeIOS/`:** `GymSwipeIOSApp.swift` (entry), `AppStore.swift` (estado + persistencia en UserDefaults + acciones), `Models.swift`, `GymScore.swift` (logica de score), `LocationManager.swift` (CoreLocation nativo), `RootView.swift` (TabView nativo + cabecera + sheets), `TrainView/PlanView/RankingView/PartnerView/ProfileView.swift`, `SocialViews.swift` (mensajes, chat, amigos, notificaciones, perfil de amigo, alta de cuenta), `Components.swift`, `Theme.swift`.
>
> **Estado Fase 1:** compila y corre. Implementado nativo: alta de cuenta, Entreno (cargar/serie hecha-saltada/descanso/cronometro), Plan (biblioteca + preview + cargar), Comunidad = Ranking (tabla + mapa MapKit con zoom + ubicacion real; el Gym Score se movió a Actividad ▸ Progreso) + Partner (planes, crear, aceptar→chat, descartar, tus planes con tu nombre) en un selector segmentado, Actividad (historial personal + estadisticas), Perfil (nivel/XP/datos), Social completo (mensajes/chat/amigos/buscar/notificaciones/perfil de amigo), integración con la app **Salud (HealthKit)** para leer la frecuencia cardíaca en el entreno. Persistencia en `UserDefaults` (clave `forge-native-v1`).

> **Salud / Frecuencia cardíaca (HealthKit):** `HealthManager` (singleton `@MainActor`) pide permiso de LECTURA de frecuencia cardíaca (`requestAuthorization(toShare: [], read: [.heartRate])`) y, durante la sesión, recoge muestras con `HKAnchoredObjectQuery` (BPM en vivo + media + máximo). En `TrainView` hay una píldora ❤️ en la cabecera: "Conectar Salud" si no está conectado, o los `ppm` en vivo si lo está; el BPM mostrado es la muestra más reciente por `endDate` (HealthKit no garantiza orden). Al guardar, `avgHeartRate`/`maxHeartRate` se almacenan en `WorkoutSession` (campos opcionales, seguros para datos antiguos) y se muestran en el resumen y en `ActivityDetailView`. La captura se reinicia por IDENTIDAD del entreno cargado (`onChange(of: exercises.first?.id)`) para no contaminar al cargar otro entreno sin guardar, y arranca también si conectas Salud a mitad de sesión (`onChange(of: health.connected)`). El permiso de Salud se ofrece en el **onboarding al crear la cuenta** (`AccountSetupView`: tarjeta "Conectar con Salud" + se solicita al pulsar "Empezar"); también hay sección "Salud" en Perfil. En el **resumen** al finalizar se muestran FC media y FC máx (se quitaron Volumen kg y XP), y el tiempo de duración se **congela** al terminar (`finalElapsed`) para que no siga corriendo. Durante la sesión, el círculo de descanso está **siempre visible**: muestra la cuenta atrás cuando hay descanso activo y el estado "¡Haz tu serie!" al empezar el entreno o al terminar el descanso. project.yml: entitlement `com.apple.developer.healthkit`, framework `HealthKit.framework`, `NSHealthShareUsageDescription` (solo lectura; sin string de escritura). Nota: el pulso en vivo requiere Apple Watch (u otra fuente) escribiendo en Salud; en simulador/iPhone sin watch la UI degrada a "—".
>
> **Añadido tras Fase 1:** Plan con "Crear entrenamiento" (formulario de ejercicios) y sin tarjeta "Biblioteca; Ranking con scope "Amigos" por defecto (ranking real de tus amigos); Partner con "Cuándo" y "Dónde" en el creador y flecha atrás a la izquierda (en vez de X); foto de perfil seleccionable (PhotosPicker) y ajustable (arrastrar/pellizcar), tanto en Perfil como al crear cuenta (`Account.photoData/scale/offset`, `PhotoSupport.swift`).
>
> **Resumen del entreno (al guardar):** nombre editable (con default = nombre del entreno), campo "¿Qué tal te ha ido?" (notas), foto opcional (PhotosPicker) y visibilidad (Todos / Seguidores / Solo yo). Se guarda como `WorkoutSession` (modelo nuevo, persistido en `store.sessions`) además del historial/XP. Pendiente: mostrar las sesiones propias en el muro Social.
>
> **Entreno (flujo de sesion):** boton "Finalizar entrenamiento"; al terminar se muestra un RESUMEN tipo Strava (duracion, series, volumen, XP) con Guardar/Descartar (el historial/XP/racha se confirman solo al Guardar). Tras Guardar/Descartar se vuelve al estado de carga, que ahora muestra un único estado vacío limpio y centrado (icono mancuerna en círculo verde, "¿Qué entrenamos hoy?" + un solo botón primario "Elegir entreno") que cambia a la pestaña Plan (`onGoToPlan` → `tab = 1`). Se quitaron la lista "TUS MÁS FRECUENTES" y el botón "Otros entrenos".
>
> **Plan / entrenos (nativo):** crear entreno con formulario mejorado (tarjetas de ejercicio con steppers redondos, boton "Añadir ejercicio" con borde discontinuo). Grupos personalizados: cada entreno tiene `block` como grupo (chips sugeridos + grupo nuevo escribible); Plan agrupa por grupos. Editar entrenos (boton Editar en el preview → reabre el formulario; los built-in se editan creando copia, los tuyos se actualizan in situ). Eliminar con papelera: menu contextual (long-press) en la fila + boton en el preview, ambos con confirmacion "¿Eliminar?".
>
> **Partner (nativo):** "Buscar compañero" abre el creador como POP-UP (sheet `CreatePlanView`) con Cuándo/Dónde/Qué/Plazas y opcion "Me adapto" en todos; flecha "Atrás" arriba-izquierda. Eliminar plan propio pide confirmacion.
>
> **Pantalla de entreno (pulida):** cabecera con nombre del entreno + barra de progreso animada; tarjeta de ejercicio con "SERIE X DE Y", nombre grande, dots de serie animados (spring), stats con iconos; botones Hecho/Saltar grandes con háptica + sonido (`SessionFX.swift`: `Haptics`, `SoundFX`); transicion deslizante entre ejercicios; banner de DESCANSO con anillo circular countdown (+15s / saltar) y aviso al terminar; resumen final con CONFETI (`ConfettiView`). Sonidos/Vibración con toggles en Perfil (`@AppStorage fxSound/fxHaptics`).
>
> **Entreno (edición en vivo + descanso):** reps y peso EDITABLES durante la sesión con steppers − / + (peso en pasos de 2.5 kg; icono mancuerna en vez de báscula). El descanso por defecto es 2 min, se muestra en mm:ss y NO tiene botón de saltar; al agotarse NO para: sigue contando en "overtime" (color ámbar, "+m:ss", "Te estás pasando · llevas X descansando") para llevar la cuenta. Se quitó el stat fijo de descanso de la tarjeta.
>
> **Feedback global (`FX` en SessionFX.swift):** háptica en toda la app (cambio de pestaña = selection, taps, success al aceptar/crear/guardar, warning al borrar) respetando los toggles Sonidos/Vibración. Sonidos SOLO en momentos clave para no cansar: aceptar amistad, aceptar entrenamiento y crear cuenta (además de los sonidos propios de la sesión de entreno). `FX.tap/selection/success(sound:)/warning`.
>
> **Navegación:** Perfil se movió de la tab bar al header (avatar arriba a la derecha junto a Mensajes/Notificaciones → abre ProfileView en sheet). Barra inferior PERSONALIZADA (`CustomTabBar`): orden **Social · Plan · Entreno · Comunidad · Actividad**, con **Entreno en el centro como botón especial** (círculo verde elevado). La navegación es un `ZStack` de 5 pantallas controlado por un único `@State tab` (no se pierde el estado de cada pestaña). Tags: Social=0, Plan=1, Entreno=2, Comunidad=3, Actividad=4 (onGoToPlan→1, onLoaded→2). **Comunidad** (`CommunityView`) fusiona Ranking + Partner de forma natural mediante un selector segmentado (Ranking / Partner) sin perder ninguna funcionalidad: ambas vistas (`RankingView`, `PartnerView`) viven en un ZStack y conservan su estado (scroll, mapa, ubicación) al cambiar de sección. **Actividad** (`ActivityView`) tiene dos secciones con selector segmentado: **Progreso** y **Actividades**. *Progreso* contiene: una tarjeta de **racha** horizontal de extremo a extremo (el número dentro de un icono de llama 🔥 + "¡En racha!" y subtítulo aclaratorio: la racha NO son días consecutivos, son entrenos encadenados sin pasar más de 3 días de descanso); la tarjeta de **Gym Score** (movida desde Comunidad: puntuación + tier + fiabilidad + barras de pilares Fuerza/Constancia/Progreso/Volumen/Calidad/Variedad); el **calendario mensual** (`TrainingCalendarView`) con todos los días del mes (huecos vacíos para los días del mes anterior/siguiente, NO se muestran días de otros meses), navegación de mes ‹ ›, días entrenados resaltados en verde, marca del día actual, badge si hay varios entrenos y contador del mes; al tocar un día entrenado se abre un pop-up (`DaySessionsSheet`) con los entrenos de ese día, y desde ahí el detalle (`ActivityDetailView`). Y las métricas de carga: (1) **Tendencia** — variación % del 1RM estimado medio entre el primer y el último registro, promediada entre ejercicios; (2) **Fuerza por ejercicio** — 1RM estimado por ejercicio con fórmula de Epley `w·(1+reps/30)` tomando la mejor serie de cada sesión, con delta vs primer registro y mini-sparkline (Swift Charts); incluye un botón de información (ⓘ gris) que explica en un alert qué es el 1RM estimado y la fórmula de Epley. *Actividades* contiene **solo** el histórico: la lista de tus sesiones (`store.sessions`) ordenadas por fecha; tap → `ActivityDetailView`. **Perfil** se movió al margen superior IZQUIERDO del header (avatar a la izquierda del título; Mensajes/Notificaciones quedan a la derecha). **Racha (`currentStreak`)**: es una racha "de gimnasio", no exige entrenar a diario; se mantiene mientras no pasen más de 3 días entre entrenos (y el último sea de los últimos 3 días). Cada día entrenado dentro de esa ventana de 3 días suma +1; si se superan los 3 días sin entrenar, la racha se reinicia a 0. Pestaña **Social** (`SocialFeedView`) con selector de cápsulas **Seguidos / Para ti** (ZStack, conserva estado). **Seguidos**: si sigues a gente, muro = tus posts + los de quien sigues por fecha; si no sigues a nadie (usuario nuevo), muestra bienvenida "Hola, {nombre} 👋" + (si tienes) tus entrenos + sección "CERCA DE TI" + enlace a Para ti. **Para ti** (descubrimiento, nunca tu propio contenido): "TE QUIEREN SEGUIR" (solicitudes `.incoming`, aceptar/descartar), "CERCA DE TI" (las personas más cercanas que no sigues, ordenadas por distancia real usando `LocationManager`/`CLLocation` —posición determinista alrededor de ti, coherente con el mapa de Ranking— o distancia sintética estable si no hay ubicación; chip "📍 a {dist}"), y "DESCUBRE ENTRENOS" (posts de no-seguidos ordenados por cercanía, máx 2/persona, ~12, con botón "Seguir" en línea). El permiso de ubicación se pide cuando ya hay cuenta (no sobre el alta). Seguir es inmediato (`store.follow`, == amigo) con toast "Ahora sigues a {nombre}". Cada post: avatar, nombre, hora, ubicación, título, nota, foto, métricas (Tiempo/Series/Ejerc. — se eliminó "kg vol." de todas las tarjetas y del detalle por ser un número grande poco útil; el pilar "Volumen" del Gym Score 0–100 se mantiene) y fila de acciones **estilo Instagram** (sin fondo/cápsula, no verde): **like** (corazón, se pone rojo al pulsar, contador; persistido en `store.appliedKudos`), **comentario** (icono `bubble.right` con nº de comentarios) y **compartir** (avión de papel `paperplane` con nº de veces compartido). **Comentarios estilo Instagram** (`CommentsSheet`): cada comentario muestra autor, texto, antigüedad ("hace …" vía `relativeTime`), botón de **like** por comentario y **Responder** (respuestas anidadas 1 nivel); caja de composición con "Respondiendo a {nombre}"; comentarios demo deterministas por post para que el muro se sienta vivo. Los **pop-ups (sheets)** ya no llevan botón "Cerrar": se cierran deslizando hacia abajo (gesto nativo de iOS); el chat (fullScreenCover) mantiene su flecha de volver. `seedDemo` arranca SIN seguidos (Mika pasa a recomendación, Leo a solicitud entrante) para mostrar la experiencia de usuario nuevo. Tap en un post → detalle; tap en una persona → su perfil. Ranking → mapa con usuarios demo cerca de tu ubicación, pin tocable → ficha (`MapUserSheet`) con perfil y añadir amigo.
>
> **Perfil:** selector de idioma (🌐, solo Español activo); edad por FECHA DE NACIMIENTO (DatePicker) con edad calculada; país (lista del sistema en español) y ciudad (búsqueda MapKit sesgada al país). Catálogo de ejercicios con autocompletado en crear/editar entreno (`Exercises.swift`); grupos personalizados con desplegable y "Crear «X»".
>
> **Pendiente de portar/afinar:** gesto de swipe opcional del deck, edicion inline de peso/reps durante la sesion, compartir entrenos, calendario de progreso.
>
> **Futuro (autenticacion):** hoy la cuenta es LOCAL (nombre + @handle + foto en el dispositivo, sin login). Para multiusuario real hara falta backend con auth: email+contraseña y/o **Sign in with Apple** (OBLIGATORIO por Apple si se ofrece login de terceros). Requiere servidor (usuarios, sesiones, recuperacion de contraseña) — pendiente de decidir stack (p. ej. Supabase/Firebase para ir rapido).
>
> **Comandos nativos:** `npm run ios:generate` (xcodegen) tras añadir archivos Swift; build con `xcodebuild -project ios/GymSwipeIOS.xcodeproj -scheme GymSwipeIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`. Ya NO hace falta `npm run ios:sync`.


Este documento es la memoria viva del proyecto. Sirve para retomar el desarrollo aunque se pierda la sesion: contexto de producto, arquitectura, decisiones tecnicas, estado funcional, bugs conocidos, comandos de trabajo y siguientes pasos.

## 1. Resumen ejecutivo

Gym Swipe iOS es una app de entrenamiento mobile-first construida con React, Vite y TypeScript, empaquetada tambien como app iOS nativa mediante un proyecto Xcode que carga la app web en un `WKWebView`.

La experiencia principal es entrenar con tarjetas tipo swipe:

- Cada ejercicio aparece como una tarjeta.
- El usuario marca cada serie como hecha con check verde.
- El usuario marca cada serie como saltada con X roja.
- El ejercicio cambia cuando se completan o saltan todas sus series.
- El entrenamiento finaliza automaticamente al cerrar el ultimo ejercicio.

El producto ha evolucionado desde una app sencilla de tarjetas hacia una app social/gamificada de entrenamiento con:

- Entrenamientos por defecto al instalar.
- Entrenamientos creados por el usuario.
- Bloques personalizables de entrenamientos, por ejemplo `Pierna`, `Push`, `Torso`, `Full body`.
- Previsualizacion antes de cargar un entrenamiento.
- Edicion y eliminacion de entrenamientos.
- Sesion activa con cronometro, descansos, sonidos, mascota y feedback.
- Historial local por serie.
- Perfil con foto, datos basicos, XP, nivel y calendario.
- Ranking simulado con mapa.
- Partner/social para buscar companero de entreno.
- Comparticion de entrenamientos mediante enlace.
- Proyecto Xcode listo para ejecutar en simulador o iPhone.

El criterio de producto actual es: experiencia movil directa, sencilla, tactil y dinamica. La app debe abrir en una pantalla usable, no en una landing. Se evitan textos explicativos largos dentro de la UI.

## 2. Ubicacion, repo y estado Git

Ruta local real en el Mac:

```txt
/Users/javiercolas/Documents/gym-swipe-ios
```

Repositorio remoto:

```txt
git@github.com:javiercolroma/gym-swipe-ios.git
```

Rama principal:

```txt
main
```

Ultimo commit relevante subido:

```txt
357abd3 Add iOS wrapper and workout flow updates
```

Estado despues del ultimo push:

```txt
main...origin/main
```

Regla acordada con el usuario:

- Cada vez que se hagan cambios de codigo o documentacion, hacer commit y push al repo.
- No dejar cambios locales importantes sin subir.

Comandos Git habituales:

```bash
git status --short --branch
git add .
git commit -m "Mensaje descriptivo"
git push origin main
```

## 3. Stack tecnico

Frontend:

- React 19.
- Vite 8.
- TypeScript 6.
- CSS manual en `src/App.css`.
- Iconos con `lucide-react`.

Persistencia:

- `localStorage`.
- No hay backend todavia.

iOS:

- Xcode completo instalado en `/Applications/Xcode.app`.
- Proyecto Xcode generado en `ios/GymSwipeIOS.xcodeproj`.
- Contenedor nativo SwiftUI con `WKWebView`.
- La app web compilada se copia a `ios/WebDist`.
- El `WKWebView` carga el `index.html` local.

Herramientas:

- Node instalado localmente.
- XcodeGen usado para generar el proyecto desde `ios/project.yml`.
- Runtime iOS Simulator 26.5 instalado.

Nota importante de entorno:

- `xcode-select` puede apuntar a Command Line Tools.
- Para compilar desde terminal se usa:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
```

## 4. Scripts principales

Desarrollo web:

```bash
npm install
npm run dev
```

Validacion web:

```bash
npm run lint
npm run build
```

Sincronizar bundle web para iOS:

```bash
npm run ios:sync
```

Regenerar proyecto Xcode desde `project.yml`:

```bash
npm run ios:generate
```

Abrir Xcode:

```bash
open ios/GymSwipeIOS.xcodeproj
```

Compilar iOS en simulador:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project ios/GymSwipeIOS.xcodeproj \
  -scheme GymSwipeIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

## 5. Archivos importantes

Raiz:

```txt
README.md
package.json
vite.config.ts
.gitignore
```

App React:

```txt
src/App.tsx
src/App.css
src/index.css
src/main.tsx
src/exerciseCatalog.ts
```

PWA/public:

```txt
public/sw.js
public/manifest.webmanifest
public/icon-512.png
public/apple-touch-icon.png
```

iOS:

```txt
ios/project.yml
ios/GymSwipeIOS.xcodeproj
ios/GymSwipeIOS/GymSwipeIOSApp.swift
ios/GymSwipeIOS/ContentView.swift
ios/GymSwipeIOS/Info.plist
ios/GymSwipeIOS/Assets.xcassets
ios/WebDist
ios/README.md
```

Scripts:

```txt
scripts/prepare-ios-webdist.mjs
```

Descripcion rapida:

- `src/App.tsx`: contiene la mayor parte de logica, tipos, estado y vistas.
- `src/App.css`: layout, responsive, animaciones, estilos de entrenamiento, plan, perfil, ranking y partner.
- `src/exerciseCatalog.ts`: catalogo local de ejercicios para autocompletado.
- `scripts/prepare-ios-webdist.mjs`: adapta el `index.html` de Vite para que funcione en `WKWebView` con archivos locales.
- `ios/project.yml`: fuente declarativa para regenerar el proyecto Xcode.
- `ios/WebDist`: bundle web compilado para iOS.

## 6. Arquitectura actual

La app sigue concentrada principalmente en `src/App.tsx`. Es una decision pragmatica para iterar rapido, pero ya es uno de los mayores riesgos de mantenimiento.

Estado principal:

```ts
type WorkoutState = {
  schemaVersion: 3
  exercises: Exercise[]
  player: Player
  lastAction: string
  history: HistoryEntry[]
  prs: Record<string, PersonalRecord>
  preferences: Preferences
  profile: Profile
  savedWorkouts: WorkoutTemplate[]
  hiddenWorkoutIds: string[]
  undoStack: Snapshot[]
}
```

Entrenamiento:

```ts
type WorkoutTemplate = {
  name: string
  description: string
  block?: string
  workout?: string
  exercises?: Exercise[]
}
```

Puntos importantes:

- `savedWorkouts` guarda los entrenamientos creados por el usuario.
- `hiddenWorkoutIds` oculta entrenamientos por defecto eliminados.
- `block` agrupa entrenamientos en bloques personalizados.
- Si un entrenamiento por defecto no tiene bloque, se muestra en `Por defecto`.
- Si un entrenamiento creado no tiene bloque, se muestra en `Otros` (antes `Mis entrenos`; hay migración automática en `AppStore.init` que reasigna los antiguos `Mis entrenos` → `Otros`).

Storage actual:

```ts
const storageKey = 'gym-swipe-ios-state-v2'
const marketStorageKey = 'gym-swipe-ios-state-v3'
const legacyStorageKey = 'gym-swipe-ios-state-v1'
```

No hay migraciones complejas todavia. `loadState` normaliza datos antiguos y rellena campos nuevos cuando faltan.

## 7. Flujo de entrenamiento

### Estado de sesion

La sesion tiene estos estados:

```ts
type SessionStatus = 'ready' | 'active' | 'finished'
```

Comportamiento:

- `ready`: hay entrenamiento cargado pero no iniciado, o se pide seleccionar uno.
- `active`: el usuario ha pulsado iniciar y los botones check/X estan activos.
- `finished`: entrenamiento terminado.

### Series

La unidad real de progreso es la serie, no el ejercicio completo.

- Cada check verde suma una serie completada.
- Cada X roja suma una serie saltada.
- El ejercicio se cierra al llegar a `sets`.
- Se crea un `HistoryEntry` por serie.

Metadatos guardados por serie:

- `setIndex`
- `totalSetsInExercise`
- `setDurationSeconds`
- `restBeforeSeconds`
- `exerciseRestSeconds`
- `sessionElapsedSeconds`
- `sessionId`
- `workoutName`

### Finalizacion automatica

Cambio reciente:

- Si el usuario cierra el ultimo ejercicio del entrenamiento, la app finaliza automaticamente.
- Ya no debe quedarse en el estado visual anterior de `Entreno cerrado` con boton `Reiniciar`.
- Al terminar se muestra `Entreno finalizado`.
- El boton final ofrece elegir otro entrenamiento.

Esto se implemento en `completeExercise`, detectando:

```ts
const finishesWorkout = closesExercise && pending.length === 1
```

Cuando `finishesWorkout` es verdadero:

- Se limpia el descanso.
- Se actualiza el tiempo final.
- `sessionStatus` pasa a `finished`.
- El feedback usa sonido de final.
- `lastAction` pasa a `Entreno finalizado`.

## 8. Barra check / X / deshacer

La barra de acciones de entrenamiento contiene:

- Deshacer.
- X roja para saltar serie.
- Check verde para completar serie.

Problemas tratados:

- En iPhone la barra quedaba demasiado arriba.
- Luego quedaba demasiado abajo al cambiar al segundo ejercicio.
- El menu inferior podia taparla.
- `position: sticky` no era fiable dentro del layout movil.
- Animaciones con `transform` en contenedores podian interferir con `position: fixed`.
- El deslizamiento vertical de la app podia fallar o sentirse irregular si el contenido crecia dentro del mock de telefono.

Estado actual:

- `.phone-stage` usa una estructura grid con altura de viewport.
- `.screen-body` es el contenedor desplazable en todas las pestanas.
- `.action-dock` usa `position: fixed` en movil.
- Se situa por encima del menu inferior.
- Usa `env(safe-area-inset-bottom)`.
- `view-train` reserva espacio inferior.
- Se eliminaron transforms de `@keyframes view-enter` para evitar que elementos fijos queden atrapados en un stacking context transformado.

CSS relevante:

```css
@media (max-width: 520px) {
  .action-dock {
    position: fixed;
    left: 12px;
    right: 12px;
    bottom: max(92px, calc(env(safe-area-inset-bottom) + 86px));
  }
}
```

Pendiente de validar siempre en iPhone real:

- Que no tape reps/peso.
- Que no tape el menu inferior.
- Que siga correctamente centrada al pasar de un ejercicio a otro.

## 9. Plan / Entrenamientos

### Estado anterior

Antes habia grupos por nivel:

- Iniciacion.
- Intermedio.
- Avanzado.
- Propios.

Esto se elimino por peticion del usuario.

### Estado actual

La pantalla `Plan` ahora es una biblioteca unica de entrenamientos agrupada por bloques.

Bloques:

- `Por defecto`: entrenamientos que vienen con la app.
- `Otros`: fallback para entrenamientos creados por el usuario sin grupo (antes `Mis entrenos`).
- Bloques personalizados escritos por el usuario, por ejemplo:
  - `Pierna`
  - `Push`
  - `Pull`
  - `Torso`
  - `Full body`

Crear un bloque:

- No hay una pantalla separada de gestion de bloques.
- El bloque se crea automaticamente escribiendo el nombre en el campo `Bloque` al crear o editar un entrenamiento.
- Al guardar, ese entrenamiento aparece agrupado bajo ese bloque.

Esto mantiene la UI simple y evita gestion extra de categorias vacias.

### Crear entrenamiento

Flujo actual:

1. Entrar en `Plan`.
2. Pulsar `Crear entrenamiento`.
3. Escribir `Nombre`.
4. Escribir `Bloque`.
5. Anadir ejercicios.
6. Ajustar series, reps y peso.
7. Guardar.

Cada ejercicio creado incluye:

- nombre
- series
- reps
- peso

El campo `dia` se elimino de la UI. Internamente se usa el nombre del entrenamiento como `day`.

### Editar entrenamiento

Al editar:

- Se carga el nombre.
- Se carga el bloque.
- Se cargan ejercicios existentes.
- Se pueden cambiar series, reps y peso.
- Al guardar se sustituye la version previa.

Si se edita un entrenamiento por defecto:

- Se guarda como entrenamiento propio.
- Se oculta el original mediante `hiddenWorkoutIds`.

### Previsualizacion

Cambio importante restaurado:

- Al tocar un entrenamiento no se carga directamente.
- Primero aparece una vista previa.
- Desde la vista previa se puede:
  - Cargar entreno.
  - Compartir.
  - Editar.
  - Eliminar.

En movil, la vista previa es flotante por encima del menu inferior y tiene scroll interno para la lista de ejercicios.

### Eliminacion / papelera

Antes la eliminacion dependia del drag largo a una papelera.

Estado actual:

- Se mantiene el drag a papelera.
- Se anadio un boton `Eliminar` dentro de la vista previa.

Motivo:

- En movil, el drag largo puede fallar o sentirse poco fiable.
- El boton directo hace que la eliminacion sea clara y usable.

Comportamiento:

- Si el entrenamiento es creado por el usuario, se elimina de `savedWorkouts`.
- Si el entrenamiento es por defecto, se oculta con `hiddenWorkoutIds`.
- Se evita duplicar IDs ocultos.

## 10. Comparticion de entrenamientos

La app puede compartir entrenamientos mediante enlace.

Implementacion:

- Se genera un payload JSON.
- Se codifica en base64url.
- Se coloca en el hash de la URL:

```txt
#workout=...
```

Funciones relevantes:

- `createSharedWorkoutPayload`
- `createWorkoutShareUrl`
- `getSharedWorkoutFromHash`
- `createWorkoutFromShare`

El payload compartido ahora incluye tambien:

```ts
block?: string
```

Si llega un entrenamiento compartido sin bloque, se guarda en:

```txt
Compartidos
```

## 11. iOS / Xcode

El proyecto iOS ya existe y compila.

Estructura:

```txt
ios/GymSwipeIOS.xcodeproj
ios/GymSwipeIOS/GymSwipeIOSApp.swift
ios/GymSwipeIOS/ContentView.swift
ios/GymSwipeIOS/Info.plist
ios/WebDist
ios/project.yml
```

Funcionamiento:

- SwiftUI arranca una vista nativa.
- `ContentView.swift` muestra un `WKWebView`.
- El `WKWebView` carga `ios/WebDist/index.html`.
- `ios/WebDist` sale de `npm run ios:sync`.

Problema corregido:

- Vite genera scripts con `type="module"` y `crossorigin`.
- En `WKWebView` cargando desde `file://`, esto puede dejar la pantalla en blanco.
- `scripts/prepare-ios-webdist.mjs` convierte el script principal a `defer` y elimina atributos problematicos.

Geolocalizacion (puente nativo):

- `WKWebView` no implementa la API JS `navigator.geolocation` cargando desde `file://`.
- `ContentView.swift` incluye `GeolocationBridge` (`CLLocationManagerDelegate` + `WKScriptMessageHandler`).
- Inyecta un shim JS (`WKUserScript` at document start) que sobreescribe `getCurrentPosition`/`watchPosition` y reenvia la peticion al lado nativo via `window.webkit.messageHandlers.geo`.
- El nativo pide permiso (`requestWhenInUseAuthorization`), obtiene la posicion con `CoreLocation` y resuelve el callback JS (`window.__geoResolve` / `window.__geoReject`).
- Requiere `NSLocationWhenInUseUsageDescription` en `Info.plist` y en `project.yml` (para que xcodegen no lo pierda al regenerar).

Flujo correcto despues de cambiar React/CSS:

```bash
npm run lint
npm run build
npm run ios:sync
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/GymSwipeIOS.xcodeproj -scheme GymSwipeIOS -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Para usar en iPhone real:

1. Abrir `ios/GymSwipeIOS.xcodeproj` en Xcode.
2. Conectar el iPhone al Mac por cable o configurarlo para ejecucion inalambrica desde Xcode.
3. Elegir el iPhone como destino.
4. Revisar `Signing & Capabilities`.
5. Pulsar Run.

Nota:

- La primera configuracion normalmente requiere cable.
- Despues se puede usar wireless debugging si Xcode y el iPhone quedan emparejados.

## 12. Perfil y progreso

La pestana `Perfil` agrupa informacion personal y progreso.

Funciona:

- Foto de perfil.
- Ajuste basico/crop dentro del circulo.
- Nivel.
- Sexo.
- Edad.
- Pais.
- Ciudad.
- Gimnasio.
- XP.
- Barra de progreso de nivel.
- Calendario visual de entrenamientos.
- Resumen de entrenamiento seleccionado.

Calendario:

- Dias entrenados en verde.
- Dias futuros o fuera de mes en gris.
- Los dias verdes se pueden vincular a sesiones.
- Hay datos demo para que el calendario parezca vivo en entornos sin historial real.

Resumen:

- Series hechas en verde.
- Series saltadas/no hechas en rojo.
- Si se finaliza a mitad, las series pendientes se guardan como saltadas.
- Descansos se muestran en minutos y segundos.

Pendiente:

- Crop real mas preciso si se necesita.
- Backend/autenticacion.
- Separar datos demo de datos reales.

## 13. Ranking

La pestana `Ranking` existe y funciona como MVP local/mock.

Objetivo:

- Ranking global y segmentable por geografia.
- Base futura para comunidades, retos y matching.

Gym Score (0-100, exigente):

- Se calcula a partir del historial local, ventana movil de 3 semanas (21 dias).
- Pilares y pesos: Fuerza 30%, Constancia 22%, Progreso 17%, Volumen 13%, Calidad 10%, Variedad 8%.
- Disenado para ser MUY exigente (cada barra cuesta):
  - Fuerza: benchmarks e1RM de nivel ELITE por patron (`getExercisePattern`: pierna 185, bisagra 220, empuje 140, tiron 120), requiere 4+ patrones (`coverage`) y curva gamma 1.3.
  - Constancia: 6 sesiones/semana (18 en 3 semanas) = 100; 4/semana ~ 49; 3/semana ~ 28 (curva 1.35).
  - Progreso: plano ~45; necesitas ganancias grandes y sostenidas (~+40% volumen bloque-a-bloque) para acercarte al top; las regresiones penalizan muy fuerte.
  - Volumen: tonelaje log-escalado vs benchmark alto + curva 1.25.
  - Variedad: los 5 patrones para nota alta (curva 1.7; 4/5 ~ 69, 3/5 ~ 43).
  - Calidad: completitud con exponente 2.4 (los skips hunden la barra).
  - Curva final gamma=1.35 sobre el total: 85+ es casi inalcanzable.
- Niveles (tier): Iniciado (0), Constante (20), Competente (40), Avanzado (55), Élite (70), Legendario (85+).

Fiabilidad (minimo 3 semanas):

- `reliability = spanFactor * evidenceFactor`.
  - `spanFactor = min(1, diasUsandoLaApp / 21)` → imposible ser fiable antes de 21 dias.
  - `evidenceFactor = min(1, min(diasEntrenados/9, sesiones/9))` → exige ~3 sesiones/semana.
- El numero mostrado = `scoreExigente * (0.5 + 0.5 * reliability)`: durante las primeras 3 semanas es PROVISIONAL (hasta -50%).
- La UI muestra "Provisional · faltan N dias" + barra de fiabilidad y el potencial; cuando es fiable muestra "Fiable · R%".
- `reliable` cuando hay >= 21 dias de uso y >= 8 dias entrenados.

Mapa:

- Usa tiles de OpenStreetMap.
- Se puede mover/arrastrar.
- Se puede ampliar/reducir (zoom) con:
  - botones `+` / `-` sobre el mapa,
  - pellizco (pinch) con dos dedos, con snap a niveles enteros de zoom,
  - doble clic en escritorio.
- El zoom se reinicia al nivel del filtro (`global/pais/ciudad/zona`) al cambiar de filtro.
- Muestra usuarios aproximados, no ubicacion exacta.
- Agrupa puntos cercanos en clusters.

Ubicacion real:

- El boton `Ubicarme` y la carga inicial usan `navigator.geolocation`.
- En iOS (`WKWebView`) la API JS de geolocalizacion no funciona sola: hay un puente nativo en `ContentView.swift` (ver seccion 11) que la conecta con `CoreLocation`.
- Si se deniega el permiso o falla, cae al fallback aproximado (Madrid).

Filtros:

- global
- pais
- ciudad
- zona cercana

Pendiente:

- Backend real.
- Usuarios reales.
- Persistencia de ubicacion aproximada.
- Privacidad configurable.
- Calculo de ranking en servidor.

## 14. Partner / Buscar companero

La pestana `Partner` permite crear o aceptar planes de entreno.

Concepto:

- No es un muro libre.
- Son tarjetas de planes.

Ejemplo:

```txt
Pecho + triceps
Manana
Basic-Fit Gran Via
Nivel: intermedio
Busco 1-2 personas
Intensidad: fuerte
Objetivo: hipertrofia
```

Flujo:

- Boton `Buscar companero`.
- Formulario rapido:
  - cuando
  - donde
  - que vas a entrenar
  - nivel buscado
  - plazas

Ajustes aplicados:

- No mostrar hora si no se configuro.
- `Donde` es multiseleccion.
- `Mi gimnasio` usa el gimnasio configurado en Perfil.
- Plazas incluye opcion flexible.
- No se generan descripciones que el usuario no escribio.
- Cada plan tiene un `ownerId` (la persona que lo propone).
- Los planes que creas tienen `ownerId: 'me'`: salen con TU nombre (de la cuenta @), marcados como "Tu plan · Esperando compañero…", con boton Eliminar y SIN boton de aceptar (no puedes aceptar/chatear contigo mismo). Solo los planes de otros (demo) son aceptables.
- Ya no se muestra el "Nivel"; cada plan muestra una puntuacion (`score`, el Gym Score del proponente; en tus planes es tu propio Gym Score).
- Se eliminaron los campos auto-inventados (intensidad y objetivo): la tarjeta solo muestra lo que el usuario define (titulo/que, cuando, lugar, plazas) + score.
- Cualquier plan que no te interese se puede descartar (boton Descartar en planes de otros, Eliminar en los tuyos); la lista se persiste, asi que no se perpetuan.
- Mientras se crea un plan (formulario "Buscar compañero" abierto) se oculta la lista de planes.

Aceptar entrenamiento (flujo actual):

- Ya NO aparece snackbar/toast ni chat inline.
- Al pulsar `Aceptar entrenamiento`:
  - se abre/crea la conversacion con esa persona (una conversacion por persona, id `conv-<personId>`),
  - se inserta el mensaje inicial "He aceptado tu entrenamiento. ¿Cuándo te viene bien quedar?",
  - se genera una notificacion de tipo `training_accepted`,
  - se navega directo al chat.
- La conversacion queda guardada en Mensajes (ver seccion 22).

Pendiente:

- Persistencia real de chats en backend.
- Solicitudes reales contra servidor.
- Usuarios reales.
- Seguidores/seguidos.
- Backend.

## 15. PWA, cache y movil

Hubo problemas con iPhone cargando versiones antiguas.

Decision actual:

- Service worker desactivado/limpiador durante iteracion.
- Se limpian caches para evitar versiones viejas.

Archivos relevantes:

```txt
src/main.tsx
public/sw.js
```

Motivo:

- iOS/Safari cachea agresivamente PWAs y service workers.
- Durante desarrollo rapido es mejor evitar offline cacheado.

Futuro:

- Reintroducir PWA offline solo cuando haya versionado estable.
- Implementar estrategia clara de cache busting.

## 16. Diseno y UX

Principios:

- Mobile-first.
- App funcional desde la primera pantalla.
- Sin landing.
- Controles grandes y tactiles.
- Pocos textos explicativos.
- Feedback inmediato.
- Animaciones cortas.
- Sensacion tipo Duolingo en recompensas, sonidos, mascota y progreso.
- Visual profesional, no sobrecargado.

Paleta:

- Base clara.
- Verde para accion positiva.
- Rojo para saltar/eliminar.
- Contraste oscuro para texto principal.

Restricciones aprendidas:

- Safe area de iPhone siempre importa.
- Bottom nav puede tapar controles.
- `position: sticky` es fragil en layouts con scroll.
- `transform` en ancestros puede afectar elementos `fixed`.
- Drag en movil debe convivir con scroll vertical.

## 17. Despliegue web

URL de produccion conocida:

```txt
https://gym-swipe-ios.vercel.app
```

Comando de despliegue usado anteriormente:

```bash
npx --yes vercel deploy --prod --yes
```

Antes de desplegar:

```bash
npm run lint
npm run build
```

Para evitar cache al probar:

```txt
https://gym-swipe-ios.vercel.app/?v=alguna-version
```

Nota:

- El trabajo actual se ha centrado en Xcode/iOS y GitHub.
- No desplegar a Vercel salvo que se pida explicitamente o toque actualizar produccion web.

## 18. Validaciones recientes

Validado el 2026-06-28:

```bash
npm run lint
npm run build
npm run ios:sync
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/GymSwipeIOS.xcodeproj -scheme GymSwipeIOS -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Resultado:

- Lint correcto.
- Build web correcto.
- Bundle iOS sincronizado.
- Build Xcode correcto.

## 19. Bugs y riesgos conocidos

1. `src/App.tsx` es demasiado grande.
   - Riesgo: mantenimiento dificil.
   - Recomendacion: modularizar por dominio.

2. No hay backend.
   - Todo vive en `localStorage`.
   - Ranking/social/partner no pueden ser reales sin servidor.

3. PWA offline desactivada.
   - Bueno para iterar.
   - Malo para offline real.

4. Datos demo mezclados con experiencia real.
   - Calendario y ranking usan mocks.
   - Separar seed/demo/real cuando haya backend.

5. No hay tests automatizados.
   - Solo lint/build.
   - Recomendable anadir tests para scoring, historial, normalizacion y workouts.

6. Layout movil requiere validacion constante.
   - Especialmente iPhone real con safe area.
   - Revisar action dock, preview flotante y bottom nav tras cambios.

7. Xcode signing en iPhone real puede requerir ajuste manual.
   - Bundle id actual: `com.javiercolroma.gymswipeios`.
   - Revisar equipo de firma en Xcode si falla al instalar en dispositivo.

## 20. Proximos pasos recomendados

### Corto plazo

1. Probar en iPhone real:
   - iniciar entreno
   - completar ultimo ejercicio
   - verificar finalizacion automatica
   - abrir Plan
   - previsualizar entreno
   - crear entreno con bloque `Pierna`
   - eliminar entreno desde vista previa

2. Ajustar si hace falta:
   - posicion check/X
   - altura de preview
   - scroll de biblioteca

3. Confirmar firma Xcode en iPhone real.

4. Mantener commit y push por cada cambio cerrado.

### Medio plazo

1. Modularizar `src/App.tsx`.
2. Separar dominio:

```txt
src/domain/workouts.ts
src/domain/history.ts
src/domain/scoring.ts
src/domain/sharing.ts
src/storage/localState.ts
```

3. Separar componentes:

```txt
src/components/train/
src/components/plan/
src/components/profile/
src/components/ranking/
src/components/partner/
```

4. Anadir tests unitarios.
5. Preparar backend minimo:
   - usuarios
   - perfiles
   - entrenamientos
   - sesiones
   - ranking
   - planes partner
   - chats

### Largo plazo

1. Auth.
2. Backend para sesiones reales.
3. Ranking real.
4. Matching de partners.
5. Chat persistente.
6. PWA offline versionada.
7. Publicacion TestFlight/App Store.

## 21. Social: mensajes, chat, amigos y notificaciones

Capa social local (sin backend), persistida en `localStorage` con clave `gym-swipe-social-v1`.
Logica en `src/App.tsx` (hook `useSocial`).

Accesos superiores:

- En la cabecera, arriba a la derecha: icono sobre (Mensajes) y campana (Notificaciones).
- Cada uno muestra un badge rojo con el numero de pendientes.

Mensajes (overlay):

- Segmento `Chats` / `Amigos`.
- Chats: lista de conversaciones (avatar, nombre, ultimo mensaje, hora, no leidos) ordenadas por reciente.
- Estado vacio "Sin conversaciones".

Chat individual:

- Cabecera con avatar/nombre + volver.
- Burbujas enviadas/recibidas con hora, auto-scroll.
- Campo de texto + boton enviar; el mensaje propio aparece al instante.
- El otro usuario responde automaticamente (~2.6 s) — SIMULADO (no hay backend).
- Marca la conversacion como leida al entrar.

Cuenta de usuario:

- En el primer arranque (sin cuenta) aparece `AccountSetup` (modal bloqueante).
- Pide nombre + `@usuario` unico (normalizado: minusculas, `a-z0-9_`, 3-20 chars).
- La unicidad se valida contra los handles de las personas demo.
- Se persiste en `social.account`. Editable desde la pestana Amigos (chip "Editar").

Perfil de un amigo:

- Al pulsar sobre una persona (en Amigos, resultados de busqueda o cabecera del chat) se abre su perfil.
- Muestra Nivel, Gym Score (con tier), racha, desglose de pilares y entrenos recientes.
- Datos demo deterministas por persona (`buildFriendHistory` con RNG sembrado desde el id); reusa `calculateGymScore`/`getLevelProgress`/`getDayStreak`.

Amigos:

- Buscador por nombre o `@usuario` arriba (filtra todas las personas).
- Solicitudes recibidas (aceptar/rechazar).
- Tus amigos (con boton Mensaje).
- Descubre companeros (enviar solicitud).
- Cada persona tiene `handle` (`@...`); las filas muestran nombre + @handle.
- Estados de relacion: `none`, `outgoing` (solicitud enviada), `incoming`, `friends`.
- Al enviar solicitud se simula su aceptacion a los ~4.2 s.

Notificaciones (overlay):

- Tipos: `friend_request`, `friend_accepted`, `training_accepted`.
- Los mensajes nuevos NO generan notificacion (campana): solo aparecen en Mensajes con el badge de no leidos del sobre.
- Cada una: titulo, descripcion corta, tiempo relativo, leida/no leida.
- Tocar abre el chat o la pestana Amigos segun el tipo. Boton "Marcar leido".

Pendiente:

- Backend real (las respuestas y aceptaciones estan simuladas con temporizadores).
- Usuarios reales (ahora la busqueda es sobre personas demo locales).
- Unicidad de @usuario validada en servidor.

## 22. Correcciones recientes (sesion actual)

- Tab-bar que desaparecia en sesion/ranking: el commit "Fix mobile app scrolling" migro el scroll a `.screen-body` pero solo actualizo `.view-train`. Las vistas `ranking/partner/profile/settings/plan/progress` seguian con scroller propio (`max-height: 610px; overflow: auto`), creando scrollers anidados. Se unifico a un unico scroller (`.screen-body`) y el tab-bar se hizo mas opaco, con z-index seguro y `position: fixed` en movil.
- Arrastrar entreno a la papelera no funcionaba en tactil: los botones tenian `touch-action: pan-y` y al arrastrar hacia abajo iOS lo trataba como scroll (cambiar `touch-action` a mitad de gesto no surte efecto). Se anadio un listener `touchmove` no pasivo con `preventDefault` mientras el arrastre esta activo + se desactivo callout/seleccion iOS en los botones removable.
- Zoom de mapa en Ranking (ver seccion 13).
- Geolocalizacion real en iOS via puente nativo (ver seccion 11).
- Segmento Chats/Amigos que ocupaba toda la pantalla: el overlay usaba grid de 2 filas con 3 hijos; se paso a flexbox.
- Cabeceras de overlays (Mensajes/Chat/Notificaciones) colisionaban con la barra de estado del iPhone (reloj) y la flecha de volver no era pulsable: se anadio `env(safe-area-inset-top)` al padding superior. Ademas, al abrir un chat desde la lista, el overlay de Mensajes queda debajo para que "atras" vuelva a la lista de conversaciones.
- Tab-bar que seguia desapareciendo (incl. al iniciar/seleccionar entreno): `position: fixed` es fragil en WKWebView (se desvanece durante animaciones de cambio de vista). Solucion final y a prueba de balas: el tab-bar es SIEMPRE una fila EN FLUJO del grid de 3 filas del `phone-stage` (`auto minmax(0,1fr) auto`), sin `position: fixed` ni `backdrop-filter`. Como `phone-stage` ocupa 100svh, la fila queda fija al fondo de la pantalla y nunca puede recortarse/desaparecer. El `<nav class="tab-bar">` va en el JSX despues de `.screen-body`.
- Formulario "Buscar compañero" (Partner): ahora se puede cerrar siempre (el boton de cabecera alterna a "Cerrar" y hay un boton "Cancelar"), sin necesidad de crear un plan.

## 23. Publicacion en App Store

Ajustes ya hechos en el repo para poder subir la app:

- `ITSAppUsesNonExemptEncryption: false` (evita la pregunta de cifrado en cada subida) y `LSApplicationCategoryType: public.app-category.healthcare-fitness` en `ios/project.yml` (se generan al Info.plist con xcodegen).
- Manifiesto de privacidad `ios/GymSwipeIOS/PrivacyInfo.xcprivacy` (sin tracking, sin recopilacion de datos, sin APIs de motivo requerido). Se incluye en el bundle al generar/compilar.
- Permiso de ubicacion `NSLocationWhenInUseUsageDescription` (ya estaba).
- Paginas para GitHub Pages en `docs/` (`index.html`, `privacy.html`, `support.html`) → URLs de privacidad/soporte que pide App Store. Activar en GitHub: Settings → Pages → Source `Deploy from a branch` → `main`/`docs`.
- `STORE.md` (raiz): nombre, subtitulo, descripcion, keywords, categoria, clasificacion por edad, respuestas de App Privacy y NOTAS PARA EL REVISOR (importante: explicar que es local-first con web empaquetada y que lo social es simulado, para mitigar la guia 4.2).

Pasos de subida (resumen, detalle en `STORE.md`):

1. `npm run ios:sync` (sincroniza WebDist) y, si cambio `project.yml`, `npm run ios:generate`.
2. Xcode → Signing & Capabilities → Team (cuenta del Apple Developer Program, 99 €/año).
3. Destino: `Any iOS Device (arm64)` → Product → Archive.
4. Organizer → Distribute App → App Store Connect → Upload.
5. App Store Connect: crear app, rellenar con `STORE.md`, subir capturas (>= iPhone 6.9"), seleccionar build y enviar a revision.

Pendiente (manual, requiere navegar la app): capturas de pantalla finales para la ficha.

## 24. Instruccion para futuras sesiones

Al retomar:

```bash
cd /Users/javiercolas/Documents/gym-swipe-ios
git status --short --branch
npm run lint
npm run build
```

Si se va a tocar iOS:

```bash
npm run ios:sync
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/GymSwipeIOS.xcodeproj -scheme GymSwipeIOS -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Leer:

```txt
README.md
ios/README.md
```

Zonas clave de codigo:

```txt
src/App.tsx
src/App.css
scripts/prepare-ios-webdist.mjs
ios/GymSwipeIOS/ContentView.swift
ios/project.yml
```

Reglas de mantenimiento:

- Actualizar esta memoria tras features relevantes.
- Actualizar esta memoria tras bugs importantes.
- Ejecutar lint/build antes de cerrar.
- Si cambia la app web usada por iOS, ejecutar `npm run ios:sync`.
- Si cambia estructura iOS declarativa, ejecutar `npm run ios:generate`.
- Hacer commit y push al terminar.
