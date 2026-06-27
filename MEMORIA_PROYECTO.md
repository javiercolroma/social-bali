# Memoria del proyecto: Gym Swipe iOS

Ultima actualizacion: 2026-06-27

Este documento es la memoria viva del proyecto. Su objetivo es permitir retomar el desarrollo aunque se pierda la sesion de trabajo: contexto de producto, decisiones tecnicas, arquitectura actual, estado funcional, problemas conocidos y proximos pasos.

## 1. Resumen ejecutivo

Gym Swipe iOS es una app web movil construida con React, Vite y TypeScript. La experiencia esta pensada principalmente para iPhone, en formato app ligera instalable/probable PWA, aunque temporalmente se esta usando desde navegador y desplegada en Vercel.

La idea inicial era una app simple para entrenar con tarjetas tipo swipe: cada ejercicio se presenta como una tarjeta y el usuario marca cada serie como hecha o saltada. El producto ha evolucionado hacia una app social/gamificada de entrenamiento, con:

- Entrenamientos creados desde la app.
- Entrenamientos predefinidos por nivel.
- Sesion de entrenamiento activa con cronometro, descanso, sonidos, mascota y animaciones.
- Registro historico por series.
- Perfil con datos basicos, foto y progresion.
- Sistema de XP/nivel.
- Calendario visual de entrenamientos.
- Ranking global con mapa.
- Partner/social para buscar companero de entreno.
- Comparticion de entrenamientos mediante enlaces.

El criterio de producto que ha guiado los cambios es: maxima sencillez visual, experiencia movil fluida y sensacion dinamica/adictiva tipo Duolingo, evitando textos explicativos largos dentro de la app.

## 2. Ubicacion y entorno

Ruta local del proyecto:

```txt
/home/jcolas/Documentos/gym-swipe-ios
```

Stack:

- React 19.
- Vite 8.
- TypeScript 6.
- CSS manual en `src/App.css`.
- Iconos con `lucide-react`.
- Persistencia local con `localStorage`.
- Despliegue en Vercel.

Scripts principales:

```bash
npm run dev
npm run lint
npm run build
npm run preview
```

URL de produccion actual:

```txt
https://gym-swipe-ios.vercel.app
```

Estado Git actual:

- El directorio aun no esta inicializado como repositorio Git.
- Hay `.gitignore`, pero no hay carpeta `.git`.
- Es correcto si se quiere crear un repositorio separado del Git de trabajo.

## 3. Archivos importantes

```txt
src/App.tsx
src/App.css
src/index.css
src/main.tsx
src/exerciseCatalog.ts
public/sw.js
public/manifest.webmanifest
package.json
vite.config.ts
```

Descripcion:

- `src/App.tsx`: contiene practicamente toda la logica de producto y vistas principales.
- `src/App.css`: contiene casi todo el diseno visual, responsive, animaciones y layout movil.
- `src/index.css`: estilos globales base.
- `src/main.tsx`: monta React y actualmente fuerza limpieza de service workers/caches.
- `src/exerciseCatalog.ts`: catalogo de ejercicios traducido/normalizado para autocompletado.
- `public/sw.js`: service worker actualmente desactivado/limpiador para evitar versiones antiguas en iPhone.
- `public/manifest.webmanifest`: configuracion PWA.

## 4. Evolucion funcional

### 4.1 Version inicial

La app empezo como una pantalla de entrenamiento con tarjetas:

- Ejercicio activo.
- Swipe a la derecha para marcar hecho.
- Swipe a la izquierda para saltar.
- Edicion basica de peso/reps/series.
- Historial local.
- Plantillas.
- Export/import JSON.
- PRs automaticos.
- PWA con manifest y service worker.

### 4.2 Entrenamiento por series

Se corrigio el modelo mental principal: un ejercicio no se completa entero de golpe. Cada ejercicio tiene varias series.

Ahora:

