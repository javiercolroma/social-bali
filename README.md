# Memoria del proyecto: Gym Swipe iOS

Ultima actualizacion: 2026-06-29

> ⚠️ **MIGRACION A NATIVO (en curso).** La app iOS se esta reescribiendo a **SwiftUI 100% nativa** (Fase 1 completada). El antiguo enfoque web en `WKWebView` queda **deprecado**: el target iOS ya NO carga `WebDist` ni usa la web; ahora arranca `RootView` (SwiftUI). El codigo web en `src/` permanece en el repo pero **no lo usa la app**. La documentacion de abajo (secciones 1-24) describe la app WEB original y se conserva como referencia funcional/de producto mientras se porta a Swift.
>
> **App nativa (Swift) — archivos clave en `ios/GymSwipeIOS/`:** `GymSwipeIOSApp.swift` (entry), `AppStore.swift` (estado + persistencia en UserDefaults + acciones), `Models.swift`, `GymScore.swift` (logica de score), `LocationManager.swift` (CoreLocation nativo), `RootView.swift` (TabView nativo + cabecera + sheets), `TrainView/PlanView/RankingView/PartnerView/ProfileView.swift`, `SocialViews.swift` (mensajes, chat, amigos, notificaciones, perfil de amigo, alta de cuenta), `Components.swift`, `Theme.swift`.
>
> **Estado Fase 1:** compila y corre. Implementado nativo: alta de cuenta, Entreno (cargar/serie hecha-saltada/descanso/cronometro), Plan (biblioteca + preview + cargar), Comunidad = Ranking (tabla + mapa MapKit con zoom + ubicacion real; el Gym Score se movió a Actividad ▸ Progreso) + Partner (planes, crear, aceptar→chat, descartar, tus planes con tu nombre) en un selector segmentado, Actividad (historial personal + estadisticas), Perfil (nivel/XP/datos), Social completo (mensajes/chat/amigos/buscar/notificaciones/perfil de amigo), integración con la app **Salud (HealthKit)** para leer la frecuencia cardíaca en el entreno. Persistencia en `UserDefaults` (clave `forge-native-v1`).

> **Seguimiento estilo Instagram (público/privado + solicitudes):** `SocialPerson.isPrivate` y `Profile.isPrivate` (toggle "Cuenta privada" en Perfil). En el perfil de alguien (`FriendProfileView`) hay un botón **Seguir / Siguiendo / Pendiente**: perfil **público** → al pulsar Seguir empiezas a seguir al instante (`.friends`, "Siguiendo"); perfil **privado** → se envía una solicitud (`.outgoing`, "Pendiente") y el usuario privado (simulado) la acepta tras unos segundos → "Siguiendo" + notificación "X ha aceptado tu solicitud de seguimiento". `AppStore.followOrRequest(id)` centraliza seguir/cancelar/dejar de seguir respetando la privacidad. Las **solicitudes entrantes** (alguien quiere seguirte) llegan como notificación (`NotificationType.friendRequest`) con botones **Aceptar/Rechazar** en línea en `NotificationsSheet`; al resolver, la notificación refleja el resultado ("Has aceptado/rechazado la solicitud de X"). También hay `NotificationType.newFollower` ("X ha empezado a seguirte") para seguidores de cuentas públicas. El perfil de usuario muestra avatar/@usuario (+ candado si es privada), fila estilo Instagram (Entrenos/Seguidores/Siguiendo, tappables → lista con buscador). **En cuentas privadas que aún no sigues**, los contadores de Seguidores/Siguiendo se muestran pero **NO son tocables** (no se puede abrir la lista — `profileCountsRow(locked:)`), igual que Instagram; el resto del contenido (Gym Score, barras, histórico) queda oculto tras el aviso "Esta cuenta es privada". Gym Score + Racha, barras de pilares y su histórico con **calendario mensual** + entrenos como posts. Tu propio perfil es `MeProfileView` (mismo formato) con un engranaje arriba que abre **Ajustes** (`SettingsView`). Perfil/ajustes separados: **Editar perfil** (`EditProfileView`: foto, nombre, @usuario, sexo, fecha de nacimiento, país, ciudad, gimnasio y **redes sociales** Instagram/TikTok/X que aparecen como tarjetas-enlace en el perfil) y **Ajustes** (`SettingsView`: cuenta privada, sonido/vibración, Salud, **política de privacidad** y **términos** en `LegalView`, soporte, versión y **cerrar sesión** vía `store.logout()`).

