# Memoria del proyecto: Gym Swipe iOS

Ultima actualizacion: 2026-07-01

> ⚠️ **MIGRACION A NATIVO (en curso).** La app iOS se esta reescribiendo a **SwiftUI 100% nativa** (Fase 1 completada). El antiguo enfoque web en `WKWebView` queda **deprecado**: el target iOS ya NO carga `WebDist` ni usa la web; ahora arranca `RootView` (SwiftUI). El codigo web en `src/` permanece en el repo pero **no lo usa la app**. La documentacion de abajo (secciones 1-24) describe la app WEB original y se conserva como referencia funcional/de producto mientras se porta a Swift.
>
> **App nativa (Swift) — archivos clave en `ios/GymSwipeIOS/`:** `GymSwipeIOSApp.swift` (entry), `AppStore.swift` (estado + persistencia en UserDefaults + acciones), `Models.swift`, `GymScore.swift` (logica de score), `LocationManager.swift` (CoreLocation nativo), `RootView.swift` (TabView nativo + cabecera + sheets), `TrainView/PlanView/RankingView/PartnerView/ProfileView.swift`, `SocialViews.swift` (mensajes, chat, amigos, notificaciones, perfil de amigo, alta de cuenta), `Components.swift`, `Theme.swift`.
>
> **Estado Fase 1:** compila y corre. Implementado nativo: alta de cuenta, Entreno (cargar/serie hecha-saltada/descanso/cronometro), Plan (biblioteca + preview + cargar), Comunidad = Ranking (tabla + mapa MapKit con zoom + ubicacion real; el Gym Score se movió a Actividad ▸ Progreso) + Partner (planes, crear, aceptar→chat, descartar, tus planes con tu nombre) en un selector segmentado, Actividad (historial personal + estadisticas), Perfil (nivel/XP/datos), Social completo (mensajes/chat/amigos/buscar/notificaciones/perfil de amigo), integración con la app **Salud (HealthKit)** para leer la frecuencia cardíaca en el entreno. Persistencia en `UserDefaults` (clave `forge-native-v1`).

> **Compartir entrenos por el chat:** en un chat, el botón 🏋️ (junto a la barra de escribir) abre `ShareWorkoutPicker` con TUS entrenos del plan (`store.allWorkouts`); al elegir uno se envía como un mensaje especial. La plantilla viaja **codificada (base64 JSON) dentro del texto** tras el marcador `WorkoutShare.marker` (sin cambiar el esquema de `messages`). El receptor ve una **tarjeta** (`SharedWorkoutCard`: nombre, nº de ejercicios, bloque, vista rápida de 4 ejercicios) con botón **«Añadir a mi plan»** → `store.addSharedWorkout` (re-genera ids, evita duplicados por nombre, lo guarda en `savedWorkouts`, bloque «Compartidos» si no traía). `ChatMessage.sharedWorkout` decodifica; la burbuja del chat pinta la tarjeta en vez del texto. El botón **+** (estilo menú de adjuntar, para ampliar en el futuro) abre el selector; elegir un entreno lo **adjunta** al compositor (chip «Entreno adjunto» con ×) sin enviarlo — se manda al pulsar enviar (junto con el texto si lo hay). La tarjeta enviada muestra **hora + doble check** (como un mensaje), sin recuadro «Enviado». En la lista de conversaciones el preview usa `ChatMessage.preview` → «📋 Entreno: {nombre}» (nunca el JSON codificado). **Añadir a mi plan** siempre funciona: `addSharedWorkout` re-genera ids y, si ya tienes un entreno con ese nombre, lo guarda como «{nombre} (2)» para que ambos sean **editables** por separado.

> **Forgey IA — coach on-device (Apple Foundation Models, iOS 26+):** IA 100 % **en el dispositivo** (sin peticiones a servidores; los datos de entreno no salen del iPhone), **centralizada en la mascota** en vez de fragmentada por pantallas. (1) **Chat con Forgey** (`ForgeyChatView`): botón con la carita de Forgey + ✨ en la **cabecera de TODAS las pantallas**; chips de arranque («¿Qué debería entrenar hoy?», «¿En qué ejercicios progreso menos?», «¿En qué debo mejorar?»…), burbujas con la mascota, «Forgey está pensando…». (2) **Crear entreno desde una descripción** (Plan → «Crear con Forgey (IA)», `AIWorkoutSheet`): describes el entreno → **guided generation** (`@Generable AIWorkout/AIExercise`) devuelve estructura tipada → previsualización con `WorkoutExerciseList` → «Guardar en mi plan» o regenerar. (3) `ForgeyAI.swift`: disponibilidad con mensajes humanos (`SystemLanguageModel.availability`: dispositivo no compatible / Apple Intelligence apagado / modelo descargándose), `context(from:)` compacto con racha+score+últimas 10 sesiones (mejor serie por ejercicio)+**progresión de 1RM por ejercicio** (para responder «dónde progreso menos»), persona de Forgey en español, texto plano, sin consejos médicos. Todo tras `#if canImport(FoundationModels)` + `@available(iOS 26)` — con target iOS 16, en dispositivos sin Apple Intelligence sale una tarjeta explicativa. **VALIDADO E2E en el simulador iOS 26**: respuesta real del modelo en el chat y entreno estructurado real generado (capturas).