- Cada accion de check marca una serie como hecha.
- Cada accion de X marca una serie como saltada.
- El ejercicio solo se cierra cuando se han completado o saltado todas sus series.
- Se guarda un `HistoryEntry` por serie, no solo por ejercicio.
- El entrenamiento guarda metadatos por serie:
  - `setIndex`
  - `totalSetsInExercise`
  - `setDurationSeconds`
  - `restBeforeSeconds`
  - `exerciseRestSeconds`
  - `sessionElapsedSeconds`
  - `sessionId`
  - `workoutName`

Esto permite construir historico, calendario, resumen de entrenos y ranking futuro con mas precision.

### 4.3 Sesion activa de entrenamiento

Se separo la pantalla de Entreno del resto de la app para que sea la vista mas importante.

Comportamiento:

- Si no hay entrenamiento seleccionado, aparece "Seleccionar entreno" y envia a Plan.
- Si hay entrenamiento seleccionado pero no iniciado, aparece un overlay elegante con boton grande "Iniciar entreno".
- Al iniciar, se ve claramente que la sesion esta activa.
- Hay cronometro de entrenamiento.
- Hay boton "Finalizar".
- Al finalizar, se marcan como no hechas todas las series restantes.
- Al terminar se muestra estado final y boton para elegir otro entrenamiento.

Se eliminaron de Entreno elementos que distraian:

- Nivel.
- Racha.
- Porcentaje redundante.
- Textos descriptivos innecesarios.

### 4.4 Barra de acciones de entrenamiento

La barra de acciones tiene:

- Deshacer.
- X roja para saltar serie.
- Check verde para marcar serie hecha.

Problemas corregidos:

- Swipe a la izquierda no salia completamente.
- Texto "Luego" eliminado.
- Barra de acciones mal colocada en movil.
- La barra ahora se ha convertido en control flotante fijo sobre el menu inferior, respetando safe area de iPhone.

Ultimo ajuste aplicado:

- `action-dock` paso de `position: sticky` a `position: fixed`.
- `view-train` reserva espacio inferior adicional.
- Botones tienen ancho/altura estable.

### 4.5 Sonidos y animaciones

Se anadio feedback tipo Duolingo:

- Sonidos Web Audio API sin archivos externos.
- Sonido de serie completada.
- Sonido distinto cuando se completa el ejercicio y se pasa a otra tarjeta.
- Sonido de saltar serie.
- Sonido de inicio/final.
- Animaciones de popups y recompensas.
- Mascota tipo gym que acompana y reacciona.

Problema importante ya tratado:

- El sonido de cambio de ejercicio solo se respetaba en el primer cambio. Se reviso la logica para diferenciar `set` y `exercise`.

### 4.6 Mascota

Se creo una mascota gym animada, inspirada en el rol de acompanamiento de Duolingo pero sin copiar el personaje.

Estados/moods:

- `ready`
- `active`
- `rest`
- `finished`
- `cheer`
- `miss`
- `pr`

La mascota reacciona cuando:

- Se inicia un entrenamiento.
- Se completa una serie.
- Se salta una serie.
- Se completa un ejercicio.
- Se finaliza la sesion.

### 4.7 Plan / Entrenamientos

La pestaña Plan evoluciono bastante.

Decisiones:

- Se elimino "Plan actual".
- Se elimino importacion de plan externo.
- La app consume entrenamientos creados dentro de la app o predefinidos.
- "Plantillas" paso a llamarse "Entrenamientos".
- Los entrenamientos propios aparecen primero.
- Predefinidos agrupados por nivel:
  - Iniciacion.
  - Intermedio.
  - Avanzado.
  - Propios.

Creacion de entrenamiento:

- La creacion esta escondida de inicio.
- Boton "Crear entrenamiento" abre una pantalla/seccion separada.
- Se introduce nombre del entrenamiento.
- Luego se anaden ejercicios.
- Se elimino el campo dia.
- Cada ejercicio tiene:
  - nombre
  - series
  - reps
  - peso

Guardar:

- El boton "Usar entrenamiento" paso a ser "Guardar entrenamiento".
- Al guardar, el entrenamiento aparece en "Entrenamientos".

Edicion:

- Se puede editar un entrenamiento existente.
- Se pueden anadir ejercicios.
- Se pueden eliminar ejercicios.
- Se pueden editar series, reps y peso.

Previsualizacion:

- Al tocar un entrenamiento no entra directamente en Entreno.
- Primero aparece una previsualizacion de ejercicios y series.
- Desde ahi se puede usar, editar o compartir.

Eliminacion:

- Eliminar entrenamiento se hace arrastrando la tarjeta a una papelera.
- La papelera es una franja rectangular de extremo a extremo.
- Siempre aparece en rojo apagado.
- Se intensifica al arrastrar.
- Se trabajo para que la tarjeta arrastrada quede visualmente bajo el dedo en movil.
- Se redujo el long press para que sea mas comodo.
- Se desactivo seleccion de texto durante el drag.

### 4.8 Catalogo de ejercicios

Se anadio autocompletado al escribir el nombre del ejercicio.

Fuente conceptual:

```txt
https://github.com/yuhonas/free-exercise-db/blob/main/dist/exercises.json
```

Decisiones:

- Los nombres se tradujeron al espanol.
- Se deduplicaron nombres.
- Se detecto el caso "press banca" repetido y se corrigio.
- No es obligatorio seleccionar del desplegable.
- Si el usuario quiere escribir un ejercicio libre, la interaccion debe ser amable.
- La fuente de inputs debe ser coherente con Peso/Reps y sin negrita excesiva.

Archivo:

```txt
src/exerciseCatalog.ts
```

### 4.9 Perfil y Logros

Se unieron Logros y Perfil en una sola pestaña llamada Perfil.

Contenido actual:

- Foto de perfil.
- Selector basico/crop de foto para ajustar la parte visible dentro del circulo.
- Nivel debajo de la foto.
- Sexo.
- Edad.
- Pais.
- Ciudad.
- Gimnasio.
- Sistema de nivel y XP.
- Barra de progreso de nivel.
- Calendario de entrenamientos.
- Resumen de entrenamiento seleccionado.

Se elimino:

- Exportar/importar.
- Preferencias.
- Mantenimiento.
- Records temporalmente.
- Copas, estrellas y checks decorativos.
- Series seguidas.
- Recuadros innecesarios de descanso/serie en resumen.

Sistema XP/nivel:

- Existe una base de XP por serie.
- Hay reglas para completar series, cerrar ejercicio, PRs y consistencia.
- Los niveles cada vez requieren mas XP.
- La barra de progreso debe sentirse suave y dinamica, sin parpadeos bruscos.

Calendario:

- Visual por semanas/dias.
- Dias entrenados en verde.
- Animacion tipo latido/llama.
- Dias futuros o fuera de mes en gris.
- Los dias verdes deben tener entrenamientos linkados.
- Se generaron entrenos demo previos para que el calendario parezca vivo.

Resumen de entreno:

- Series hechas en verde.
- Series saltadas/no hechas en rojo.
- Si se finaliza a mitad, las series restantes se guardan como no hechas.
- Se quito kilos movidos.
- Tiempo de entreno no debe duplicarse.
- Descansos se muestran en minutos y segundos, no solo segundos.

### 4.10 Ranking

Se creo una pestaña nueva Ranking.

Objetivo estrategico:

- Ranking global y segmentable por geografia.
- Base para descubrir usuarios compatibles.
- Base futura para comunidades, retos y matching.

Puntuacion Gym Score:

Debe reflejar las ultimas 3 semanas de entrenamiento, con criterios:

- fuerza
- constancia
- volumen
- intensidad relativa
- progresion reciente
- variedad
- calidad/completitud

Implementacion actual:

- Calcula score a partir del historial local.
- Usa ultimos 21 dias.
- Distingue grupos de ejercicios.
- Aplica benchmarks aproximados.
- Penaliza falta de datos mediante `reliability`.
- Ranking mock con usuarios simulados.