> **Onboarding cálido para usuarios nuevos (`OnboardingView.swift`):** los usuarios nuevos ya no ven el formulario único; pasan por un **acompañamiento amable, una pregunta por pantalla**, guiados por **Forgey**, la **mascota original** de la app (personaje "blob" dibujado con shapes de SwiftUI: cuerpo `BlobShape` con **degradado** verde, **brillo** superior, sombra de contacto, ojos con **destello** blanco que parpadean, sonrisa suave y mejillas difuminadas; saluda con la mano en la bienvenida y sostiene un corazón en el paso de Salud; idle bob + parpadeo por temporizador). Cada pantalla está **centrada** (no formulario pegado arriba) y Forgey "habla" en un **bocadillo** (texto en tinta, nada de texto gris explicativo). **Encuesta conversacional estilo "una pregunta por toque"** (inspirada en el género de onboarding de apps tipo Duolingo — patrones de interacción genéricos, NO una copia de su arte/personaje/textos): el bocadillo de Forgey **se escribe letra a letra a ritmo pausado y natural** (`TypingBubble`: ~40 ms/letra con **variación humana por letra** (no mecánico), pausa tras `. , ! ?` y respiración inicial; tope total para frases largas; toca para completar). **Sin cursor parpadeante** (el de antes "bailaba" junto al texto multilínea) y el bocadillo **reserva su tamaño final** (texto completo invisible debajo) para que NO salte ni crezca mientras aparecen las letras., aparecen **tarjetas de respuesta de selección única** (`SelectCard`) con emoji que al tocarlas se rellenan de verde con check + háptica, **Forgey reacciona** (squash + cara feliz `^^` + chip "¡A por esos músculos!" via `bounceTrigger`; el chip va en su PROPIO espacio reservado ENCIMA de la cabeza, nunca sobre la cara), y "Continuar" está **en gris hasta que eliges** y entonces se pone verde. **Todos** los bocadillos de la app (bienvenida, encuesta, foto, sobre-ti, dónde-entrenas, Salud) usan el mismo tecleado para una voz coherente. Cuatro preguntas propias de fitness: **objetivo** (goal, **multi-selección**), **experiencia** (level, única), **días/semana** (weeklyDays, única) y **motivación** (motivation, **multi-selección**), persistidas como campos opcionales en `Profile` (las multi se guardan unidas por ", " en el orden de las opciones). `surveyStep` (única, `Binding<String?>`) y `surveyMultiStep` (multi, `Binding<Set<String>>`) comparten la misma maquetación/`SelectCard`. Pantallas: **bienvenida** ("¡Hola! Soy Forgey…", bocadillo tecleado) → **nombre** (requerido) → **@usuario** (requerido, validación en vivo "está libre"/error; copy sin "colegas") → **objetivo · experiencia · días · motivación** (encuesta de tarjetas, una por toque) → **foto** → **"Cuéntame un poco sobre ti"** (dos **ruletas clásicas de iPhone** apiladas, cada una con su pregunta en tinta: "¿Cuándo naciste?" — solo año, por defecto 1997 — y "¿Cuál es tu sexo?" — por defecto Hombre) → **"¿Dónde sueles entrenar?"** (país/ciudad/gimnasio, sin etiquetas grises; el desplegable de ciudad es más bonito —tarjeta elevada con sombra, pin verde en círculo, filas más altas— y el gimnasio se marca "(opcional)" para no resultar invasivo) → **Salud** (`health.connect()` solo al pulsar; copy alternativo si no está disponible) → **cierre personal centrado** ("¡Listo, {nombre}!" con aro verde que se dibuja + avatar con spring). Solo nombre y @usuario bloquean; los pasos no obligatorios se saltan con un discreto "Quizá más tarde". En el paso de la foto, el botón "Elegir foto" **abre el selector** y, tras elegir, se abre un **editor de encuadre manual** (`OnboardingPhotoFramer`: arrastrar + pellizcar en un círculo de 240 pt) para que la foto NO se recorte automáticamente; la escala/desplazamiento se guardan en `Account.photoScale/photoOffsetX/Y` (mismo espacio que `MeAvatar`), se reflejan en la vista previa del círculo y en el avatar final, y tocar el círculo vuelve a abrir el editor. La secuencia se encadena limpia: al elegir, el selector se cierra primero y, tras una breve pausa, sube el editor de encuadre. Barra de progreso fina, flecha atrás (oculta en bienvenida/cierre), transiciones deslizantes asimétricas, respeta Reduce Motion. Los datos viven en `@State` del `OnboardingView` (no se pierden al volver atrás); al terminar se guarda con `store.saveAccount` + se escriben en `store.profile` SOLO los campos que el usuario rellenó (el año → fecha 15-jun de ese año; género solo si no es "No especificar"). Diseñado con un workflow de tono + crítica de "buen gusto", mascota y copy 100% originales (inspirado en el género de onboarding cálido, NO una copia de otra app). El antiguo `AccountSetupView` (formulario simple) se conserva **solo para EDITAR** la cuenta; `RootView` ramifica el `fullScreenCover`: `store.account == nil` → `OnboardingView`, edición → `AccountSetupView`. Ya **no** se auto-pide Salud al guardar.
>
> **Salud / Frecuencia cardíaca (HealthKit):** `HealthManager` (singleton `@MainActor`) pide permiso de LECTURA de frecuencia cardíaca (`requestAuthorization(toShare: [], read: [.heartRate])`) y, durante la sesión, recoge muestras con `HKAnchoredObjectQuery` (BPM en vivo + media + máximo). En `TrainView` hay una píldora ❤️ en la cabecera: "Conectar Salud" si no está conectado, o los `ppm` en vivo si lo está; el BPM mostrado es la muestra más reciente por `endDate` (HealthKit no garantiza orden). Al guardar, `avgHeartRate`/`maxHeartRate` se almacenan en `WorkoutSession` (campos opcionales, seguros para datos antiguos) y se muestran en el resumen y en `ActivityDetailView`. La captura se reinicia por IDENTIDAD del entreno cargado (`onChange(of: exercises.first?.id)`) para no contaminar al cargar otro entreno sin guardar, y arranca también si conectas Salud a mitad de sesión (`onChange(of: health.connected)`). El permiso de Salud se pide en su **propio paso del onboarding** (`OnboardingView`, solo al pulsar "Conectar con Salud", con consentimiento explícito; saltable); también hay sección "Salud" en Perfil para conectarlo después. En el **resumen** al finalizar se muestran FC media y FC máx (se quitaron Volumen kg y XP), y el tiempo de duración se **congela** al terminar (`finalElapsed`) para que no siga corriendo. Durante la sesión, el círculo de descanso está **siempre visible**: muestra la cuenta atrás cuando hay descanso activo y el estado "¡Haz tu serie!" al empezar el entreno o al terminar el descanso. project.yml: entitlement `com.apple.developer.healthkit`, framework `HealthKit.framework`, `NSHealthShareUsageDescription` (solo lectura; sin string de escritura). Nota: el pulso en vivo requiere Apple Watch (u otra fuente) escribiendo en Salud; en simulador/iPhone sin watch la UI degrada a "—".
>
> **Live Activity / widget de pantalla de bloqueo (entreno en marcha):** cuando hay un entrenamiento en curso, la app muestra una **Live Activity (ActivityKit)** en la pantalla de bloqueo y en la **Isla Dinámica**. Tecnología: una **extensión de widget** (`ForgeWidget`, target `app-extension` en `project.yml` con `NSExtensionPointIdentifier: com.apple.widgetkit-extension`, embebida en la app vía `dependencies`), más `NSSupportsLiveActivities: true` en el Info.plist de la app. Archivos: `ios/GymSwipeIOS/WorkoutActivityAttributes.swift` (tipo `ActivityAttributes` **compartido** entre app y extensión — incluido como `source` explícito en ambos targets; `ContentState` = nombre del entreno, `startedAt`, series cerradas/total, ejercicio actual, `reps`, `weight`, `setIndex`, `exerciseSets`, `bpm?`, `resting`, `restStartedAt?`, `restEndsAt?`), `ios/GymSwipeIOS/LiveActivityManager.swift` (singleton `@MainActor` con `start/update/end`, todo bajo `#available(iOS 16.2, *)` y guardando la actividad como `Any` para no exponer un tipo iOS 16.x en la clase del target iOS 16.0; respeta `ActivityAuthorizationInfo().areActivitiesEnabled`), `ios/ForgeWidget/ForgeWidgetBundle.swift` (`@main WidgetBundle`) y `ios/ForgeWidget/WorkoutLiveActivity.swift` (`ActivityConfiguration`: vista de pantalla de bloqueo + regiones de Isla Dinámica, paleta lima/ink de la marca). La pantalla de bloqueo tiene un diseño **simple de una sola fila de cabecera** + un bloque de contenido: cabecera con 🏋️ **nombre del ejercicio actual** (el nombre del entreno NO se muestra) y, a la derecha, el chip "Serie X/Y" (+ ❤️ ppm si hay pulso). El **cronómetro de duración del entreno se ELIMINÓ del widget**. Debajo, los **controles interactivos** o, en descanso, el **aro de cuenta atrás** (ver más abajo). Ciclo de vida en `TrainView`: `start` al empezar (`onAppear`/al cargar otro entreno), `update` en cada serie registrada/ajuste y al llegar muestras de FC (`onChange(of: health.liveBPM)`), `end` al cerrar el último ejercicio, al pulsar "Finalizar entrenamiento" y en `resetLocal` (guardar/descartar). La extensión despliega a iOS 16.2; la app sigue en 16.0 con guardas `#available`.
>
> **Controles interactivos del widget (iOS 17+):** desde la propia pantalla de bloqueo / Isla Dinámica se puede **manejar el entreno completo sin abrir la app**: ajustar **repeticiones** (− / +), ajustar **peso** (− / + en pasos de 2,5 kg), marcar serie **Hecho** o **Saltar** (que avanzan de serie y, al cerrar la última, **pasan al siguiente ejercicio** — el widget se actualiza con el nuevo nombre), y durante el **descanso** una **fila compacta horizontal**: aro de cuenta atrás a la izquierda, "DESCANSO" + "Recupera fuerzas" en el medio y botón **Saltar** a la derecha (el layout vertical anterior era demasiado alto y se recortaba en el lock screen; el horizontal encaja limpio). El aro es un `ProgressView(timerInterval:countsDown:)` con `.progressViewStyle(.circular)` (la ÚNICA primitiva que se auto-anima en una Live Activity; un `Circle().trim()` quedaría congelado entre updates). Detalles clave: (1) **un solo dígito, bien centrado** — el contador va DENTRO del aro como `currentValueLabel` (el sistema lo centra solo, sin solapamientos ni cálculos manuales) y `label:` se deja vacío; el bug previo de "dígitos superpuestos" venía de tener a la vez el contador interno del `ProgressView` y un `Text` superpuesto; (2) **tamaño** — se controla con `.frame(width:height:)` (sí funciona en el contexto de Live Activity, al contrario que dentro de la app). Se evita `.scaleEffect`, que emborronaba el trazo y descuadraba el aro; (3) **encaje** — fila horizontal compacta (~62pt de alto) en vez de bloque vertical alto, para no recortarse en el lock screen. El layout se validó con un harness temporal en la app (`FORGE_HARNESS=1`) que replica la tarjeta a tamaño real de Live Activity y se captura por `simctl screenshot` (el render exacto del aro del sistema solo se ve en una Live Activity real; ver memoria del proyecto). Para el aro se añadió `restStartedAt` al `ContentState` (intervalo del aro = `restStartedAt…restEndsAt`). En la **Isla Dinámica** también se quitó el cronómetro: las zonas compacta/mínima/expandida muestran la cuenta atrás del descanso o "Serie X/Y" según el estado. Implementación: botones `Button(intent:)` (WidgetKit interactivo, iOS 17+) que disparan `WorkoutControlIntent` (`ios/GymSwipeIOS/WorkoutIntents.swift`). Es un **`LiveActivityIntent`**, así que el sistema ejecuta `perform()` **dentro del proceso de la app** (no en la extensión); ahí publica el comando en `WorkoutRemote.shared` (`ios/GymSwipeIOS/WorkoutRemote.swift`, bus `@MainActor` con un token incremental para que repetir la misma acción siempre dispare). `TrainView` observa ese bus (`.onReceive(remote.$pending…)`) y aplica el comando con su MISMA lógica de UI (`register`, `store.adjustReps/adjustWeight`, +15s/saltar descanso) y vuelve a llamar a `syncLive()`, manteniendo una sola fuente de verdad. **Rendimiento de los steppers (reps/peso) en el widget:** lo que daba la sensación de lentitud era el camino `intent → WorkoutRemote (@Published) → TrainView → store → syncLive → activity.update` (varios saltos de SwiftUI antes de redibujar el widget). Ahora el **App Intent actualiza la Live Activity DIRECTAMENTE**: `WorkoutControlIntent.perform()` llama a `LiveActivityManager.shared.bumpReps/bumpWeight`, que mutan el `ContentState` que el manager guarda como fuente de verdad y hacen `activity.update` al instante — sin esperar a la vista ni al store. En paralelo, `WorkoutRemote.send` sincroniza el store (TrainView aplica `adjustReps/adjustWeight` pero **ya no re-empuja** la Live Activity para reps/peso). Además `adjustReps/adjustWeight` usan **persistencia diferida** (`persistSoon()`, ~0,6 s) en vez de recodificar todo el estado en cada toque. (`LiveActivityManager.swift` se compila también en el target del widget para que el intent compartido encuentre el símbolo; en runtime se usa la instancia del proceso de la app.) El `ContentState` compartido se amplió con `reps`, `weight`, `setIndex`, `exerciseSets`. En iOS 16.2–16.x (sin botones interactivos) el widget degrada a solo lectura (muestra reps/peso/series como texto). Limitación conocida: los botones requieren que la app esté viva en segundo plano (flujo normal: empiezas el entreno y bloqueas el móvil); si la app se ha cerrado por completo, el sistema la relanza pero la sesión en memoria no se restaura.
>
> **Añadido tras Fase 1:** Plan con "Crear entrenamiento" (formulario de ejercicios) y sin tarjeta "Biblioteca; Ranking con scope "Amigos" por defecto (ranking real de tus amigos); Partner con "Cuándo" y "Dónde" en el creador y flecha atrás a la izquierda (en vez de X); foto de perfil seleccionable (PhotosPicker) y ajustable (arrastrar/pellizcar), tanto en Perfil como al crear cuenta (`Account.photoData/scale/offset`, `PhotoSupport.swift`).
>
> **Detalle del entreno (historial) — solo series HECHAS:** el detalle (`ActivityDetailView`) muestra únicamente las series completadas. Antes, un ejercicio saltado por completo aparecía con círculos verdes porque `saveSession` guardaba `SessionExercise.sets = series planeadas` cuando no había completadas; ahora **solo se añaden a `items` los ejercicios con `completedSets > 0`**, con `sets = completedSets` y `logs` = solo las series hechas (`setLog` nunca guarda las saltadas). `expandedSets` ya no fabrica círculos de más. Las series saltadas se siguen registrando en `history` (status `.skipped`) para las estadísticas, pero no se pintan como hechas.
>
> **Resumen del entreno (al guardar):** nombre editable (con default = nombre del entreno), campo "¿Qué tal te ha ido?" (notas), foto opcional (PhotosPicker) y visibilidad (Todos / Seguidores / Solo yo). Se guarda como `WorkoutSession` (modelo nuevo, persistido en `store.sessions`) además del historial/XP. Pendiente: mostrar las sesiones propias en el muro Social.
>
> **Entreno (flujo de sesion):** boton "Finalizar entrenamiento"; al terminar se muestra un RESUMEN tipo Strava (duracion, series, volumen, XP) con Guardar/Descartar (el historial/XP/racha se confirman solo al Guardar). Tras Guardar/Descartar se vuelve al estado de carga, que ahora muestra un único estado vacío limpio y centrado (icono mancuerna en círculo verde, "¿Qué entrenamos hoy?" + un solo botón primario "Elegir entreno") que cambia a la pestaña Plan (`onGoToPlan` → `tab = 1`). Se quitaron la lista "TUS MÁS FRECUENTES" y el botón "Otros entrenos".
>
> **Plan / entrenos (nativo):** crear entreno con formulario mejorado (tarjetas de ejercicio con steppers redondos, boton "Añadir ejercicio" con borde discontinuo). Grupos personalizados: cada entreno tiene `block` como grupo (chips sugeridos + grupo nuevo escribible); Plan agrupa por grupos. Editar entrenos (boton Editar en el preview → reabre el formulario; los built-in se editan creando copia, los tuyos se actualizan in situ). **Eliminar cualquier entreno** (también los de por defecto): botón "Eliminar entreno" SIEMPRE visible al entrar en el preview + opción "Eliminar" en el menú contextual (long-press) de la fila. La confirmación es ahora un **`.alert`** centrado que nombra el entreno ("Se quitará «X» de tu lista de entrenos"). `AppStore.deleteWorkout` borra los entrenos propios de `savedWorkouts` y **oculta los de por defecto** añadiéndolos a `hiddenWorkoutIds` (`Set<String>` persistido); `allWorkouts` filtra los ocultos, así desaparecen del Plan.
>
> **Partner (nativo):** "Buscar compañero" abre el creador como POP-UP (sheet `CreatePlanView`) con Cuándo/Dónde/Qué/Plazas y opcion "Me adapto" en todos; flecha "Atrás" arriba-izquierda. Eliminar plan propio pide confirmación con un **`.alert`** centrado que nombra el plan y avisa de que es irreversible ("Dejarás de buscar compañero para «X». Esta acción no se puede deshacer."), en vez del antiguo action sheet genérico. **Filtro de distancia** ("Cerca de mí", `maxKm` **1–100**, "Sin límite" en el tope): `DistanceSlider` **personalizado** (en PartnerView.swift) — pista fina (4pt) + **pulgar circular pequeño** (16pt, blanco con aro verde) sobre `GeometryReader` + `DragGesture(minimumDistance: 0)`, continuo (se desliza suave, antes con `Slider(step: 5)` iba a trompicones). El mínimo es **1 km** y se redondea solo para mostrar/filtrar; la lista de planes aparece/desaparece con una animación suave (`.animation(value: visiblePlans.count)`) y se **ordena por cercanía** (los planes de gente más cercana salen primero; tus planes, a 0 km, encabezan). Se hizo a medida porque el `Slider` de SwiftUI no permite achicar el pulgar.
>
> **Pantalla de entreno (pulida):** cabecera con nombre del entreno + barra de progreso animada; tarjeta de ejercicio con "SERIE X DE Y", nombre grande, dots de serie animados (spring), stats con iconos; botones Hecho/Saltar grandes con háptica + sonido (`SessionFX.swift`: `Haptics`, `SoundFX`); transicion deslizante entre ejercicios; banner de DESCANSO con anillo circular countdown (+15s / saltar) y aviso al terminar; resumen final con CONFETI (`ConfettiView`). Sonidos/Vibración con toggles en Perfil (`@AppStorage fxSound/fxHaptics`).
>
> **Entreno (edición en vivo + descanso):** reps y peso EDITABLES durante la sesión con steppers − / + (peso en pasos de 2.5 kg; icono mancuerna en vez de báscula). El descanso por defecto es 2 min, se muestra en mm:ss y NO tiene botón de saltar; al agotarse NO para: sigue contando en "overtime" (color ámbar, "+m:ss", "Te estás pasando · llevas X descansando") para llevar la cuenta. Se quitó el stat fijo de descanso de la tarjeta.
>
> **Feedback global (`FX` en SessionFX.swift):** háptica en toda la app (cambio de pestaña = selection, taps, success al aceptar/crear/guardar, warning al borrar) respetando los toggles Sonidos/Vibración. Sonidos SOLO en momentos clave para no cansar: aceptar amistad, aceptar entrenamiento y crear cuenta (además de los sonidos propios de la sesión de entreno). `FX.tap/selection/success(sound:)/warning`.
>
> **Sonidos (paleta `Synth`, SessionFX.swift):** tonos **sinusoidales limpios y suaves** (seno puro, con rampa de entrada y de salida para que no chasqueen, decaimiento exponencial, volumen bajo). NO se usan armónicos duros ni *soft-clip* (un intento previo con síntesis aditiva sonaba metálico/distorsionado y se descartó). Cues discretos: `start`, `done` (un solo "tin" suave), `skip` (grave suave), `exercise`, `rest`, `milestone`, `success`, `finish` (carrera ascendente corta).
>
> **Pantalla de entreno (detalles, sin gamificación de rachas):** sin XP ni volumen-kg ni rachas/llamas dentro del entreno (se probó un chip de racha "🔥" y se quitó por petición del usuario: no tiene sentido una racha dentro de una misma sesión). Se conservan toques sutiles y con sentido: (1) **microcopia de coach** en el banner de descanso (rota frases curadas de descanso / tras saltar, y "¡Vamos!" al acabar el descanso; reusa los `Text` existentes, sin elementos nuevos); (2) **"fire" del botón Hecho** — onda (anillo que se expande) + *bloom* de resplandor + leve sobreimpulso, todo en overlay sin mover el layout; (3) **hito del 50%** — un tick que se vuelve oro y hace pop en la barra de progreso + cue de `milestone`, y la cuenta "X / Y series" rueda con `contentTransition(.numericText())`. Estado en `@State` de `TrainView`, se resetea al cargar/terminar entreno.
>
> **Gym Score en la foto de perfil del header:** el avatar de perfil del header (`RootView.header`, abre `MeProfileView`) lleva un **badge verde con el Gym Score** (`store.gymScore.total`) en la **esquina inferior derecha** de la foto (cápsula `Brand.green` con borde blanco para resaltar sobre la imagen); se actualiza con el score real y forma parte del botón que abre el perfil.
>
> **Navegación:** Perfil se movió de la tab bar al header (avatar arriba a la derecha junto a Mensajes/Notificaciones → abre ProfileView en sheet). Barra inferior PERSONALIZADA (`CustomTabBar`): orden **Social · Plan · Entreno · Comunidad · Actividad**, con **Entreno en el centro como botón especial** (círculo verde elevado). La navegación es un `ZStack` de 5 pantallas controlado por un único `@State tab` (no se pierde el estado de cada pestaña). Tags: Social=0, Plan=1, Entreno=2, Comunidad=3, Actividad=4 (onGoToPlan→1, onLoaded→2). **Comunidad** (`CommunityView`) fusiona Ranking + Partner de forma natural mediante un selector segmentado (Ranking / Partner) sin perder ninguna funcionalidad: ambas vistas (`RankingView`, `PartnerView`) viven en un ZStack y conservan su estado (scroll, mapa, ubicación) al cambiar de sección. **Actividad** (`ActivityView`) tiene dos secciones con selector segmentado: **Progreso** y **Actividades**. *Progreso* contiene: una tarjeta de **racha** horizontal de extremo a extremo (el número dentro de un icono de llama 🔥 + "¡En racha!" y subtítulo aclaratorio: la racha NO son días consecutivos, son entrenos encadenados sin pasar más de 3 días de descanso); la tarjeta de **Gym Score** (movida desde Comunidad: puntuación + tier + fiabilidad + barras de pilares Fuerza/Constancia/Progreso/Volumen/Calidad/Variedad); el **calendario mensual** (`TrainingCalendarView`) con todos los días del mes (huecos vacíos para los días del mes anterior/siguiente, NO se muestran días de otros meses), navegación de mes ‹ ›, días entrenados resaltados en verde, marca del día actual, badge si hay varios entrenos y contador del mes; al tocar un día entrenado se abre un pop-up (`DaySessionsSheet`) con los entrenos de ese día, y desde ahí el detalle (`ActivityDetailView`). Y las métricas de carga: (1) **Tendencia** — variación % del 1RM estimado medio entre el primer y el último registro, promediada entre ejercicios; (2) **Fuerza por ejercicio** — 1RM estimado por ejercicio con fórmula de Epley `w·(1+reps/30)` tomando la mejor serie de cada sesión, con delta vs primer registro y mini-sparkline (Swift Charts); incluye un botón de información (ⓘ gris) que explica en un alert qué es el 1RM estimado y la fórmula de Epley. *Actividades* contiene **solo** el histórico: la lista de tus sesiones (`store.sessions`) ordenadas por fecha; tap → `ActivityDetailView`. **Perfil** se movió al margen superior IZQUIERDO del header (avatar a la izquierda del título; Mensajes/Notificaciones quedan a la derecha). **Racha (`currentStreak`)**: es una racha "de gimnasio", no exige entrenar a diario; se mantiene mientras no pasen más de 3 días entre entrenos (y el último sea de los últimos 3 días). Cada día entrenado dentro de esa ventana de 3 días suma +1; si se superan los 3 días sin entrenar, la racha se reinicia a 0. Pestaña **Social** (`SocialFeedView`) con selector de cápsulas **Seguidos / Para ti** (ZStack, conserva estado). **Seguidos**: usuario nuevo (sin seguidos) = bienvenida "Hola, {nombre} 👋" + **tira horizontal deslizable de sugerencias** ("A QUIÉN SEGUIR", tarjetas estilo Strava: avatar/nombre/@usuario/Seguir, **sin mostrar distancia**) + debajo un feed con tus posts + posts de gente cercana que aún no sigues. Con seguidos = la tira de sugerencias (si hay) + feed con **solo** tus posts y los de quien sigues, por fecha. **El modo de layout (usuario-nuevo vs con-seguidos) se CONGELA en el snapshot del refresh** (`seguidosNewUser`): seguir a alguien desde la tira NO reorganiza el muro al instante (la tarjeta solo cambia a "Siguiendo"); las sugerencias solo "se bajan"/intercalan y el feed solo se reorganiza al hacer **pull-to-refresh**. Antes el layout dependía en vivo de `store.following.isEmpty`, así que al seguir 1-2 desaparecían inmediatamente — corregido. **Para ti** = **solo POSTS** de gente cercana que no sigues (descubrimiento, máx 2/persona, ~12, con botón "Seguir" en línea); ya no muestra listas de recomendación de amistad. El orden de cercanía es determinista (Social no pide ubicación). El **mapa de Comunidad** se carga bajo demanda (botón "Ver mapa") para no pedir permiso de ubicación al arrancar. Seguir es inmediato (`store.follow`, == amigo) con toast "Ahora sigues a {nombre}". Cada post: avatar, nombre, hora, ubicación, título, nota, foto, métricas (Tiempo/Series/Ejerc. — se eliminó "kg vol." de todas las tarjetas y del detalle por ser un número grande poco útil; el pilar "Volumen" del Gym Score 0–100 se mantiene) y fila de acciones **estilo Instagram** (sin fondo/cápsula, no verde): **like** (corazón, se pone rojo al pulsar, contador; persistido en `store.appliedKudos`), **comentario** (icono `bubble.right` con nº de comentarios) y **compartir** (avión de papel `paperplane` con nº de veces compartido). **Comentarios estilo Instagram** (`CommentsSheet`): cada comentario muestra autor, texto, antigüedad ("hace …" vía `relativeTime`), botón de **like** por comentario y **Responder** (respuestas anidadas 1 nivel); caja de composición con "Respondiendo a {nombre}"; comentarios demo deterministas por post para que el muro se sienta vivo. Los **pop-ups (sheets)** ya no llevan botón "Cerrar": se cierran deslizando hacia abajo (gesto nativo de iOS); el chat (fullScreenCover) mantiene su flecha de volver. **`MessagesSheet`** (Amigos/Mensajes) **no tiene título de navegación** ("Mensajes" arriba se quitó por redundante: el selector segmentado Amigos/Mensajes ya etiqueta la pantalla). En **Amigos**, la sección "Solicitudes recibidas" **solo aparece si hay solicitudes** entrantes (antes mostraba "Sin solicitudes pendientes." sin sentido cuando no había ninguna). `seedDemo` arranca SIN seguidos (Mika pasa a recomendación, Leo a solicitud entrante) para mostrar la experiencia de usuario nuevo. Tap en un post → detalle; tap en una persona → su perfil. Ranking → mapa con usuarios demo cerca de tu ubicación, pin tocable → ficha (`MapUserSheet`) con perfil y añadir amigo.
>
> **Perfil:** selector de idioma (🌐, solo Español activo); edad por FECHA DE NACIMIENTO (DatePicker) con edad calculada; país (lista del sistema en español) y ciudad (búsqueda MapKit sesgada al país). Catálogo de ejercicios con autocompletado en crear/editar entreno (`Exercises.swift`); grupos personalizados con desplegable y "Crear «X»".
>
> **Tarjetas de entreno unificadas (sistema compartido):** antes había 5 layouts de tarjeta duplicados + 4 estilos de fila de stats distintos. Se unificaron en componentes compartidos en `Components.swift`, reutilizados en el feed Social, "Para ti", histórico de Actividad, perfiles (propio y de amigo) y el pop-up del calendario: (1) **`WorkoutTypeBadge`** — tile redondeado **neutro** (`Brand.chip` con la mancuerna en gris `Brand.soft`) que sustituye la mancuerna verde suelta; discreto a propósito (el verde llamativo se descartó por petición del usuario), tamaños `.full`/`.compact`; (2) **`WorkoutStatStrip`** — UNA franja de stats con un solo fondo `Brand.surface` y separadores finos (hairlines), nada de píldoras sueltas; números `monospacedDigit` + `design: .rounded` para que no "bailen"; `.full` (feed: micro-iconos, más alta) y `.compact` (filas de histórico: sin iconos, más baja); su builder `metrics(time:sets:exercises:ppm:)` es la **única fuente** de las métricas (Tiempo/Series/Ejerc./ppm — nunca volumen ni XP); (3) **`WorkoutPhoto`** — bloque de foto uniforme (esquinas redondeadas + hairline). La tarjeta **full** (feed) lleva además una línea divisoria fina entre la cabecera de autor y el contenido, y el título subió a 18pt. Diseño elegido con un workflow (3 direcciones → síntesis con crítica de "buen gusto") y verificado con harness + screenshots.
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
- **Tarjeta de plan simplificada:** menos texto y la **descripción con más peso**. Orden: cabecera (avatar + nombre + distancia + chip "Score") → **título** (foco del entreno, grande) → **descripción** (el `note`, ahora 15pt semibold y oscuro, es lo segundo más prominente) → una sola línea meta compacta (📅 cuándo · 📍 dónde) → acciones. Se quitaron el prefijo "Propuesto por", la fila de lugar aparte y el tag de plazas.

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