> **Internacionalización FASE 2 + 3 idiomas nuevos:** ahora **5 idiomas**: español (fuente), **inglés, portugués de Portugal, portugués de Brasil y francés** — catálogos completos (241 claves × 4) + **~40 claves de FORMATO** para las cadenas con números («SERIE %lld DE %lld», «%lld ejercicios · %@», «Vas #%lld…»). **Nombres de ejercicios/plantillas/grupos traducidos al mostrarse** (`L10n.x`: mapa es→en/pt-PT/pt-BR/fr de ~60 ejercicios del catálogo + grupos; los datos guardados no cambian y los nombres puestos por el usuario se respetan) en TrainView, Plan (listas/preview/cabeceras de grupo), detalle, récords, fuerza por ejercicio y tarjetas compartidas. **La IA responde en el idioma del usuario** (`L10n.aiLanguage` inyectado en los tres prompts; los entrenos generados nombran los ejercicios en ese idioma). Selector de Ajustes ampliado a los 5 idiomas. Verificado onboarding en francés e inglés. Cola restante: interpolaciones poco visibles y textos-parámetro de componentes.

> **Internacionalización (fase 1) + entradas multilínea:** idioma de desarrollo = **español** (`developmentLanguage: es` — las cadenas del código son las claves) + catálogo **`en.lproj/Localizable.strings` con 236 traducciones al inglés** de todos los literales estáticos de la UI (extraídos por script de Text/Label/Button/navigationTitle/TextField/alert/confirmationDialog). Al abrir la app por primera vez se usa el **idioma del sistema** automáticamente; en **Ajustes → Idioma** selector manual (Automático/Español/English vía `AppleLanguages`, aplica al relanzar, con aviso). Verificado en simulador con `-AppleLanguages (en)` (onboarding completo en inglés). **Pendiente fase 2**: cadenas con interpolación (`"Hasta \(x) km"` → claves de formato), textos que llegan como parámetros String a componentes, nombres de ejercicios/plantillas (son datos) y respuestas de la IA en inglés. Además: los campos de escritura largos (chat de Forgey y mensajes) ahora hacen **saltos de línea nativos** (`axis: .vertical`, 1-4 líneas) en vez de una línea infinita.

> **IA 2.0 — dos motores, prompts compartidos, uso medido y seguridad:** (1) **`ForgeyPrompts`** (fuente única de prompts): ámbito BLINDADO (solo fitness/datos del usuario/entrenos; respuesta fija ante otros temas e intentos de "ignora tus instrucciones"), precisión/formato, protocolo **`ENTRENO_SUGERIDO:`** y reglas de carga. (2) **Botón «Crear entreno de esto» SOLO cuando procede**: el modelo añade la línea `ENTRENO_SUGERIDO: <descripción>` únicamente si la conversación lo justifica; la UI la extrae (parser tolerante a variantes) y el botón abre el generador **auto-generando con esa descripción ya escrita por el LLM** (el usuario no teclea). (3) **`ForgeyEngine`** selector: on-device (Apple) si puede; si no, **nube** = Edge Function **`forgey-ai`** (DESPLEGADA, v1 ACTIVA) → Claude **Haiku** con JWT obligatorio, topes de longitud server-side, tope duro 100/día y registro en **`ai_usage`** (migración `0019`: user+día, on_device/cloud/tokens — base del futuro plan de pago; el uso on-device también se registra vía `bump_ai_usage`). La nube está **apagada** (`FeatureFlags.cloudAIEnabled=false` + falta `ANTHROPIC_API_KEY` en secretos; la función responde 503 hasta entonces). La foto NUNCA sale del dispositivo (Vision local en ambos modos; a la nube solo van mediciones en texto). (4) **Cargas con sentido**: `referenceLoads` (máximos reales por ejercicio) en el prompt (65-80 % del máximo, nunca superarlo) + `clampWeights` local (si el modelo se pasa, baja al ~75 % del máximo real). (5) Seguridad de entrada: solo imágenes decodificables (cinturón además de los pickers), topes 200/220 caracteres en cliente + re-capado server-side.

> **Análisis corporal: E2E con foto real + robustez Vision:** probado end-to-end en el simulador con una foto real de cuerpo entero (foto → burbuja → análisis del LLM + chip). Hallazgo: `VNDetectHumanBodyPoseRequest` **NO funciona en el simulador** (error Code=9 "Unable to setup request"; en Mac/iPhone real la misma foto da hombros 0,70/0,73 y caderas 0,62/0,57 ✓). `bodyMetrics` es ahora `detectBody` → enum de 3 casos: `.metrics` (análisis completo), `.noPerson` (Vision funcionó y no hay persona → pedir otra foto) y `.unavailable` (Vision no disponible → analiza SOLO con el reparto de entreno y lo dice — antes mentía con "no veo un cuerpo"). La foto de pruebas está en el carrete del simulador (`simctl addmedia`). El camino completo con mediciones debe probarse en un iPhone con iOS 26.

> **Forgey chat, flujo directo:** el chip «✨ Crear entreno de esto» ahora **genera directamente** (AIWorkoutSheet con `autoGenerate: true` — se abre generando y aterrizas en la TARJETA del entreno para previsualizar, ponerle nombre/grupo y «Guardar y entrenar» o «Solo guardar»), sin pasar por la pantalla de texto. **Tope de caracteres**: 200 en el chat de Forgey y 220 en la descripción del generador (el modelo on-device es pequeño; nada de Quijotes).

> **Ronda 8 — WorkoutMedia único + encuadre pro + fix 3 puntitos:** (1) **Regla nueva (memoria): cualquier cambio a las tarjetas del post aplica a TODAS las tarjetas de entreno** → el medio visual vive en UN componente, `WorkoutMedia` (foto → pager [foto entera + tarjeta stats]; sin foto → `WorkoutCover`), usado por feed (320), historial/perfiles/calendario (160) y detalle (260). (2) **Encuadre de foto mejorado**: el hueco se rellena con la MISMA foto difuminada y aclarada (blur 22 + velo blanco 45%, técnica Instagram) + sombra suave a la foto — ya no parece "desampliada" sobre bandas planas. (3) **Bug 3 puntitos en Actividad**: un `Menu` dentro del label de un `Button` no recibe toques (el botón se los come) → el menú va ahora como overlay hermano del botón, con zona táctil de 40×44.

> **Ronda 7 — consistencia de score, follow robusto y fotos protagonistas:** (1) **Gym Score canónico en el servidor** (`0017_profile_score`: `profiles.gym_score`): cada cliente sube el SUYO (`pushGymScore` al guardar/borrar sesión), el feed lo trae embebido en el autor y las búsquedas/seguidos lo siembran (`seedScores`); la caché de scores es ahora `@Published` → al refrescarse, TODAS las insignias visibles se repintan (antes convivían 14 y 16 según cuándo se pintó cada tarjeta). (2) **Follow**: política `follows_update_self` (`0018`) — el upsert de re-seguir tras un pending/accepted previo fallaba por RLS en silencio; el error de follow ahora se loguea en vez de tragarse. (3) **Posts con foto**: la foto es la protagonista — ENTERA (aspect-fit sobre fondo BLANCO — sin bandas negras, homogéneo con la app clara; `FullWorkoutPhoto`) y deslizando a la derecha una segunda página (TabView .page) con la tarjeta visual de estadísticas.

> **Tarjetas de entreno UNIFICADAS en toda la app**: la misma tarjeta que en los posts del feed (foto si hay; si no, `WorkoutCover` con héroe variado) aparece ahora también en el historial de Actividades, en **tu perfil y el de cualquiera** (muro de entrenos), en el detalle de actividad y en las hojas del calendario. Subtítulos con mayúscula inicial.

> ⚠️ **FLAG DE PRUEBAS ACTIVA**: `FeatureFlags.allowShortWorkouts = true` permite guardar entrenos cortos/implausibles (ignora la regla anti-fake en cliente) para probar features en dispositivo. **APAGAR antes de cualquier lanzamiento público.** Nota: el trigger del servidor sigue marcando `verified=false` para esos entrenos (el ranking real no se contamina).

> **Feedback en dispositivo real (6ª ronda, ampliada):** el **widget también VIBRA**: los App Intents no pueden disparar haptics (proceso en background), así que se usa `sensoryFeedback` (iOS 17+) disparado por el CAMBIO de estado que provoca cada botón — ajustar reps/peso → toque medio, cerrar serie → éxito, empezar/terminar descanso → toque; en iOS 16 no vibra (API no disponible). Subtítulos de `WorkoutCover` con mayúscula inicial.

> **Feedback en dispositivo real (6ª ronda):** (1) **Portada de posts sin foto con héroe VARIADO** (minutos / series / ejercicios, hash estable por post; el volumen se quitó a petición). (2) **Widget más rápido para ajustar**: aceleración de taps — pulsar rápido seguido en la misma dirección duplica el paso (peso 2,5→5→10 kg, reps 1→2; un tap suelto vuelve al paso base): de 20 a 60 kg son 6 toques en vez de 16. (3) **3 puntitos en las tarjetas de Actividades** → «Eliminar entreno» con confirmación (`AppStore.deleteSession`: quita local, recalcula histórico/score/racha, borra fila y foto del servidor). (4) Partner: **slider de km REAL** vía celdas de ~5 km heredadas del perfil al publicar (`0016_plan_cells`, trigger; haversine en cliente; chip «a ~N km»; los planes sin celda siempre visibles, al final).

> **Feedback en dispositivo real (5ª ronda):** (1) **PARTNER HA VUELTO, y REAL** (`partnerEnabled=true` + migración `0015_training_plans`): planes de entrenamiento en Supabase (ver todos los de 14 días, crear/borrar los tuyos vía RLS), autor real con avatar/nombre embebidos, «Aceptar entrenamiento» envía un mensaje por el **chat real** y abre la conversación; **el slider de km funciona también con planes reales** (`0016_plan_cells`): al publicar, el plan hereda por trigger la celda de ~5 km del perfil del autor (nunca coordenadas exactas); el cliente calcula haversine entre tu celda y la del plan → chip «a ~N km», filtro por distancia y orden por cercanía; los planes sin celda (autor sin ubicación) se muestran siempre, al final. (2) **Flecha de VOLVER en los pop-ups** (`SheetBackButton`, circulito con chevron arriba-izquierda; deslizar hacia abajo sigue funcionando): chat Forgey, generador IA, previsualizaciones de entreno, compartir, crear/editar entreno, progreso de ejercicio, detalle de actividad, Gym Score, fuerza por ejercicio, récords, buscar personas, guardar entreno compartido y hoja de email. (3) **Portada visual para posts SIN foto** (`WorkoutCover`): gradiente de marca + mancuerna en marca de agua + dato héroe VARIADO por post — a veces minutos, a veces series, a veces ejercicios (hash FNV estable del título+fecha; sin volumen, quitado a petición) — con los otros dos datos debajo — el feed ya no es una pila de texto. (4) **Más vibraciones**: marcar serie (éxito)/desmarcar (suave), steppers del editor, seguir a alguien (éxito), enviar mensajes, y las existentes. (5) **La flecha de los posts del feed ahora abre el detalle** (era decorativa). (6) Progreso: fuera la fila «Tus récords» (ya embebidos en fuerza por ejercicio) y **vuelve la teja de la mancuerna con el %** (carga 1RM medio, la visualización favorita del usuario).

> **Feedback en dispositivo real (4ª ronda) — editor de rutinas:** (1) **El teclado tapaba la tarjeta del ejercicio**: `ScrollViewReader` + `scrollTo(id, anchor: .center)` al cambiar el foco (con retardo para esperar al teclado), padding inferior de 260 y `scrollDismissesKeyboard(.interactively)`. (2) **Editar una rutina predefinida "no se guardaba"**: la copia editable se creaba con id NUEVO y la previsualización seguía mirando el id viejo → ahora la copia **CONSERVA el id** y pisa a la plantilla en `allWorkouts` (los guardados tienen prioridad sobre las plantillas por id); borrar la copia restaura la predefinida.

> **Feedback en dispositivo real (3ª ronda):** (1) **BUG CRÍTICO de Storage cazado**: las políticas comparaban la carpeta con `auth.uid()::text` (minúsculas) y Swift subía a `uid.uuidString` (MAYÚSCULAS) → **todas las subidas de fotos desde la app fallaban en silencio** (entrenos y avatares). Triple arreglo: políticas insensibles a mayúsculas (`0014_storage_case_fix`), cliente con carpetas en minúsculas, y **curación en la sync** (sesión del servidor sin `photo_url` + `photoData` local → re-subida automática); el error de subida ahora se loguea. (2) **Regla anti-fake v2**: mínimo **1 serie hecha + 60 s totales** además de la media de 20 s/serie (con 0 series la regla pasaba trivialmente y un entreno de 2 s se guardó). (3) **Cámara para la foto del entreno**: diálogo «Hacer foto / Elegir de la galería» (`CameraPicker` con UIImagePickerController; `NSCameraUsageDescription` añadido; en dispositivos sin cámara va directo a galería). Galería no requiere permiso (picker fuera de proceso). (4) **Buscador de Amigos REAL**: buscaba solo en la lista demo (vacía en producción) → ahora `searchProfiles` con debounce 300 ms, excluyendo al propio usuario; filas con foto real. (5) **Color SOLO en crear/editar** (iterado): burbuja verde numerada + steppers SERIES (verde) / REPS (ámbar) / KG (azul) con iconos en el editor, y mancuerna en las filas del Plan; la **previsualización del entreno volvió a sobria** a petición (número gris, «4×8 · 60 kg» en gris; la superserie mantiene su letra verde por ser información). (6) El contador de **activos (30 días)** se carga al entrar en Comunidad y se ve también con el mapa plegado.

> **Feedback en dispositivo real (2ª ronda):** (1) **XP solo agregado a nivel de entreno** (se quitó el desglose por ejercicio/serie a petición): chip «+N XP» en la tarjeta de Actividades + métrica en el detalle. (2) **IA oculta en dispositivos que NUNCA la soportarán** (`ForgeyAI.isSupported`: iOS <26 o hardware sin Apple Intelligence → desaparecen ForgeyPeek y «Crear con Forgey»; estados transitorios —IA apagada, modelo descargándose— sí muestran la tarjeta explicativa). (3) **Mapa de calor de actividad** (migración `0013_activity_heatmap`): el cliente sube SOLO una celda redondeada a 0,05° (~5 km) + `active_at` (`updatePresence` desde LocationManager; `touchPresence` al abrir la app); RPCs agregados `activity_heatmap` (celda→conteo, sin identidades) y `active_users_count` (30 días); el mapa de Comunidad con backend muestra **burbujas de calor** (tamaño/número por celda, no tocables) + chip «N activos · 30 días»; sin backend, mapa demo. (4) **El mapa recuerda que lo abriste** (`@AppStorage communityMapOpen` — antes se cerraba en cada visita). (5) **Invitaciones bien pensadas**: el mensaje lleva tu **@usuario** + enlace a `docs/invite.html?u=<handle>` (pulsable en WhatsApp) → botón «Abrir en la app» = deep link **`forgeloop://user/<handle>`** (esquema registrado; `onOpenURL` → `openProfileByHandle` busca el perfil y lo abre listo para seguir — la «solicitud de amistad» de la invitación) + «Descargar» con hueco para el App Store cuando exista. (6) **Título del header en una línea** en cualquier pantalla (`minimumScaleFactor(0.55)` — «Comunidad» se partía).

> **Feedback en dispositivo real (1ª ronda):** (1) **ForgeyPeek ARRASTRABLE**: arrastra a Forgey verticalmente por el borde derecho y se queda donde lo dejes (posición persistida en `@AppStorage forgeyPeekYFrac`, límites 50pt de márgenes, muelle al soltar; tap sigue abriendo el chat — `onTapGesture` + `DragGesture(minimumDistance: 6)` conviven). (2) **XP visible en el histórico**: chip «+N XP» en cada tarjeta de Actividades, métrica «+N XP» en el detalle, chip por ejercicio («+66 XP» = 12/serie + 18 de bono) y «+12 XP» por serie (`ActivityData.xp`; solo en tus sesiones — los posts de otros no lo muestran).

> **Instalación en iPhone físico (hecha por primera vez):** `project.yml` lleva ahora `DEVELOPMENT_TEAM: H8K8QNTDBA` + `CODE_SIGN_STYLE: Automatic` (sobrevive a xcodegen). ⚠️ La capacidad **Sign in with Apple está COMENTADA** en los entitlements — los Personal Team gratuitos no la soportan y bloquean la firma; **restaurar al pasar a la cuenta de pago** (el botón de Apple del login no funcionará mientras tanto: usar email OTP o Google). Flujo por terminal: `xcodebuild -destination 'platform=iOS,id=<device>' -allowProvisioningUpdates build` + `xcrun devicectl device install app --device <id> <ruta>.app`. Requisitos en el iPhone: Modo de desarrollador activado + Confiar en el certificado (Ajustes → General → VPN y gestión de dispositivos). Cuenta gratuita: la app caduca a los 7 días (reinstalar); con cable la primera vez, luego posible por Wi-Fi (Connect via network).

> **Forgey: análisis de físico por foto + follow-ups accionables:** (1) **Foto** (botón 📷 en el chat): honestidad técnica — el modelo on-device NO ve imágenes y Vision no juzga "músculo"; lo que se hace: `ForgeyAI.bodyMetrics` (Vision `VNDetectHumanBodyPoseRequest`) mide **proporciones reales** (ratio hombros/cadera con referencias, asimetría de hombros) y se combina con `trainingSplit` (**reparto real del volumen por patrón**, solo sesiones fiables — la señal más honesta de qué está descuidado) → el LLM da 2-3 zonas a priorizar con ejercicios, marcado como APROXIMADO, sin juicios duros ni consejos médicos; si no se detecta un cuerpo → mensaje amable pidiendo foto de cuerpo entero. La burbuja del usuario muestra la miniatura. (2) **Follow-up en TODAS las respuestas**: instrucción de cerrar siempre con una pregunta ofreciendo el siguiente paso + chip **«✨ Crear entreno de esto»** bajo la última respuesta → abre `AIWorkoutSheet(initialDescription:)` prellenado con el consejo. Validado E2E: respuesta con dato exacto + follow-up + chip (captura).

> **Anti-fake v4 (regla FINAL, iterada con el usuario):** único criterio = **duración: media ≥ 20 s por serie completada** (sin tope de series ni de XP — las sesiones largas legítimas no se penalizan), en cliente y servidor (`0012_verify_duration.sql`, trigger en vivo). La **pantalla final se muestra NORMAL** (🏁 + estadísticas); si la sesión es implausible aparece una tarjeta ámbar informativa «Este entreno no se guardará — duración demasiado baja (X series en M:SS)», botón **«Seguir entrenando»** si quedaban ejercicios (por si finalizaste sin querer) y **«Continuar»** (primario) para salir; sin formulario de guardado ni confeti.

> **Anti-fake v3 (feedback):** (1) **Umbral recalibrado a 15 s de MEDIA por serie** (antes 20; es media de la sesión, no por serie individual — una serie suelta rápida no penaliza) en cliente Y servidor (migración `0012_verify_15s`, trigger actualizado en vivo). (2) **El guardado se BLOQUEA**: si la sesión es implausible, el resumen no ofrece guardar — muestra «Demasiado rápido para ser real» (series y tiempo) + solo Descartar, sin confeti (`TrainView.sessionPlausible`, misma fórmula). (3) **La IA y las estadísticas solo usan entrenos FIABLES**: `ForgeyAI.context` (chat + generador), `lastPerformance` («última vez»), `liftProgress` (Fuerza por ejercicio) y `ExerciseProgressView` (evolución) filtran `verified`. (4) Respuestas del chat **más cortas y estructuradas**: máx 50 palabras, primera línea = respuesta, máximo 3 líneas «- », sin párrafos.

> **Anti-fake COMPLETO (sesiones cortas fuera del Gym Score):** las sesiones implausibles (`verified=false`: <20 s/serie, >60 series o >600 XP) ya no contaban para liga/récords públicos, pero SÍ alimentaban el Gym Score y registraban récords en silencio — cerrado: (1) `HistoryEntry.verified` (nil = legado = cuenta) se marca al guardar y en `rebuildHistoryFromSessions`; (2) `GymScoreEngine.calculate` filtra las no verificadas al inicio; (3) `detectPRs(celebrate:)` — una sesión fake **ni registra ni celebra** récords (antes contaminaba `personalBests` en silencio; el parámetro `verified` pasó a `celebrate`, que solo distingue el backfill silencioso tras re-login); (4) el aviso al guardar añade «ni el Gym Score». Decisión consciente: la **racha sí** cuenta sesiones no verificadas (presentarse cuenta; la nota no).

> **Progreso v2 — panel compacto (vistazo → detalle):** la pantalla apilaba 7 bloques largos; ahora cada cosa se lee de un vistazo y el detalle vive en hojas. (1) **RESUMEN**: Racha y Gym Score en **dos tiles lado a lado** (`heroRow`); el de score muestra nota + chip de división y **toca → hoja** con el desglose completo (pilares, fiabilidad, ⓘ — la antigua `gymScoreCard` entera). (2) **Fuerza por ejercicio** absorbe la Tendencia como **chip** en su cabecera («+39%», antes tarjeta entera), muestra el **top 4** y «Ver los N ejercicios» → hoja con la lista completa (cada fila sigue abriendo su evolución). (3) **Récords**: top 3 + «Ver los N récords» → `AllRecordsSheet`. (4) Misiones se queda (accionable). **Iteración con feedback:** el **calendario sube justo debajo de racha/score** (dentro de RESUMEN, `calendarBlock`) y **Tus récords se une a la tarjeta de Fuerza** como fila fina al pie («🏆 Tus récords · N ›» → `AllRecordsSheet`), sin tocar las filas de fuerza; desapareció la sección RÉCORDS independiente (`RecordsCard` queda sin uso en Progreso). Orden final (tras quitar también las Misiones de Progreso a petición del usuario — `WeeklyQuestsCard` queda sin uso; las misiones siguen vivas en celebraciones/recompensas al completar): Resumen (racha+score) → calendario → Fuerza por ejercicio (+récords). Se eliminaron `rachaCard` y `trendCard` (fusionados).

> **Chat de Forgey v2 — precisión + formato:** (1) El contexto pasa de prosa a **datos ESTRUCTURADOS con las respuestas pre-calculadas** (`ForgeyAI.context`): MEJORES MARCAS ordenadas por 1RM, TU MEJOR EJERCICIO, EL QUE MÁS ENTRENAS, PROGRESIÓN por ejercicio con MAYOR/MENOR PROGRESO, últimos entrenos — el modelo pequeño responde bien cuando el dato exacto ya está servido (antes «resumía el perfil» en vez de contestar). (2) Instrucciones quirúrgicas: responder EXACTAMENTE lo preguntado en 2-4 frases, **la primera frase ya es la respuesta** (sin preámbulos tipo «¡Estoy emocionado…!»), sin enumerar datos no pedidos. (3) **Formato bonito**: la burbuja interpreta el Markdown inline línea a línea (negritas reales, viñetas «* »→«• », interlineado). Validado E2E con datos sembrados: «¿En qué ejercicio soy mejor?» → «tu mejor ejercicio es **la sentadilla**, 1RM estimado 117 kg» (dato exacto). (4) **ForgeyPeek más arriba** (padding inferior 400, ~tercio superior) y con **badge ✨** (el símbolo clásico de IA) en círculo blanco sobre la parte visible.

> **Tarjetas de entreno del chat v2:** (1) **TODA la tarjeta** abre la previsualización (contentShape + onTapGesture; el botón «Añadir» conserva su toque). (2) Al dar a «Añadir a mi plan» (en la tarjeta o en la previsualización) aparece `SaveSharedWorkoutSheet` (detent .medium): **NOMBRE** prellenado editable + **GRUPO** (campo libre para apartado nuevo + chips con tus apartados existentes) → Guardar. `addSharedWorkout(_:name:group:)` acepta overrides. (3) **Fuera los botones Cerrar/Cancelar de TODOS los sheets** (AuthProviderSheet, ForgeyChat, AIWorkoutSheet, ShareWorkoutPicker, SharedWorkoutPreview…): en iPhone se desliza hacia abajo y listo; se conservan los «Cancelar» de los diálogos de confirmación destructivos (cerrar sesión, eliminar cuenta/entreno), que son otra cosa.

> **Forgey se ASOMA por el lateral (`ForgeyPeek`):** para que el coach IA esté más presente, Forgey sobresale por el borde DERECHO de la pantalla (medio cuerpo fuera, inclinado −16°, saludando), flotando sobre el contenido en las 5 pantallas (overlay `bottomTrailing` sobre el ZStack de pantallas, por encima de la barra). Cada ~5–7 s se asoma un poco más durante 1,2 s (muelle suave; respeta Reduce Motion) como diciendo «estoy aquí». Toca → abre el chat de Forgey IA. El botón de la cabecera se quitó (redundante; la cabecera respira).

> **Generador IA v2 — grupos musculares correctos + guardar a tu manera:** el modelo on-device es pequeño y colaba ejercicios de otro grupo (pedías pierna y salía press banca) porque el prompt tenía una lista plana de ejemplos sesgada a torso (los modelos pequeños COPIAN los ejemplos). Defensa en 3 capas en `ForgeyAI.generateWorkout`: (1) catálogo de ejemplos **POR GRUPO** en las instrucciones + regla crítica explícita; (2) **verificación LOCAL** de cada ejercicio generado contra lo pedido (`targetGroups(in:)` extrae los grupos de la descripción; `exerciseGroups(_:)` clasifica cada ejercicio por nombre con orden cuidado: «curl femoral»=pierna, «elevación de piernas»=core); (3) si algo no encaja → **reintento correctivo** en la misma sesión nombrando los ejercicios mal puestos, y filtrado final de los claramente fuera de grupo (si quedan ≥3). Validado E2E: «Pierna completa con énfasis en glúteo» → 4/4 de pierna (sentadilla, prensa, hip thrust, gemelos). Además, al guardar puedes **editar el NOMBRE** y elegir **GRUPO/apartado del plan** (campo libre + chips con tus grupos existentes), o abrir «Ajustar ejercicios antes de guardar». El CTA principal es **«Guardar y entrenar ahora»** (guarda + `loadWorkout` + navega a Entreno vía `onLoaded` — antes solo guardaba y te dejaba sin cargar), con secundaria «Solo guardar en el plan»; al guardar, el `day` de los ejercicios pasa a ser el nombre final elegido (el encabezado del entreno muestra TU nombre) → `CreateWorkoutView` prefijado con lo generado.

> **Arreglos de sugerencias/búsqueda:** en `DiscoverPeopleView` (1) el filtro de «tú mismo» usaba `currentUserId` SÍNCRONO (nil en arranque frío mientras se restaura la sesión) → **aparecías tú como sugerencia para seguirte**; ahora usa `currentUserIdAsync()`. (2) Tras cada búsqueda se recarga `loadFollowing` para no mostrar «Seguir» en gente que ya sigues. (3) **Avatar y nombre tocables** → abren la previsualización del perfil (`FriendProfileView`), sigas o no a la persona.

> **Tienda ELIMINADA:** fuera `Shop.swift` (ShopView, TitlesView, cosméticos, marcos de avatar, `buyCosmetic`/`buyFreeze`/`equip*`) y todo su cableado (fila «Tienda» de la tarjeta de gamificación, sheet, overlay `AvatarFrame`). Las **monedas se mantienen como puntos de recompensa** (logros/misiones las siguen dando y el saldo se ve en una fila pasiva «Monedas» de la tarjeta); los campos persistidos de cosméticos se conservan para compatibilidad de decodificación.

> **Mascota: se probaron dos rediseños (blob musculado con etapas y llama) y NO convencieron → REVERTIDOS.** Forgey vuelve al diseño original (squircle verde sonriente) y a su presencia original (onboarding + tutoriales). Si se retoma, partir de concepto nuevo con el usuario antes de implementar.
> **P1 retención:** (1) **«Última vez» en el entreno**: la tarjeta del ejercicio activo muestra un chip «Última vez: 60 kg × 8 · hace 3 días» (`AppStore.lastPerformance` — mejor serie por 1RM de la sesión más reciente con ese ejercicio). (2) **Evolución por ejercicio** (`ExerciseProgress.swift`): en Actividad ▸ Progreso, cada fila de «Fuerza por ejercicio» abre una hoja con la evolución — dato grande actual + chip Δ%, selector **Peso/Reps/1RM est.**, gráfica de área verde (Swift Charts, catmullRom, último punto destacado), rango 1M/3M/Todo, mejores marcas (peso/1RM/sesiones) e historial de series por sesión. Una métrica a la vez = sencillo. (3) **Partner OCULTO en v1** (`FeatureFlags.partnerEnabled=false`): sigue siendo demo; Comunidad = solo Ranking (sin selector) y su tour se reduce a 2 pasos de ranking; el código de Partner queda intacto para migrarlo a real. (4) **Notificaciones** (`NotificationManager.swift`): recordatorio LOCAL de racha (pide permiso al guardar un entreno; programa aviso 3 días después a las 18h — cada entreno lo re-programa, si entrenas nunca suena; se cancela en logout) + scaffolding push (AppDelegate registra token APNs → `device_tokens` con RLS; el envío server-side necesita la clave APNs del Apple Developer account). (5) **Compresión de imágenes** en `PhotoPickerLabel` (todas las fotos: avatar y entreno): reescala a ≤1600px + JPEG 0.72 ANTES de persistir/subir (antes un HEIC de 10 MB acababa entero en UserDefaults y Storage). (6) **Invita a tus amigos**: tarjeta con ShareLink al final de Amigos (cold start).

> **P0 producción:** (1) **Eliminar cuenta in-app** (App Store 5.1.1): migración `0010_delete_account` — RPC security-definer `delete_my_account()` que borra tu fila de `auth.users` (cascadas verificadas: profiles→todo, workouts); `Backend.deleteAccount()` borra antes tus archivos de Storage (best-effort) y cierra sesión; UI en Perfil → Ajustes → «Eliminar cuenta» (confirmación destructiva + spinner + alert de error); `AppStore.deleteAccount()` remata con `logout()`. Validado E2E por API (signup → delete → login falla). (2) **Solicitudes de seguimiento REALES** (cuentas privadas): antes eran invisibles para el receptor (solo demo). `Backend.fetchFollowRequests/acceptFollowRequest/rejectFollowRequest` (las políticas ya lo permitían: UPDATE/DELETE por `following_id`); `AppStore.incomingRequestPeople` + `loadFollowRequests()` (en `loadFollowing`); `relationship()` devuelve `.incoming` para reales; aceptar/rechazar escriben en el servidor; la sección «Solicitudes recibidas» y el contador «Amigos (N)» incluyen las reales. (3) **Legales como URL pública** (`docs/`): `privacy.html` REESCRITA para la era backend (Supabase, HealthKit, ubicación, borrado in-app; la anterior decía «local-first», ya falso) + `terms.html` nueva (tolerancia cero UGC) — listas para GitHub Pages y los campos de App Store Connect. (4) Tabla `device_tokens` (`0011`) con RLS para el scaffolding de push.

> **Entrenos creados sincronizados (no se pierden al cerrar sesión):** antes `savedWorkouts` era **solo local** y `logout()` lo borra (aislamiento entre cuentas), así que al reentrar tus entrenos creados desaparecían. Ahora se **suben a Supabase** (migración `0009_workouts` — tabla `workouts` con `exercises` jsonb + RLS por dueño): `addWorkout`/`updateWorkout`/`addSharedWorkout` hacen `pushWorkoutToBackend` (upsert por id), `deleteWorkout` borra también en el servidor, y `syncWorkoutsFromBackend` (arranque + tras cada login) trae los del servidor como fuente de verdad y **sube los locales que faltaran**. Validado end-to-end por API (insert 201 + fetch por RLS + otro usuario ve `[]`). `Backend.WorkoutRow`/`upsertWorkout`/`deleteWorkout`/`fetchMyWorkouts`.

> **Superseries (elegante en plan + entreno + widget):** `Exercise` lleva `supersetGroup: String?` — ejercicios **consecutivos con el mismo id** forman una superserie (se entrenan alternando **una serie de cada, sin descanso entre ellos**; el descanso llega al **cerrar la ronda**). **Editor** (`CreateWorkoutView`): entre dos ejercicios aparece un conector — verde **«Superserie»** si están enlazados, gris **«Enlazar en superserie»** si no; `DraftExercise.linkNext` marca el enlace y `save()` asigna un id de grupo a cada tramo unido (prefill lo reconstruye desde `supersetGroup`). **Entreno** (`TrainView`): `AppStore.activeExercise` **rota** dentro del grupo (el pendiente con menos series cerradas → A·1, B·1, A·2, B·2…) y `restsAfterSet` solo descansa al cerrar la ronda; la tarjeta muestra una tira **«🔗 SUPERSERIE · sin descanso entre ejercicios»** con los ejercicios enlazados (A/B) y el activo resaltado. **Widget/Isla** (`ContentState.supersetPartner`): chip **«SUPERSERIE → {siguiente}»** en el lock screen y en la Isla expandida. **Visualización del entreno** (`WorkoutExerciseList`, reutilizable): al ver un entreno (preview del plan y previsualización de tarjeta compartida) los ejercicios de una superserie salen **agrupados** — etiqueta «🔗 SUPERSERIE · sin descanso entre ellos», fondo/borde verde y **letra A/B/C** por ejercicio. Retrocompatible: `supersetGroup` es opcional (los datos antiguos decodifican a `nil`).

> **Previsualizar entrenos compartidos antes de añadirlos:** tocar una tarjeta de entreno en el chat abre `SharedWorkoutPreview` (hoja con la lista completa vía `WorkoutExerciseList` — superseries incluidas — y CTA «Añadir a mi plan»), para decidir si te interesa antes de guardarlo. La tarjeta muestra un chevron + «Toca para previsualizar».

> **Animación de sub-pestañas (deslizamiento tipo páginas):** el componente `SlidingPages` (Components.swift) desliza horizontalmente entre las dos sub-vistas en vez de fundir/cortar. Aplicado en **Social** (Seguidos/Para ti), **Comunidad** (Ranking/Partner), **Actividad** (Progreso/Actividades) y **Mensajes** (Amigos/Mensajes). Ambas páginas quedan montadas (conservan scroll/estado); el desplazamiento va con un muelle suave (`.spring(response:0.4)`).

> **Barra de menú fluida (sin deslizar las pantallas):** la `CustomTabBar` se rediseñó para ser **fluida, no «botones»**: se quitaron los `Button` (ahora es `.onTapGesture`), el recuadro duro del activo y el **botón central elevado**; el indicador es una **píldora verde tenue que se ENCIENDE directamente en la pestaña activa** (la barra lleva `.id(tab)` — imprescindible: sin él SwiftUI a veces se salta el re-render y el resaltado se queda pegado; ya pasó dos veces) (sin deslizarse entre pestañas — se probó con `matchedGeometryEffect` y no gustó), y el icono/label activo va en verde con un leve `scaleEffect`. **Las 5 pantallas del menú NO se deslizan** (se probó y no gustó): siguen en un `ZStack` con cambio directo por opacidad; solo las **sub-pestañas** dentro de una pantalla usan `SlidingPages`.

> **Logos de proveedores en el login:** el botón de Apple usa el `SignInWithAppleButton` nativo (logo de Apple). El de Google usa `GoogleGLogo` — la **«G» de Google a 4 colores dibujada en SwiftUI** (anillo rojo/amarillo/verde + arco y barra azul), sin necesidad de imágenes. `providerButton` acepta un icono a medida (`@ViewBuilder leading`).

> **Seguimiento estilo Instagram (público/privado + solicitudes):** `SocialPerson.isPrivate` y `Profile.isPrivate` (toggle "Cuenta privada" en Perfil). En el perfil de alguien (`FriendProfileView`) hay un botón **Seguir / Siguiendo / Pendiente**: perfil **público** → al pulsar Seguir empiezas a seguir al instante (`.friends`, "Siguiendo"); perfil **privado** → se envía una solicitud (`.outgoing`, "Pendiente") y el usuario privado (simulado) la acepta tras unos segundos → "Siguiendo" + notificación "X ha aceptado tu solicitud de seguimiento". `AppStore.followOrRequest(id)` centraliza seguir/cancelar/dejar de seguir respetando la privacidad. Las **solicitudes entrantes** (alguien quiere seguirte) llegan como notificación (`NotificationType.friendRequest`) con botones **Aceptar/Rechazar** en línea en `NotificationsSheet`; al resolver, la notificación refleja el resultado ("Has aceptado/rechazado la solicitud de X"). También hay `NotificationType.newFollower` ("X ha empezado a seguirte") para seguidores de cuentas públicas. El perfil de usuario muestra avatar/@usuario (+ candado si es privada), fila estilo Instagram (Entrenos/Seguidores/Siguiendo, tappables → lista con buscador). **En cuentas privadas que aún no sigues**, los contadores de Seguidores/Siguiendo se muestran pero **NO son tocables** (no se puede abrir la lista — `profileCountsRow(locked:)`), igual que Instagram; el resto del contenido (Gym Score, barras, histórico) queda oculto tras el aviso "Esta cuenta es privada". Gym Score + Racha, barras de pilares y su histórico con **calendario mensual** + entrenos como posts. Tu propio perfil es `MeProfileView` (mismo formato) con un engranaje arriba que abre **Ajustes** (`SettingsView`). Perfil/ajustes separados: **Editar perfil** (`EditProfileView`: foto, nombre, @usuario, sexo, fecha de nacimiento, país, ciudad, gimnasio y **redes sociales** Instagram/TikTok/X que aparecen como tarjetas-enlace en el perfil) y **Ajustes** (`SettingsView`: cuenta privada, sonido/vibración, Salud, **política de privacidad** y **términos** en `LegalView`, soporte, versión y **cerrar sesión** vía `store.logout()`).

> **Onboarding cálido para usuarios nuevos (`OnboardingView.swift`):** los usuarios nuevos ya no ven el formulario único; pasan por un **acompañamiento amable, una pregunta por pantalla**, guiados por **Forgey**, la **mascota original** de la app (personaje "blob" dibujado con shapes de SwiftUI: cuerpo `BlobShape` con **degradado** verde, **brillo** superior, sombra de contacto, ojos con **destello** blanco que parpadean, sonrisa suave y mejillas difuminadas; saluda con la mano en la bienvenida y sostiene un corazón en el paso de Salud; idle bob + parpadeo por temporizador). Cada pantalla está **centrada** (no formulario pegado arriba) y Forgey "habla" en un **bocadillo** (texto en tinta, nada de texto gris explicativo). **Encuesta conversacional estilo "una pregunta por toque"** (inspirada en el género de onboarding de apps tipo Duolingo — patrones de interacción genéricos, NO una copia de su arte/personaje/textos): el bocadillo de Forgey **se escribe letra a letra a ritmo pausado y natural** (`TypingBubble`: ~40 ms/letra con **variación humana por letra** (no mecánico), pausa tras `. , ! ?` y respiración inicial; tope total para frases largas; toca para completar). **Sin cursor parpadeante** (el de antes "bailaba" junto al texto multilínea) y el bocadillo **reserva su tamaño final** (texto completo invisible debajo) para que NO salte ni crezca mientras aparecen las letras., aparecen **tarjetas de respuesta de selección única** (`SelectCard`) con emoji que al tocarlas se rellenan de verde con check + háptica, **Forgey reacciona** (squash + cara feliz `^^` + chip "¡A por esos músculos!" via `bounceTrigger`; el chip va en su PROPIO espacio reservado ENCIMA de la cabeza, nunca sobre la cara), y "Continuar" está **en gris hasta que eliges** y entonces se pone verde. **Todos** los bocadillos de la app (bienvenida, encuesta, foto, sobre-ti, dónde-entrenas, Salud) usan el mismo tecleado para una voz coherente. Cuatro preguntas propias de fitness: **objetivo** (goal, **multi-selección**), **experiencia** (level, única), **días/semana** (weeklyDays, única) y **motivación** (motivation, **multi-selección**), persistidas como campos opcionales en `Profile` (las multi se guardan unidas por ", " en el orden de las opciones). `surveyStep` (única, `Binding<String?>`) y `surveyMultiStep` (multi, `Binding<Set<String>>`) comparten la misma maquetación/`SelectCard`. Pantallas: **bienvenida** ("¡Hola! Soy Forgey…", bocadillo tecleado) → **nombre** (requerido) → **@usuario** (requerido, validación en vivo "está libre"/error; copy sin "colegas") → **objetivo · experiencia · días · motivación** (encuesta de tarjetas, una por toque) → **foto** → **"Cuéntame un poco sobre ti"** (dos **ruletas clásicas de iPhone** apiladas, cada una con su pregunta en tinta: "¿Cuándo naciste?" — solo año, por defecto 1997 — y "¿Cuál es tu sexo?" — por defecto Hombre) → **"¿Dónde sueles entrenar?"** (país/ciudad/gimnasio, sin etiquetas grises; el desplegable de ciudad es más bonito —tarjeta elevada con sombra, pin verde en círculo, filas más altas— y el gimnasio se marca "(opcional)" para no resultar invasivo) → **Salud** (`health.connect()` solo al pulsar; copy alternativo si no está disponible) → **cierre personal centrado** ("¡Listo, {nombre}!" con aro verde que se dibuja + avatar con spring). Solo nombre y @usuario bloquean; los pasos no obligatorios se saltan con un discreto "Quizá más tarde". En el paso de la foto, el botón "Elegir foto" **abre el selector** y, tras elegir, se abre un **editor de encuadre manual** (`OnboardingPhotoFramer`: arrastrar + pellizcar en un círculo de 240 pt) para que la foto NO se recorte automáticamente; la escala/desplazamiento se guardan en `Account.photoScale/photoOffsetX/Y` (mismo espacio que `MeAvatar`), se reflejan en la vista previa del círculo y en el avatar final, y tocar el círculo vuelve a abrir el editor. La secuencia se encadena limpia: al elegir, el selector se cierra primero y, tras una breve pausa, sube el editor de encuadre. Barra de progreso fina, flecha atrás (oculta en bienvenida/cierre), transiciones deslizantes asimétricas, respeta Reduce Motion. Los datos viven en `@State` del `OnboardingView` (no se pierden al volver atrás); al terminar se guarda con `store.saveAccount` + se escriben en `store.profile` SOLO los campos que el usuario rellenó (el año → fecha 15-jun de ese año; género solo si no es "No especificar"). Diseñado con un workflow de tono + crítica de "buen gusto", mascota y copy 100% originales (inspirado en el género de onboarding cálido, NO una copia de otra app). El antiguo `AccountSetupView` (formulario simple) se conserva **solo para EDITAR** la cuenta; `RootView` ramifica el `fullScreenCover`: `store.account == nil` → `OnboardingView`, edición → `AccountSetupView`. Ya **no** se auto-pide Salud al guardar.
>
> **Tutorial guiado por sección (Forgey te acompaña, estilo Duolingo) — `CoachTour`:** la **primera vez** que entras en cada una de las 5 secciones del menú (Social, Plan, Entreno, Comunidad, Actividad) aparece un tutorial breve y profesional: **Forgey** (la mascota) **asoma deslizándose desde el lateral** sobre la esquina superior izquierda de una tarjeta blanca anclada abajo, **saluda** con la mano y te da **2 consejos** escritos a máquina (mismo "tecleado" natural que el onboarding). La tarjeta lleva la **etiqueta de la sección**, **puntos de progreso**, botón **"Saltar"** (arriba-derecha) y CTA **"Siguiente" → "¡Entendido!"** en el último paso; un velo tenue (`Brand.ink` 22%) enfoca sin tapar. Forgey hace **squash + cara feliz** (`bounceTrigger`) en cada paso y respeta **Reduce Motion** (sin deslizamiento, texto instantáneo). Se muestra **una sola vez por sección**, persistido en `AppStore.seenTours` (`Set<String>`, clave `tour-<índice>`); helpers `tourSeen`/`markTourSeen`/`resetTours`. **La guía de Comunidad lleva al usuario hasta Partner y resalta cada componente (coach-marks tipo spotlight):** son **5 pasos** (1 de ranking + 4 de Partner) y, a partir del paso 1 de Partner, el tour **cambia el selector a Partner** y **resalta el componente que hay que usar en cada función**, atenuando el resto de la pantalla: la **barra de distancia** ("Con esta barra eliges a qué distancia buscar compañero"), el botón **«Buscar compañero»** ("Con este botón publicas tu propio plan…"), el botón **«Aceptar entrenamiento»** de una tarjeta ("…se abre un chat para quedar") y la **✕ de descartar** ("Descártalo con la ✕ y sigue viendo más"). El foco es un velo `Brand.ink` con un **hueco iluminado + aro verde** sobre la diana, que se **anima** de un componente a otro. Infraestructura genérica reutilizable: `TourAnchorKey` (PreferenceKey) + modificador `.tourAnchor(id)`/`.tourAnchor(id, if:)` que marca los componentes; `CoachStep` (texto + `target` opcional); `CoachDim` (velo con máscara inversa `reverseMask`). `RootView` resuelve los marcos con `.overlayPreferenceValue(TourAnchorKey.self)` + `GeometryReader` y dibuja el atenuado + aro + tarjeta; `CoachTour` reporta el `target` de cada paso vía `onTarget`, y el cambio de sub-pestaña vía `onStep` conectado a `store.communitySection` (0 = Ranking, 1 = Partner). `CommunityView` lee ese estado compartido (antes era `@State` local) para que la sub-pestaña se pueda dirigir desde fuera; `PartnerView` marca sus componentes con `.tourAnchor(...)` (la tarjeta de otra persona resaltada es la primera, `firstOtherPlanId`).
>
> **Los coach-marks de resaltar-componente se aplican a TODAS las secciones (textos cortos y sencillos):** cada tour son 2 pasos (Comunidad, 5) que **iluminan el botón/componente exacto** de esa función con una frase corta:
> - **Social**: el selector Seguidos/Para ti (`social.switch`) → "Aquí ves lo que entrenan tus colegas."; y una publicación (`social.card`) → "Dale like o comenta sus entrenos."
> - **Plan**: el botón «Crear entrenamiento» (`plan.create`) → "Crea tu propio entreno con este botón."; y el primer entreno de la lista (`plan.item`, `firstWorkoutId`) → "O toca un entreno para cargarlo."
> - **Entreno**: el botón «Elegir entreno» del estado vacío (`train.choose`) → "Aquí entrenas. Empieza eligiendo un entreno." + un paso sin diana sobre marcar series.
> - **Comunidad**: ranking + los 4 de Partner (barra de distancia, «Buscar compañero», «Aceptar», ✕ descartar).
> - **Actividad**: el selector Progreso/Actividades (`activity.switch`) → "Cambia entre tu progreso y tus entrenos."; y la tarjeta de racha/Gym Score (`activity.progress`) → "Aquí ves tu racha y tu Gym Score."
>
> Las etiquetas `.tourAnchor(id)` viven en cada vista (SocialFeedView, PlanView, TrainView, PartnerView, ActivityView); los pasos con `target` resaltan ese componente y los pocos sin `target` degradan a velo uniforme. `RootView` lo dispara con `maybeShowTour(tab)` en `onAppear`, al cambiar de pestaña y al terminar el onboarding (la cuenta pasa a existir), con un pequeño retardo y sin interrumpir si hay una hoja/chat abiertos. Ajustes ▸ **"Ver tutoriales de nuevo"** (`store.resetTours()`) los reactiva. El componente `CoachTour` vive en `OnboardingView.swift` y reutiliza la mascota `Mascot` y la voz de tecleado. Diseño elegido con un **workflow de 3 direcciones + crítica de buen gusto** (mismo patrón que el rediseño de tarjetas/onboarding).
>
> **Salud / Frecuencia cardíaca (HealthKit):** `HealthManager` (singleton `@MainActor`) pide permiso de LECTURA de frecuencia cardíaca (`requestAuthorization(toShare: [], read: [.heartRate])`) y, durante la sesión, recoge muestras con `HKAnchoredObjectQuery` (BPM en vivo + media + máximo). En `TrainView` hay una píldora ❤️ en la cabecera: "Conectar Salud" si no está conectado, o los `ppm` en vivo si lo está; el BPM mostrado es la muestra más reciente por `endDate` (HealthKit no garantiza orden). Al guardar, `avgHeartRate`/`maxHeartRate` se almacenan en `WorkoutSession` (campos opcionales, seguros para datos antiguos) y se muestran en el resumen y en `ActivityDetailView`. La captura se reinicia por IDENTIDAD del entreno cargado (`onChange(of: exercises.first?.id)`) para no contaminar al cargar otro entreno sin guardar, y arranca también si conectas Salud a mitad de sesión (`onChange(of: health.connected)`). El permiso de Salud se pide en su **propio paso del onboarding** (`OnboardingView`, solo al pulsar "Conectar con Salud", con consentimiento explícito; saltable); también hay sección "Salud" en Perfil para conectarlo después. En el **resumen** al finalizar se muestran FC media y FC máx (se quitaron Volumen kg y XP), y el tiempo de duración se **congela** al terminar (`finalElapsed`) para que no siga corriendo. Durante la sesión, el círculo de descanso está **siempre visible**: muestra la cuenta atrás cuando hay descanso activo y el estado "¡Haz tu serie!" al empezar el entreno o al terminar el descanso. project.yml: entitlement `com.apple.developer.healthkit`, framework `HealthKit.framework`, `NSHealthShareUsageDescription` (solo lectura; sin string de escritura). Nota: el pulso en vivo requiere Apple Watch (u otra fuente) escribiendo en Salud; en simulador/iPhone sin watch la UI degrada a "—".
>
> **Live Activity / widget de pantalla de bloqueo (entreno en marcha):** cuando hay un entrenamiento en curso, la app muestra una **Live Activity (ActivityKit)** en la pantalla de bloqueo y en la **Isla Dinámica**. Tecnología: una **extensión de widget** (`ForgeWidget`, target `app-extension` en `project.yml` con `NSExtensionPointIdentifier: com.apple.widgetkit-extension`, embebida en la app vía `dependencies`), más `NSSupportsLiveActivities: true` en el Info.plist de la app. Archivos: `ios/GymSwipeIOS/WorkoutActivityAttributes.swift` (tipo `ActivityAttributes` **compartido** entre app y extensión — incluido como `source` explícito en ambos targets; `ContentState` = nombre del entreno, `startedAt`, series cerradas/total, ejercicio actual, `reps`, `weight`, `setIndex`, `exerciseSets`, `bpm?`, `resting`, `restStartedAt?`, `restEndsAt?`), `ios/GymSwipeIOS/LiveActivityManager.swift` (singleton `@MainActor` con `start/update/end`, todo bajo `#available(iOS 16.2, *)` y guardando la actividad como `Any` para no exponer un tipo iOS 16.x en la clase del target iOS 16.0; respeta `ActivityAuthorizationInfo().areActivitiesEnabled`), `ios/ForgeWidget/ForgeWidgetBundle.swift` (`@main WidgetBundle`) y `ios/ForgeWidget/WorkoutLiveActivity.swift` (`ActivityConfiguration`: vista de pantalla de bloqueo + regiones de Isla Dinámica, paleta lima/ink de la marca). La pantalla de bloqueo tiene un diseño **simple de una sola fila de cabecera** + un bloque de contenido: cabecera con 🏋️ **nombre del ejercicio actual** (el nombre del entreno NO se muestra) y, a la derecha, el chip "Serie X/Y" (+ ❤️ ppm si hay pulso). El **cronómetro de duración del entreno se ELIMINÓ del widget**. Debajo, los **controles interactivos** o, en descanso, el **aro de cuenta atrás** (ver más abajo). Ciclo de vida en `TrainView`: `start` al empezar (`onAppear`/al cargar otro entreno), `update` en cada serie registrada/ajuste y al llegar muestras de FC (`onChange(of: health.liveBPM)`), `end` al cerrar el último ejercicio, al pulsar "Finalizar entrenamiento" y en `resetLocal` (guardar/descartar). La extensión despliega a iOS 16.2; la app sigue en 16.0 con guardas `#available`.
>
> **Controles interactivos del widget (iOS 17+):** desde la propia pantalla de bloqueo / Isla Dinámica se puede **manejar el entreno completo sin abrir la app**: ajustar **repeticiones** (− / +), ajustar **peso** (− / + en pasos de 2,5 kg), marcar serie **Hecho** o **Saltar** (que avanzan de serie y, al cerrar la última, **pasan al siguiente ejercicio** — el widget se actualiza con el nuevo nombre), y durante el **descanso** una **fila compacta horizontal**: aro de cuenta atrás a la izquierda, "DESCANSO" + "Recupera fuerzas" en el medio y botón **Saltar** a la derecha (el layout vertical anterior era demasiado alto y se recortaba en el lock screen; el horizontal encaja limpio). El aro es un `ProgressView(timerInterval:countsDown:)` con `.progressViewStyle(.circular)` (la ÚNICA primitiva que se auto-anima en una Live Activity; un `Circle().trim()` quedaría congelado entre updates). Detalles clave: (1) **un solo dígito, bien centrado** — el contador va DENTRO del aro como `currentValueLabel` (el sistema lo centra solo, sin solapamientos ni cálculos manuales) y `label:` se deja vacío; el bug previo de "dígitos superpuestos" venía de tener a la vez el contador interno del `ProgressView` y un `Text` superpuesto; (2) **tamaño** — se controla con `.frame(width:height:)` (sí funciona en el contexto de Live Activity, al contrario que dentro de la app). Se evita `.scaleEffect`, que emborronaba el trazo y descuadraba el aro; (3) **encaje** — fila horizontal compacta (~62pt de alto) en vez de bloque vertical alto, para no recortarse en el lock screen. El layout se validó con un harness temporal en la app (`FORGE_HARNESS=1`) que replica la tarjeta a tamaño real de Live Activity y se captura por `simctl screenshot` (el render exacto del aro del sistema solo se ve en una Live Activity real; ver memoria del proyecto). Para el aro se añadió `restStartedAt` al `ContentState` (intervalo del aro = `restStartedAt…restEndsAt`). En la **Isla Dinámica** también se quitó el cronómetro: las zonas compacta/mínima/expandida muestran la cuenta atrás del descanso o "Serie X/Y" según el estado. Implementación: botones `Button(intent:)` (WidgetKit interactivo, iOS 17+) que disparan `WorkoutControlIntent` (`ios/GymSwipeIOS/WorkoutIntents.swift`). Es un **`LiveActivityIntent`**, así que el sistema ejecuta `perform()` **dentro del proceso de la app** (no en la extensión); ahí publica el comando en `WorkoutRemote.shared` (`ios/GymSwipeIOS/WorkoutRemote.swift`, bus `@MainActor` con un token incremental para que repetir la misma acción siempre dispare). `TrainView` observa ese bus (`.onReceive(remote.$pending…)`) y aplica el comando con su MISMA lógica de UI (`register`, `store.adjustReps/adjustWeight`, +15s/saltar descanso) y vuelve a llamar a `syncLive()`, manteniendo una sola fuente de verdad. **Rendimiento de los steppers (reps/peso) en el widget:** lo que daba la sensación de lentitud era el camino `intent → WorkoutRemote (@Published) → TrainView → store → syncLive → activity.update` (varios saltos de SwiftUI antes de redibujar el widget). Ahora el **App Intent actualiza la Live Activity DIRECTAMENTE**: `WorkoutControlIntent.perform()` llama a `LiveActivityManager.shared.bumpReps/bumpWeight` (async), que mutan el `ContentState` que el manager guarda como fuente de verdad y hacen `activity.update`. **Clave del segundo arreglo de latencia:** `perform()` **ESPERA (`await`) esa actualización** — el sistema recarga la UI del widget justo al terminar `perform()`, así que si el update no está confirmado para entonces (antes se lanzaba en un `Task` sin esperar), la recarga muestra el valor viejo y el cambio no se ve hasta la siguiente pasada → sensación de botón lento. Con el await, el valor nuevo aparece en la recarga inmediata (patrón documentado de `LiveActivityIntent`). Los bumps aplican además los mismos topes que la app (reps ≤ 50, peso ≤ 500) para no divergir del store. En paralelo, `WorkoutRemote.send` sincroniza el store (TrainView aplica `adjustReps/adjustWeight` pero **ya no re-empuja** la Live Activity para reps/peso). Además `adjustReps/adjustWeight` usan **persistencia diferida** (`persistSoon()`, ~0,6 s) en vez de recodificar todo el estado en cada toque. (`LiveActivityManager.swift` se compila también en el target del widget para que el intent compartido encuentre el símbolo; en runtime se usa la instancia del proceso de la app.) El `ContentState` compartido se amplió con `reps`, `weight`, `setIndex`, `exerciseSets`. En iOS 16.2–16.x (sin botones interactivos) el widget degrada a solo lectura (muestra reps/peso/series como texto). Limitación conocida: los botones requieren que la app esté viva en segundo plano (flujo normal: empiezas el entreno y bloqueas el móvil); si la app se ha cerrado por completo, el sistema la relanza pero la sesión en memoria no se restaura.
>
> **Añadido tras Fase 1:** Plan con "Crear entrenamiento" (formulario de ejercicios) y sin tarjeta "Biblioteca; Ranking con scope "Amigos" por defecto (ranking real de tus amigos); Partner con "Cuándo" y "Dónde" en el creador y flecha atrás a la izquierda (en vez de X); foto de perfil seleccionable (PhotosPicker) y ajustable (arrastrar/pellizcar), tanto en Perfil como al crear cuenta (`Account.photoData/scale/offset`, `PhotoSupport.swift`).
>
> **Detalle del entreno (historial) — solo series HECHAS:** el detalle (`ActivityDetailView`) muestra únicamente las series completadas. Antes, un ejercicio saltado por completo aparecía con círculos verdes porque `saveSession` guardaba `SessionExercise.sets = series planeadas` cuando no había completadas; ahora **solo se añaden a `items` los ejercicios con `completedSets > 0`**, con `sets = completedSets` y `logs` = solo las series hechas (`setLog` nunca guarda las saltadas). `expandedSets` ya no fabrica círculos de más. Las series saltadas se siguen registrando en `history` (status `.skipped`) para las estadísticas, pero no se pintan como hechas.
>
> **Resumen del entreno (al guardar):** nombre editable (con default = nombre del entreno), campo "¿Qué tal te ha ido?" (notas) y foto opcional (PhotosPicker). Se **quitó el selector "¿Quién puede verlo?"** (Todos / Seguidores / Solo yo): no aportaba y se eliminó de la pantalla de resumen; internamente las sesiones se guardan con `visibility = .all` por defecto (el enum `WorkoutVisibility` se conserva para no romper datos antiguos). Se guarda como `WorkoutSession` (modelo nuevo, persistido en `store.sessions`) además del historial/XP. Pendiente: mostrar las sesiones propias en el muro Social.
>
> **Ubicación aproximada del entreno (GPS):** la localización que aparece en la tarjeta del entreno es ahora la **zona aproximada donde se hizo la actividad**, capturada por GPS, no la ciudad del perfil. Al empezar la sesión `TrainView` pide ubicación (`LocationManager`, `kCLLocationAccuracyHundredMeters`) y, al recibir coordenadas, hace **geocodificación inversa** (`CLGeocoder`, locale `es_ES`) a un nombre legible y aproximado tipo "barrio, ciudad" (p. ej. "Chamberí, Madrid") — sin calle ni número. Ese texto se guarda en `WorkoutSession.location` (campo nuevo, opcional) al guardar el entreno y se muestra con el pin en la tarjeta del feed (`SocialFeedView.myItems`) y en el detalle (`ActivityView.activityData` → `ActivityDetailView`). Para sesiones antiguas sin ubicación capturada se cae con elegancia en la ciudad del perfil. Permiso reutilizado: `NSLocationWhenInUseUsageDescription` (ya existía para ranking/compañeros). Las tarjetas de **otras** personas siguen mostrando su ciudad de perfil.
>
> **Entreno (flujo de sesion):** boton "Finalizar entrenamiento"; al terminar se muestra un RESUMEN tipo Strava (duracion, series, volumen, XP) con Guardar/Descartar (el historial/XP/racha se confirman solo al Guardar). Tras Guardar/Descartar se vuelve al estado de carga, que ahora muestra un único estado vacío limpio y centrado (icono mancuerna en círculo verde, "¿Qué entrenamos hoy?" + un solo botón primario "Elegir entreno") que cambia a la pestaña Plan (`onGoToPlan` → `tab = 1`). Se quitaron la lista "TUS MÁS FRECUENTES" y el botón "Otros entrenos".
>
> **Plan / entrenos (nativo):** crear entreno con formulario mejorado (tarjetas de ejercicio con steppers redondos, boton "Añadir ejercicio" con borde discontinuo). **Flujo de escritura ágil en `CreateWorkoutView`:** al crear un entreno nuevo el cursor empieza **directamente en el campo Nombre** (`@FocusState nameFocused`, auto-foco en `onAppear` solo si no se edita); pulsar **"Añadir ejercicio"** deja el cursor listo en el nuevo ejercicio (`focusedExercise = nuevoId`, sin tener que tocarlo); y en el campo de ejercicio, si escribes uno que NO está en el catálogo, el desplegable ofrece una fila **"Usar «X» · nuevo"** para añadirlo como personalizado de forma intuitiva (los nombres personalizados ya se guardaban; ahora se ve la opción). Grupos personalizados: cada entreno tiene `block` como grupo (chips sugeridos + grupo nuevo escribible); Plan agrupa por grupos. Editar entrenos (boton Editar en el preview → reabre el formulario; los built-in se editan creando copia, los tuyos se actualizan in situ). **Eliminar cualquier entreno** (también los de por defecto): botón "Eliminar entreno" SIEMPRE visible al entrar en el preview + opción "Eliminar" en el menú contextual (long-press) de la fila. La confirmación es ahora un **`.alert`** centrado que nombra el entreno ("Se quitará «X» de tu lista de entrenos"). `AppStore.deleteWorkout` borra los entrenos propios de `savedWorkouts` y **oculta los de por defecto** añadiéndolos a `hiddenWorkoutIds` (`Set<String>` persistido); `allWorkouts` filtra los ocultos, así desaparecen del Plan.
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
> **Navegación:** Perfil se movió de la tab bar al header (avatar arriba a la derecha junto a Mensajes/Notificaciones → abre ProfileView en sheet). Barra inferior PERSONALIZADA (`CustomTabBar`): orden **Social · Plan · Entreno · Comunidad · Actividad**, con **Entreno en el centro como botón especial** (círculo verde elevado). La navegación es un `ZStack` de 5 pantallas controlado por un único `@State tab` (no se pierde el estado de cada pestaña). Tags: Social=0, Plan=1, Entreno=2, Comunidad=3, Actividad=4 (onGoToPlan→1, onLoaded→2). **Comunidad** (`CommunityView`) fusiona Ranking + Partner de forma natural mediante un selector segmentado (Ranking / Partner) sin perder ninguna funcionalidad: ambas vistas (`RankingView`, `PartnerView`) viven en un ZStack y conservan su estado (scroll, mapa, ubicación) al cambiar de sección. **Actividad** (`ActivityView`) tiene dos secciones con selector segmentado: **Progreso** y **Actividades**. *Progreso* contiene: una tarjeta de **racha** horizontal de extremo a extremo (el número dentro de un icono de llama 🔥 + "¡En racha!" y subtítulo aclaratorio: la racha NO son días consecutivos, son entrenos encadenados sin pasar más de 3 días de descanso); la tarjeta de **Gym Score** (movida desde Comunidad: puntuación + tier + fiabilidad + barras de pilares Fuerza/Constancia/Progreso/Volumen/Calidad/Variedad); el **calendario mensual** (`TrainingCalendarView`) con todos los días del mes (huecos vacíos para los días del mes anterior/siguiente, NO se muestran días de otros meses), navegación de mes ‹ ›, días entrenados resaltados en verde, marca del día actual, badge si hay varios entrenos y contador del mes; al tocar un día entrenado se abre un pop-up (`DaySessionsSheet`) con los entrenos de ese día, y desde ahí el detalle (`ActivityDetailView`). Y las métricas de carga: (1) **Tendencia** — variación % del 1RM estimado medio entre el primer y el último registro, promediada entre ejercicios; (2) **Fuerza por ejercicio** — 1RM estimado por ejercicio con fórmula de Epley `w·(1+reps/30)` tomando la mejor serie de cada sesión, con delta vs primer registro y mini-sparkline (Swift Charts); incluye un botón de información (ⓘ gris) que explica en un alert qué es el 1RM estimado y la fórmula de Epley. *Actividades* contiene **solo** el histórico: la lista de tus sesiones (`store.sessions`) ordenadas por fecha; tap → `ActivityDetailView`. **Perfil** se movió al margen superior IZQUIERDO del header (avatar a la izquierda del título; Mensajes/Notificaciones quedan a la derecha). **Racha (`currentStreak`)**: es una racha "de gimnasio", no exige entrenar a diario; se mantiene mientras no pasen más de 3 días entre entrenos (y el último sea de los últimos 3 días). Cada día entrenado dentro de esa ventana de 3 días suma +1; si se superan los 3 días sin entrenar, la racha se reinicia a 0. Pestaña **Social** (`SocialFeedView`) con selector de cápsulas **Seguidos / Para ti** (ZStack, conserva estado). **Seguidos**: usuario nuevo (sin seguidos) = bienvenida "Hola, {nombre} 👋" + **tira horizontal deslizable de sugerencias** ("A QUIÉN SEGUIR", tarjetas estilo Strava: avatar/nombre/@usuario/Seguir, **sin mostrar distancia**) + debajo un feed con tus posts + posts de gente cercana que aún no sigues. Con seguidos = la tira de sugerencias (si hay) + feed con **solo** tus posts y los de quien sigues, por fecha. **El modo de layout (usuario-nuevo vs con-seguidos) se CONGELA en el snapshot del refresh** (`seguidosNewUser`): seguir a alguien desde la tira NO reorganiza el muro al instante (la tarjeta solo cambia a "Siguiendo"); las sugerencias solo "se bajan"/intercalan y el feed solo se reorganiza al hacer **pull-to-refresh**. Antes el layout dependía en vivo de `store.following.isEmpty`, así que al seguir 1-2 desaparecían inmediatamente — corregido. **Para ti** = **solo POSTS** de gente cercana que no sigues (descubrimiento, máx 2/persona, ~12, con botón "Seguir" en línea); ya no muestra listas de recomendación de amistad. El orden de cercanía es determinista (Social no pide ubicación). El **mapa de Comunidad** se carga bajo demanda (botón "Ver mapa") para no pedir permiso de ubicación al arrancar. Seguir es inmediato (`store.follow`, == amigo) con toast "Ahora sigues a {nombre}". Cada post: avatar, nombre, hora, ubicación, título, nota, foto, métricas (Tiempo/Series/Ejerc. — se eliminó "kg vol." de todas las tarjetas y del detalle por ser un número grande poco útil; el pilar "Volumen" del Gym Score 0–100 se mantiene) y fila de acciones **estilo Instagram** (sin fondo/cápsula, no verde): **like** (corazón, se pone rojo al pulsar, contador; persistido en `store.appliedKudos`; iconos con trazo **más grueso** —`.semibold`, 22pt— para un aire más *cosy*, y al dar like el corazón hace **pop** + brota una pequeña **explosión de corazones** vía `LikeButton`/`HeartBurst` con háptica). **Ver a quién le gusta una publicación:** el **número** de likes es tocable y abre una hoja "Me gusta" con la lista de personas (tú primero si has dado like), igual que en los comentarios — el corazón da/quita like y el número abre la lista (`likesOfPost` + `postLikesSheet`/`postLikers`, deterministas por post). **Vista previa de comentarios estilo Instagram:** si una publicación tiene comentarios, justo debajo de la fila de acciones se muestra "Ver los N comentarios" (solo si hay más de los previsualizados) y hasta **2 comentarios recientes** en formato `**nombre** texto` (una línea, `lineLimit(1)`); tocar cualquiera abre la `CommentsSheet` completa. Helpers en `SocialFeedView`: `commentPreview` (vista), `previewComments` (2 de nivel superior ordenados por fecha desc.), `commentList`/`commentTotal` (deterministas por id), `openComments`. En la lista de "Me gusta" (de posts y de comentarios) cada fila es **tocable y abre el perfil**, se puede **hacer scroll** para verlos todos, muestra el **Gym Score** en cada cara y **se quitó el corazón** de la derecha (ahora un chevron).
>
> **Badge de Gym Score en TODOS los avatares (sustituye la banderita):** todos los avatares de perfil de la app (feed, "Para ti", perfiles propio y de amigo, sugerencias, listas de "Me gusta", amigos, notificaciones, ranking, detalle de entreno) muestran el **Gym Score en la esquina inferior derecha** en una cápsula verde, en lugar de la antigua **banderita del país** (eliminada de los avatares). Componentes compartidos `ScoreBadge` / `ScoredAvatar` (Components.swift); el score se obtiene de `store.personScore(id)` (cacheado, determinista para los demo) o `store.gymScore.total` para "mí"; `ActivityData` lleva un campo `score` para el autor del detalle. Ver memoria del proyecto.
>
> **Gamificación: divisiones Hierro → Maestro (`ScoreTier`):** 7 divisiones por Gym Score — **Hierro** (<15), **Bronce** (15–29), **Plata** (30–44), **Oro** (45–59), **Platino** (60–74), **Diamante** (75–89), **Maestro** (≥90). El **prestigio se lee a simple vista**: las bajas son apagadas/grises y SIN brillo; conforme suben, el color es más vivo y el badge **brilla más** (halo/`shadow` que crece con la división), culminando en Maestro (gradiente violeta→cian vívido + corona + glow fuerte). Cada una tiene degradado metálico e icono (escudo → roseta → diamante → corona). El color/brillo tiñe el badge del Gym Score en TODOS los avatares (incluida **mi foto del header**, que ahora usa `ScoreBadge` con color de división en vez del verde plano). La tarjeta de **Gym Score** (Actividad ▸ Progreso) muestra la división como chip con su color. La puntuación "en línea" (sin avatar) se muestra con su división mediante el componente compartido **`ScorePill`** (Components.swift): cápsula con gradiente metálico de la división + icono de tier + glow que crece con el nivel. Se usa en el **Ranking** (`RankingView.rankRow` — la puntuación de cada fila ya no es texto plano; se quitó también la banderita que quedaba en el avatar de la fila) y en **Partner** (`PartnerView.planCard` — la puntuación de quien ofrece el plan, **y la de tu propio plan**, va con su rango: Bronce/Oro/Diamante/Maestro de un vistazo, sustituyendo el antiguo `Tag` verde plano "Score X"). Solo visual — `ScoreTier`/`ScoreBadge`/`ScorePill` en Components.swift., **comentario** (icono `bubble.right` con nº de comentarios) y **compartir** (avión de papel `paperplane` con nº de veces compartido). **Comentarios estilo Instagram** (`CommentsSheet`): cada comentario muestra autor, texto, antigüedad ("hace …" vía `relativeTime`), botón de **like** por comentario y **Responder** (respuestas anidadas 1 nivel); caja de composición con "Respondiendo a {nombre}"; comentarios demo deterministas por post para que el muro se sienta vivo. El **avatar de cada comentario lleva su Gym Score** (badge de división, como el resto de la plataforma) y es **tocable para abrir el perfil** de esa persona (`avatar`→`openAuthor`→`profileTarget`→`FriendProfileView`, mismo patrón que la lista de "Me gusta"). Para ello `PostComment` lleva un `personId` (los comentarios demo guardan el id del autor; las respuestas, el del dueño del post; tus comentarios, nil → no navegable); el score sale de `store.personScore(personId)` (o `store.gymScore.total` si eres tú). Los **pop-ups (sheets)** ya no llevan botón "Cerrar": se cierran deslizando hacia abajo (gesto nativo de iOS); el chat (fullScreenCover) mantiene su flecha de volver. **`MessagesSheet`** (Amigos/Mensajes) **no tiene título de navegación** ("Mensajes" arriba se quitó por redundante: el selector segmentado Amigos/Mensajes ya etiqueta la pantalla). En **Amigos**, las secciones "Solicitudes recibidas", "Tus amigos" y **"Descubre compañeros"** **solo aparecen si tienen contenido** (no se muestra el placeholder "Sin solicitudes…", "Aún no tienes amigos…" ni "Ya estás conectado con todos." cuando están vacías; si ya sigues a todo el mundo, la sección de descubrimiento simplemente no aparece). `seedDemo` arranca SIN seguidos (Mika pasa a recomendación, Leo a solicitud entrante) para mostrar la experiencia de usuario nuevo. Tap en un post → detalle; tap en una persona → su perfil. Ranking → mapa con usuarios demo cerca de tu ubicación, pin tocable → ficha (`MapUserSheet`) con perfil y añadir amigo.
>
> **Perfil:** selector de idioma (🌐, solo Español activo); edad por FECHA DE NACIMIENTO (DatePicker) con edad calculada; país (lista del sistema en español) y ciudad (búsqueda MapKit sesgada al país). Catálogo de ejercicios con autocompletado en crear/editar entreno (`Exercises.swift`); grupos personalizados con desplegable y "Crear «X»".
>
> **Tarjetas de entreno unificadas (sistema compartido):** antes había 5 layouts de tarjeta duplicados + 4 estilos de fila de stats distintos. Se unificaron en componentes compartidos en `Components.swift`, reutilizados en el feed Social, "Para ti", histórico de Actividad, perfiles (propio y de amigo) y el pop-up del calendario: (1) **`WorkoutTypeBadge`** — tile redondeado **neutro** (`Brand.chip` con la mancuerna en gris `Brand.soft`) que sustituye la mancuerna verde suelta; discreto a propósito (el verde llamativo se descartó por petición del usuario), tamaños `.full`/`.compact`; (2) **`WorkoutStatStrip`** — UNA franja de stats con un solo fondo `Brand.surface` y separadores finos (hairlines), nada de píldoras sueltas; números `monospacedDigit` + `design: .rounded` para que no "bailen"; `.full` (feed: micro-iconos, más alta) y `.compact` (filas de histórico: sin iconos, más baja); su builder `metrics(time:sets:exercises:ppm:)` es la **única fuente** de las métricas (Tiempo/Series/Ejerc./ppm — nunca volumen ni XP); (3) **`WorkoutPhoto`** — bloque de foto uniforme (esquinas redondeadas + hairline). La tarjeta **full** (feed) lleva además una línea divisoria fina entre la cabecera de autor y el contenido, y el título subió a 18pt. Diseño elegido con un workflow (3 direcciones → síntesis con crítica de "buen gusto") y verificado con harness + screenshots.
>
> **Pendiente de portar/afinar:** gesto de swipe opcional del deck, edicion inline de peso/reps durante la sesion, compartir entrenos, calendario de progreso.
>
> **Autenticación (login real activado, listo para publicar):** la app arranca en `AuthView` con tres vías: **Sign in with Apple** (nativo, `AuthenticationServices` + entitlement `com.apple.developer.applesignin`, funciona ya), **Continuar con Google** (SDK oficial `GoogleSignIn-iOS` vía SPM) con **bienvenida estilo Strava**: la pantalla inicial ofrece **«Unirme gratis»** (primario) e **«Iniciar sesión»** (secundario); cada una abre `AuthProviderSheet` (hoja media) con Apple / Google / email titulada según el modo («Únete a Forge Loop» / «Bienvenido de nuevo»). El email abre `EmailAuthSheet` ya en el modo elegido (crear/entrar), con enlace para cambiar. **Email por CÓDIGO (OTP) — ACTIVO:** con el SMTP de **Resend** configurado en Supabase (host smtp.resend.com:587, sender onboarding@resend.dev «Forge Loop»; la API key vive SOLO en la config del servidor, nunca en el repo), las plantillas de confirmación y magic link llevan `{{ .Token }}` (código de 6 dígitos, asunto «{{ .Token }} es tu código de Forge Loop»), `mailer_autoconfirm` OFF y `mailer_otp_length` 6. El flujo de email es **sin contraseña**: paso 1 correo → `Backend.sendEmailCode(email, createIfNeeded:)` (registro crea cuenta; inicio de sesión NO — correo desconocido da error en vez de cuenta nueva) → paso 2 **casillas de 6 dígitos** (TextField oculto + `oneTimeCode` para autorrelleno desde el email, verificación automática al 6º dígito, «Reenviar» con cuenta atrás de 30 s, «Cambiar correo») → `Backend.verifyEmailCode` (`verifyOTP(type: .email)`) abre sesión + hydrate + sync. Los métodos de contraseña (`signInEmail`/`signUpEmail`) se eliminaron. Probado en vivo: OTP 200 al correo del usuario y a terceros vía Resend. Ojo producción: verificar un dominio propio en Resend para remitente propio y entregabilidad para que siempre quede claro si entras o te registras: `Backend.signInEmail` (falla con credenciales incorrectas → «Correo o contraseña incorrectos») y `Backend.signUpEmail` (si el correo ya existe, GoTrue devuelve usuario sin sesión → `BackendError.emailTaken` → «Ya existe una cuenta con este correo»); «¿Olvidaste la contraseña?» solo en modo login. Sin backend todavía: la identidad del proveedor se guarda en local (`store.signIn(provider:userId:email:name:)` → `Auth`) y el **onboarding** monta el perfil. Cuando llegue el backend (Supabase), estos mismos proveedores le pasan el `idToken` para crear el usuario real.
> - **Activar Google (lo único pendiente, ≈5 min, requiere cuenta Google Cloud):** crear un **OAuth Client ID de iOS** en https://console.cloud.google.com/apis/credentials (Bundle ID `com.javiercolroma.gymswipeios`), pegar el **client ID** en `ios/GymSwipeIOS/AuthConfig.swift` (`GoogleAuth.clientID`) y el **esquema de URL de iOS** (client ID al revés, `com.googleusercontent.apps.…`) en `ios/project.yml` sustituyendo el marcador `GOOGLE_REVERSED_CLIENT_ID`; luego `npm run ios:generate`. Mientras `clientID` esté vacío, `GoogleAuth.isConfigured == false` y el botón muestra una ayuda en vez de fallar (Apple/email funcionan igual). El callback de OAuth se enruta con `.onOpenURL { GIDSignIn.sharedInstance.handle($0) }` en `GymSwipeIOSApp`. Instrucciones completas dentro de `AuthConfig.swift`.
> - **Ship-blockers resueltos:** `AppStore.debugSkipAuthOnboarding` ahora es **`false`** (la app pasa por login → onboarding; el flag y su cuenta "Debug" en memoria siguen ahí por si hace falta depurar sin login, poniéndolo a `true`). Se revirtió el `testRestSeconds = 10` de pruebas en `TrainView`: el descanso vuelve a usar `ex.rest` (2 min por defecto).
>
> **Backend (Supabase) — construido y VALIDADO end-to-end; proyecto `xdczilodphmejbzvfdye`:** migraciones `0001`–`0003` aplicadas (tablas + RLS + buckets + trigger anti-trampas + RPC de ranking). Validado con usuarios reales de prueba por API: **email/contraseña** real (`mailer_autoconfirm` ON para bring-up), **sesiones** al servidor (Fase 2), **grafo social + feed** por RLS (Fase 3), **ranking real** por XP semanal (Fase 4, RPC `weekly_xp_leaderboard`), **anti-trampas v2** (Fase 6, trigger `recompute_verified` — el server recalcula `verified`), **storage** de avatar/foto de entreno con RLS por carpeta (Fase 5). **Apple** cableado (falta prueba interactiva con Apple ID real); **Google** cableado (falta el iOS OAuth Client ID, paso del usuario). **UI ya enchufada a datos reales** (feed particionado, ranking/liga, perfiles, chat con Realtime, likes/comentarios, moderación reportar/bloquear). **Pulido social reciente:** (1) *follow fantasma* corregido — para usuarios reales (id UUID) `relationship()` deriva SOLO del estado del servidor (`followingPeople`/`pendingFollowingIds`), nunca del diccionario demo `relationships` que persiste en el dispositivo y contaminaba a la siguiente cuenta; `followOrRequest` escribe follow/unfollow REAL en Supabase (pending si la cuenta es privada) con estado optimista; y `logout()` hace **borrado completo** del estado local del usuario (follows, chats, monedas, logros, racha, historial…) para que nada se filtre entre cuentas. (2) **Feed particionado**: *Seguidos* = tus posts + de a quien sigues (+ locales sin sincronizar); si no sigues a nadie, modo usuario nuevo (tuyos + descubrimiento con la tira **"A quién seguir"** de usuarios reales recientes, `fetchSuggestedProfiles`); el resto de posts públicos van a *Para ti* con botón Seguir. (3) **Logros**: tras `syncSessionsFromBackend` se recalcula la racha y se ejecuta `refreshAchievements(celebrate: false)` — antes un logro cumplido con sesiones del servidor (p. ej. Tonelaje) se quedaba con candado; la racha (`currentStreak`) cuenta también los días de `sessions` (sincronizadas), no solo `history` (local), y el logro de foto acepta `photoURL` remota. `SocialPerson`/`ScoredAvatar` llevan `avatarURL` (foto real con fallback a emoji). El backend elegido es **Supabase** (auth Apple/Google, Postgres para ranking/liga reales, realtime para chat, storage para fotos). **Todo el lado iOS está gateado por `BackendConfig`**: mientras `supabaseURL`/`supabaseAnonKey` estén vacíos, `Backend.shared.isConfigured == false`, `client == nil` y la app funciona 100% en local (UserDefaults) sin tocar la red. En cuanto se rellenen, empieza a usar Supabase. Piezas ya en el repo:
> - **Esquema SQL** (`backend/supabase/migrations/`): `0001_init.sql` (tablas `profiles`, `follows`, `workout_sessions` con `items` en JSONB, `player_stats` para ranking/liga, `kudos`, `comments` + **RLS** completo + triggers `updated_at`) y `0002_storage.sql` (buckets `avatars`/`session-photos` + políticas por carpeta `<uid>/…`). Se pegan en el SQL Editor de Supabase.
> - **SDK iOS** (`supabase-swift` vía SPM) + `Backend.swift` (singleton `@MainActor`, `client` lazy solo si está configurado) con **auth por ID token nativo**: `signInWithApple(idToken:nonce:)` (nonce SHA256 a Apple + crudo a Supabase, `AuthNonce`), `signInWithGoogle(idToken:)`, `upsertProfile(_:)`, `signOut()`. `AuthView` captura el `identityToken`/nonce de Apple y el `idToken` de Google y abre la sesión Supabase **best-effort** (si no hay backend, sigue el flujo local intacto). `AppStore.saveAccount` hace `upsert` del perfil (`syncProfileToBackend`) y `logout` cierra sesión también en Supabase.
> - **Guía de puesta en marcha**: `backend/README.md` (crear proyecto, pegar URL+anon key en `BackendConfig.swift`, ejecutar migraciones, activar Apple/Google en Authentication → Providers con los *Authorized Client IDs*) + roadmap de migración local→servidor (Fase 2 sesiones · 3 follows/feed · 4 ranking/liga reales · 5 storage/realtime · 6 anti-trampas v2 con timestamps de servidor).
> - **Nota de build (entorno):** la caché SPM global de este entorno falla al hacer checkout de `swift-crypto`; se compila con `-clonedSourcePackagesDirPath ios/.spm-cache` (carpeta gitignorada). En una máquina normal no hace falta ese flag.
>
> **Gamificación — Fase 1: Nivel + Monedas + Logros (`Gamification.swift`):** el perfil (`MeProfileView`) muestra una **tarjeta de gamificación** con el **Nivel** del jugador (curva `getLevelProgress(player.xp)`), barra de XP, **monedas** 🪙 (`store.coins`) y un acceso a **Logros** (`X/total`). `LogrosView` es una cuadrícula de **medallas** con estados conseguido (círculo con degradado de su tier bronce/plata/oro/diamante + icono + recompensa en monedas) o bloqueado (candado gris + barra de progreso para los de conteo). Catálogo `Achievements.all` (~15 logros: primer entreno, 10/50/100 entrenos, racha 7/30, división Oro/Diamante/Maestro, 10k/100k kg de volumen, foto, madrugador, búho, seguir a alguien) con un `value: @MainActor (AppStore) -> Int` que calcula el progreso desde el estado real. `AppStore.refreshAchievements(celebrate:)` desbloquea los cumplidos, suma sus monedas y encola los nuevos en `store.celebrations`. **Solo celebra en acciones explícitas**: al **guardar un entreno** (`saveSession`) y al **seguir a alguien** (`followOrRequest`, si no estás entrenando). Todo lo que corre en **cada apertura** (arranque, `syncSessionsFromBackend`, `loadFollowing`) hace **backfill SILENCIOSO** (`celebrate: false`) — si `loadFollowing` celebrara, el pop-up de "Sociable" saldría en cada arranque. Al desbloquear, `RootView` muestra `AchievementCelebration` (overlay con confeti + icono del tier + "+N monedas"). Persistido: `coins`, `unlockedAchievements`.
>
> **Gamificación — Fase 2: Récords personales (PRs):** al guardar un entreno, `AppStore.detectPRs` calcula el mejor **1RM estimado** (Epley `w·(1+min(20,reps)/30)`) por ejercicio a partir de las series completadas; guarda el mejor de cada ejercicio en `personalBests: [String: PersonalBest]` y **celebra** con `PRCelebration` (confeti + copa + "kg × reps" + 1RM) solo cuando **supera un récord anterior** (la primera vez lo registra en silencio). `prCount` cuenta los récords batidos (para logros `pr1`/`pr10`). La tarjeta **"Tus récords"** (`RecordsCard`, en Actividad ▸ Progreso) lista tus mejores marcas por ejercicio ordenadas por 1RM. Persistido: `personalBests`, `prCount`.
>
> **Gamificación — Fase 3: Misiones semanales (pulidas a nivel producto):** tarjeta **"Misiones de la semana"** (`WeeklyQuestsCard`, en Actividad ▸ Progreso) con 3 misiones que se **reinician cada semana** (su progreso se calcula de las sesiones de la semana ISO actual, `weekSessions()`): "Entrena 3 días", "Completa 40 series", "Acumula 90 minutos". Cada una tiene barra de progreso y, al completarse, un botón **Reclamar** que da **monedas + XP** (`claimQuest` → `coins += q.reward; player.xp += q.xpReward`) — una vez reclamada muestra ✓. Se evita re-reclamar con `claimedQuests` (`Set` de `"semanaISO:idMision"`, persistido). `WeeklyQuest.progress` es un `@MainActor (AppStore) -> Int`. **Mejoras de producto (para que las recompensas "salgan donde tienen que salir"):** (1) **recompensas escalonadas** — cada misión tiene su propio `reward`/`xpReward` según esfuerzo (días 🪙50+30XP · series 🪙80+50XP · minutos 🪙100+60XP), no un premio plano; (2) **reset comunicado** — la cabecera de la tarjeta muestra "Nuevas el lunes · Xd" (`store.leagueDaysLeft`) para que se entienda que caducan; (3) **celebración al completar** — al **guardar** un entreno que cierra una misión (no reclamada), se detecta comparando el estado antes/después (`questsBefore` en `saveSession`) y se encola en `store.questCompleted`; `RootView` muestra `QuestCompleteCelebration` (overlay con confeti + icono de la misión + "🪙 X · Y XP" + botón "Reclamar recompensa"/"Ahora no", zIndex 8 en la cadena de celebraciones); (4) **flourish al reclamar** — el botón lanza un "+🪙X" flotante (~1 s) al pulsar; (5) **accesibilidad** — la barra lleva `accessibilityValue` y el botón `accessibilityLabel` con monedas+XP. **Bugs corregidos:** `weekSessions()`/`weekXP()` ahora comparan por `weekIdFor(date)` completo (año+semana ISO), no solo el número de semana → sin colisión entre años; y `claimedQuests` se **poda** en `init` a solo las claves de la semana actual (`filter { $0.hasPrefix("\(weekId):") }`) para que no crezca sin límite.
>
> **Gamificación — Fase 4: Racha (hitos + congelador):** al guardar, `checkStreakMilestones` detecta hitos de racha (7/14/30/60/100) no celebrados, suma monedas (`racha·3`) y, en 7 y 30, regala un **congelador**; celebra con `StreakCelebration` (llama naranja + confeti). Los **congeladores** (`streakFreezes`) protegen la racha: `applyStreakFreeze` (en `saveSession`) consume congeladores para marcar días "protegidos" (`shieldedDays`) que **puentean un hueco** de más de 3 días, y `currentStreak()` cuenta esos días protegidos como entrenados. La tarjeta de **racha** (Actividad ▸ Progreso) muestra 🧊 con el nº de congeladores. Persistido: `streakFreezes`, `shieldedDays`, `streakMilestones`.
>
> **Gamificación — Fase 5: Ligas semanales (ascenso/descenso):** liga estilo Duolingo. Tarjeta **`LeagueCard`** (**Comunidad ▸ Ranking**, como hero arriba — antes estaba en Actividad; ver la nota "Comunidad vs Actividad" más abajo: liga actual + tu puesto + días restantes) que abre **`LeagueView`** con la **clasificación** de la semana: 14 rivales **deterministas** por semana+liga (`League.bots(weekId:tier:)`, XP que escala con la liga) + **tú**, ordenados por **XP semanal** (`weekXP()` = suma del XP de tus sesiones de la semana ISO). Los **3 primeros** ascienden (flecha verde ↑) y los **3 últimos** descienden (flecha roja ↓); tu fila va resaltada. 7 ligas: Bronce → Plata → Oro → Platino → Diamante → Maestro → Leyenda. Al **cambiar de semana** (`resolveLeagueIfNeeded`, en `init`), se resuelve la semana anterior por posición y se sube/baja de `leagueTier`; al ascender se celebra con `LeaguePromotionCelebration`. Reinicia el lunes (`leagueDaysLeft`). Persistido: `leagueTier`, `leagueWeekId`.
>
> **Gamificación — Fase 6: Tienda de cosméticos + Títulos + Forgey (`Shop.swift`):** desde la tarjeta de gamificación del perfil se abre la **Tienda** (`ShopView`) y los **Títulos** (`TitlesView`). La **Tienda** gasta monedas en: **accesorios de Forgey** (corona, gorro, auriculares, aureola — se dibujan sobre la mascota `Mascot`, con **vista previa** en vivo de Forgey con el accesorio equipado), **marcos de avatar** (`AvatarFrame`, aro de color que rodea tu avatar — se ve en la cabecera del perfil) y **congeladores** de racha (consumible). Comprar/equipar con `buyCosmetic`/`equipFrame`/`equipForgey`; estado en `ownedCosmetics`, `equippedFrame`, `equippedForgey`. Los **Títulos** (`Titles.all`: Novato, Constante, Bestia constante, Rompe-récords, Rey de la pierna, Maestro del hierro, Leyenda) **se ganan** (condición sobre el estado real, no se compran) y el equipado (`equippedTitle`) se muestra como chip morado bajo tu nombre. El `Mascot` acepta un `accessory` y `getLevelProgress` ya daba el nivel; con esto Forgey "evoluciona" al equipar accesorios. Con esto se completan las 6 fases de gamificación (todo lo pedido salvo el bloque social-competitivo). Persistido: `ownedCosmetics`, `equippedFrame`, `equippedForgey`, `equippedTitle`.
>
> **Comunidad vs Actividad (reorganización para que todo tenga sentido):** antes había **dos** superficies de clasificación con **rosters distintos** que confundían: un *Ranking* en **Comunidad** (por Gym Score, con ámbitos inventados Global/País/Ciudad/Zona = gente ficticia tipo Mika/Leo con offsets) y una *Liga* en **Actividad** (por XP semanal, con bots tipo Aria/Bruno). Se ha separado por **eje de producto**: **Comunidad = competición/social (hacia fuera)**, **Actividad = tu progreso personal (hacia dentro)**.
> - **Comunidad ▸ Ranking** (`RankingView`) ahora es coherente: (1) **Liga semanal** como *hero* card arriba (movida desde Actividad; `LeagueCard` → `LeagueView`, competición por XP con ascenso/descenso — el "ranking contra desconocidos" vive aquí); (2) **Ranking de amigos** por Gym Score, **solo datos reales** de quien sigues (se **eliminaron los ámbitos inventados** Global/País/Ciudad/Zona y su selector de iconos — eran la fuente del "salen personas distintas"; el `rankingRows` fabricado desaparece, queda `friendsRanking`); (3) **Mapa** de la comunidad. Empty state honesto: "Sigue a más gente para comparar vuestro Gym Score."
> - **Actividad ▸ Progreso** (`ActivityView`) se reordena de arriba a abajo con **cabeceras de grupo** (un nivel por encima de los títulos internos de cada tarjeta, para que se lea como secciones y no como una pila): **RESUMEN** (Racha + Gym Score) → **ESTA SEMANA** (Misiones) → **RÉCORDS Y PROGRESO** (Récords + Tendencia + Fuerza por ejercicio) → **HISTORIAL** (calendario mensual). Se **quitó la `LeagueCard`** de aquí (ahora en Comunidad), así Actividad no compara con nadie: es solo tuyo. Helper `sectionHeader(_:)` en `ActivityView`.
>
> **Anti-trampas v1 (entrenos "fakeados"):** al gamificar surge el incentivo de **falsear entrenos** (pulsar "Hecho" en todas las series a toda velocidad, desde la app o desde el widget de la Live Activity, para farmear XP → ligas, récords, racha y volumen). Como todavía **no hay backend**, se añade un **disuasor client-side** honesto (no es un muro; el arreglo definitivo es validación en servidor). Mecánica: `WorkoutSession` gana `var verified: Bool = true` (por defecto `true`, así los entrenos antiguos siguen contando). Al guardar (`saveSession`) se calcula una **heurística de plausibilidad** con el tiempo real transcurrido y el volumen del entreno:
> ```swift
> let verified = elapsed >= totalSets * 20 && totalSets <= 60 && gained <= 600
> ```
> es decir: al menos **~20 s por serie** de duración real, un tope de **60 series** y un tope de **600 kg** de volumen ganado por sesión (números absurdos = probable fake). Filosofía **"gate vs lenient"** para no castigar al usuario honesto: lo que **SÓLO cuenta si `verified`** son las **superficies competitivas** públicas → el **XP de la liga** (`weekXP` filtra `$0.verified`) y los **récords públicos / PR celebrados** (`detectPRs(_,verified:)` sólo celebra y suma `prCount` si `verified`; el `personalBests` interno se actualiza siempre para no perder tu historial). Lo que sigue contando **siempre** (seguimiento personal, no competitivo): `player.xp`/nivel, racha, monedas, historial, logros y **progreso de misiones**. **Refuerzos en origen:** los steppers de reps/peso ahora tienen **topes realistas** (`adjustReps` ≤ 50, `adjustWeight` ≤ 500 kg) para matar de raíz el exploit de "PR absurdo". **UX honesta:** nunca se **bloquea** el guardado; si sale no verificado, un **toast discreto** (`store.flashMessage`, capsula oscura abajo ~3,2 s) avisa "Entreno guardado. Por ser muy rápido, no cuenta para la liga ni para récords."; y las tarjetas de sesión no verificada muestran un **icono escudo tachado** (`shield.slash`) en el feed/perfil. **Límite honesto (documentado para el usuario):** al ser client-side, un usuario avanzado podría sortearlo; la solución **autoritativa** llegará con el backend (el servidor sella el timestamp de cada serie al recibirla y recalcula `verified` de forma no manipulable). Archivos tocados: `Models.swift` (flag), `AppStore.swift` (heurística + `questCompleted`/`flashMessage` + gating de `detectPRs` + topes de steppers), `Gamification.swift` (`weekXP` filtra verificados), `RootView.swift` (toast), `SocialViews.swift` (escudo tachado).
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