Mapa:

- Se implemento mapa real con tiles de OpenStreetMap.
- El mapa se puede mover/arrastrar para explorar zonas.
- Se muestran usuarios aproximados, no ubicacion exacta.
- Se agrupan puntos: si hay varios usuarios cercanos aparece un cluster con numero.
- Filtros de ranking:
  - global
  - pais
  - ciudad
  - zona cercana

Privacidad:

- No se muestra localizacion exacta.
- El enfoque futuro debe ser zona aproximada.

Ranking visual:

- Foto de perfil a la izquierda.
- Bandera del pais en parte inferior derecha.

### 4.11 Partner / Buscar companero

Se creo pestaña independiente Partner.

La feature no es un muro libre, sino tarjetas de planes de entreno.

Una tarjeta representa algo como:

```txt
Pecho + triceps
Manana · 19:30
Basic-Fit Gran Via
Nivel: intermedio
Busco 1-2 personas
Intensidad: fuerte
Objetivo: hipertrofia
```

Flujo de creacion:

- Boton "Buscar companero".
- Formulario rapido:
  - cuando
  - donde
  - que vas a entrenar
  - nivel buscado
  - plazas

Ajustes ya pedidos/aplicados:

- No mostrar hora si el usuario no ha configurado hora.
- "Donde" debe ser multiseleccion.
- Plazas incluye una opcion tipo "Me adapto".
- "Mi gimnasio" usa el gimnasio configurado en Perfil.
- Quitar descripciones generadas que el usuario no ha escrito.
- Se puede aceptar un plan/solicitud de otro usuario.
- Al aceptar, lleva a un chat basico.

Futuro:

- Sistema real de seguidores/seguidos.
- Chat persistente.
- Solicitudes.
- Usuarios verificados.

### 4.12 Social y comparticion

Se anadio comparticion de entrenamientos.

Objetivo:

- Que los entrenamientos creados circulen fuera y dentro de la app.
- Viralidad por WhatsApp, Instagram, enlaces externos, perfiles.

Implementacion actual:

- Se genera payload JSON del entrenamiento.
- Se codifica en base64url.
- Se mete en hash URL `#workout=...`.
- Al abrir un enlace, la app intenta importar ese entrenamiento.

Funciones relevantes:

- `createSharedWorkoutPayload`
- `createWorkoutShareUrl`
- `getSharedWorkoutFromHash`
- `createWorkoutFromShare`

## 5. Arquitectura de datos

Todo esta en localStorage. No hay backend todavia.

Storage actual:

```ts
const storageKey = 'gym-swipe-ios-state-v2'
const marketStorageKey = 'gym-swipe-ios-state-v3'
```

Estado principal:

```ts
type WorkoutState = {
  schemaVersion: number
  exercises: Exercise[]
  player: Player
  lastAction: LastAction | null
  history: HistoryEntry[]
  prs: Record<string, PR>
  preferences: Preferences
  profile: Profile
  savedWorkouts: WorkoutTemplate[]
  hiddenWorkoutIds: string[]
  undoStack: Snapshot[]
}
```

Entidades relevantes:

- `Exercise`
- `HistoryEntry`
- `WorkoutTemplate`
- `Player`
- `Profile`
- `TrainingPlan`
- `GymScore`

Advertencia:

El proyecto esta creciendo mucho dentro de `src/App.tsx`. Para una siguiente fase seria recomendable separar por modulos:

```txt
src/domain/workouts.ts
src/domain/scoring.ts
src/domain/history.ts
src/components/train/
src/components/plan/
src/components/profile/
src/components/ranking/
src/components/partner/
src/storage/localState.ts
```

## 6. Diseno y UX

Principios acordados:

