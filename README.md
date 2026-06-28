# Memoria del proyecto: Gym Swipe iOS

Ultima actualizacion: 2026-06-28

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
- Si un entrenamiento creado no tiene bloque, se muestra en `Mis entrenos`.

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
- `Mis entrenos`: fallback para entrenamientos creados por el usuario.
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

Gym Score:

- Calcula puntuacion a partir del historial local.
- Usa las ultimas 3 semanas.
- Tiene en cuenta:
  - fuerza
  - constancia
  - volumen
  - progresion
  - variedad
  - calidad/completitud
  - fiabilidad de datos

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

Amigos:

- Buscador por nombre o `@usuario` arriba (filtra todas las personas).
- Solicitudes recibidas (aceptar/rechazar).
- Tus amigos (con boton Mensaje).
- Descubre companeros (enviar solicitud).
- Cada persona tiene `handle` (`@...`); las filas muestran nombre + @handle.
- Estados de relacion: `none`, `outgoing` (solicitud enviada), `incoming`, `friends`.
- Al enviar solicitud se simula su aceptacion a los ~4.2 s.

Notificaciones (overlay):

- Tipos: `friend_request`, `friend_accepted`, `message`, `training_accepted`.
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

## 23. Instruccion para futuras sesiones

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