- Mobile-first.
- Minimalista y profesional.
- Sencillez por encima de densidad.
- Evitar textos descriptivos dentro de la app.
- No usar landing page.
- La primera pantalla debe ser funcional.
- Entreno es la seccion principal y debe sentirse especial.
- Botones principales grandes, claros y tactiles.
- Animaciones cortas, con feedback, no decoracion excesiva.
- Inspiracion tipo Duolingo: feedback, recompensa, mascota, sonidos, progreso.

Paleta:

- Base clara: blanco roto / crema suave.
- Verde energetico para accion positiva.
- Rojo apagado para eliminar/saltar.
- Negro/verde oscuro para contraste.
- Se ha intentado evitar una UI caotica o con textos que se salen.

Problemas recurrentes en movil:

- iPhone/Safari cachea agresivamente PWA/service worker.
- El bottom nav puede tapar elementos.
- `position: sticky` dentro de contenedores con scroll puede comportarse mal.
- Drag en tarjetas puede interferir con scroll vertical.

Soluciones aplicadas:

- Barra inferior fija.
- Safe area con `env(safe-area-inset-bottom)`.
- Limpieza/desactivacion de service worker durante iteracion.
- Long press en Plan para iniciar drag, para no bloquear scroll.

## 7. PWA, cache y movil

Hubo problemas de que el movil parecia cargar versiones antiguas.

Decision temporal:

- Desactivar service worker y limpiar caches mientras se itera rapido.

`src/main.tsx`:

- Al cargar, desregistra service workers.
- Borra caches.

`public/sw.js`:

- Borra caches.
- Hace unregister.
- Fetch pasa a red.

Esto evita que iPhone mantenga una version anterior. Cuando la app este mas estable, se puede reintroducir PWA offline con versionado correcto.

## 8. Despliegue

Proyecto desplegado en Vercel.

Comando usado:

```bash
npx --yes vercel deploy --prod --yes
```

URL estable:

```txt
https://gym-swipe-ios.vercel.app
```

Para probar evitando cache:

```txt
https://gym-swipe-ios.vercel.app/?v=alguna-version
```

Antes de desplegar, se suele ejecutar:

```bash
npm run lint
npm run build
```

## 9. Estado actual por pantalla

### Entreno

Funciona:

- Seleccionar entreno.
- Iniciar sesion.
- Cronometro.
- Serie hecha/saltada.
- Swipe.
- Editar peso/reps durante sesion.
- Descanso.
- Finalizar entrenamiento.
- Guardado de series restantes como no hechas.
- Sonidos y mascota.

Ultimo bug tratado:

- Barra de check verde / X roja no se veia bien en movil.
- Se corrigio `action-dock`.

Pendiente de validar en iPhone:

- Que la barra flote correctamente.
- Que no tape contenido ni menu.
- Que el swipe izquierdo siga completo.

### Plan

Funciona:

- Entrenamientos propios primero.
- Grupos por nivel.
- Crear entrenamiento.
- Editar entrenamiento.
- Previsualizar entrenamiento.
- Guardar.
- Compartir.
- Arrastrar a papelera para eliminar.
- Autocompletado de ejercicios.

Pendiente:

- Pulir aun mas legibilidad si hay muchos entrenamientos.
- Separar mejor componentes.

### Ranking

Funciona:

- Score local.
- Ranking simulado.
- Mapa real OpenStreetMap.
- Clusters.
- Filtros.
- Mapa arrastrable.
- Foto + bandera.

Pendiente:

- Backend real.
- Usuarios reales.
- Geolocalizacion aproximada persistida.
- Segmentacion real por pais/ciudad/area.

### Partner

Funciona:

- Crear plan de entreno.
- Multiseleccion de donde.
- Mi gimnasio desde perfil.
- Opcion flexible de plazas.
- Aceptar plan.
- Chat basico.

Pendiente:

- Persistencia real de chats.
- Seguidores/seguidos.
- Solicitudes reales.
- Backend.

### Perfil

Funciona:

- Foto.
- Ajuste/crop basico.
- Nivel.
- Datos basicos.
- Calendario.
- Resumen.
- XP.

Pendiente:

- Mejor crop real de imagen si se quiere precision total.
- Backend/autenticacion.

## 10. Bugs o riesgos conocidos

1. App demasiado concentrada en `src/App.tsx`.
   - Riesgo: mantenimiento dificil.
   - Solucion: modularizar por dominios.

2. Sin backend.
   - Todo es localStorage.
   - Si se comparte enlace con amigos, cada uno tiene datos locales separados solo por navegador/dispositivo.
   - Para ranking/social real hace falta auth + base de datos.

3. PWA desactivada temporalmente.
   - Bueno para iterar.
   - Malo para offline real.
   - Reintroducir con versionado cuando estabilice.

4. Mapa usa tiles externos de OpenStreetMap.
   - Correcto para MVP.
   - Revisar terminos/limites si crece.

5. No hay tests automatizados.
   - Solo lint/build.
   - Recomendable anadir tests unitarios para scoring, historial y normalizacion.

6. Datos mock mezclados con datos reales.
   - El calendario y ranking usan datos simulados para dar vida.
   - Cuando haya backend, separar claramente seed/demo/real.

## 11. Proximos pasos recomendados

### Corto plazo

1. Validar en iPhone la barra de Entreno.
2. Ajustar pequenos bugs visuales de movil.
3. Inicializar Git separado.
4. Crear primer commit estable.
5. Subir a repo remoto privado/personal.

### Medio plazo

1. Modularizar `App.tsx`.
2. Crear backend minimo:
   - usuario
   - perfil
   - entrenamientos
   - sesiones
   - ranking
   - partner plans
   - chats
3. Anadir autenticacion.
4. Migrar localStorage a API + cache local.
5. Reintroducir PWA offline con versionado.

### Ranking/social real

1. Definir modelo de usuario.
2. Guardar sesiones reales.
3. Calcular Gym Score en backend.
4. Guardar ubicacion aproximada, nunca exacta.
5. Crear filtros por global/pais/ciudad/area.
6. Crear visibilidad voluntaria en mapa.
7. Crear solicitudes y chat.

## 12. Credenciales y Git

Para subir este proyecto a Git no necesito tu password.

Opciones recomendadas:

### Opcion A: GitHub CLI ya autenticado

Si tienes `gh` instalado y autenticado:

```bash
gh auth status
```

Solo necesito que me digas:

- nombre del repo
- si lo quieres publico o privado
- organizacion/cuenta donde crearlo

Ejemplo:

```txt
Repo: gym-swipe-ios
Visibilidad: privado
Cuenta: tu usuario personal de GitHub
```

### Opcion B: repo remoto ya creado

Tu creas el repo en GitHub/GitLab/Bitbucket y me pasas la URL remota:

```txt
git@github.com:usuario/gym-swipe-ios.git
```

o

```txt
https://github.com/usuario/gym-swipe-ios.git
```

Con eso yo puedo:

```bash
git init
git add .
git commit -m "Initial app version"
git branch -M main
git remote add origin <url>
git push -u origin main
```

### Opcion C: token personal

No es la opcion preferida dentro del chat.

Si no tienes `gh` autenticado ni SSH configurado, lo mejor es que autentiques tu maquina localmente con:

```bash
gh auth login
```

o configures SSH. Evitar pegar tokens en la conversacion.

## 13. Instruccion para futuras sesiones

Si se pierde la sesion, empezar por:

```bash
cd /home/jcolas/Documentos/gym-swipe-ios
npm run lint
npm run build
sed -n '1580,2705p' src/App.tsx
sed -n '2707,4184p' src/App.tsx
sed -n '360,1485p' src/App.css
```

Leer tambien:

```txt
MEMORIA_PROYECTO.md
```

Regla de mantenimiento:

- Cada vez que se haga una feature relevante, actualizar este archivo.
- Cada vez que se corrija un bug importante, anadirlo en "Bugs o riesgos conocidos" o "Estado actual".
- Cada cambio de arquitectura debe quedar reflejado en "Arquitectura de datos" o "Proximos pasos".

