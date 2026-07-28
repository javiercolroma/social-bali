# Forge Loop — material para App Store Connect

Todo lo que hay que rellenar en App Store Connect, ya redactado. Copia y pega.

## Datos básicos
- **Nombre (App Name):** Forge Loop
- **Subtítulo (Subtitle, máx. 30):** Entrena, registra y compite
- **Categoría principal:** Salud y forma física (Health & Fitness)
- **Categoría secundaria:** Deporte (opcional)
- **Bundle ID:** `com.javiercolroma.gymswipeios`
- **SKU:** `forgeloop-001`
- **Idioma principal:** Español (España)
- **Versión:** 1.0 · **Build:** 1
- **Precio:** Gratis

## URLs (GitHub Pages en el repo PÚBLICO `forgeloop-legal`)
- **Política de privacidad:** https://javiercolroma.github.io/forgeloop-legal/privacy.html
- **Soporte (Support URL):** https://javiercolroma.github.io/forgeloop-legal/support.html
- **Marketing URL (opcional):** https://javiercolroma.github.io/forgeloop-legal/

> Viven en un repo **aparte y público** (`javiercolroma/forgeloop-legal`) porque `gym-swipe-ios` es privado y GitHub Pages en repos privados exige plan de pago. El contenido sale de `docs/` de este repo; **si tocas `docs/`, hay que volver a empujarlo allí**. Activar: repo `forgeloop-legal` → Settings → Pages → Source `Deploy from a branch` → `main` / `(root)` → Save.

## Texto promocional (Promotional Text, máx. 170)
Planifica tus entrenos, registra series con swipes y mide tu Gym Score. Compite en ligas semanales y sigue el progreso de tus amigos.

## Descripción (Description)
Forge Loop es tu compañero de gimnasio directo y sin fricción. Planifica entrenamientos, registra cada serie con un gesto y sigue tu progreso real con un Gym Score exigente.

Qué puedes hacer:
• Entrena con tarjetas: marca series hechas o saltadas deslizando.
• Crea y guarda tus rutinas, o usa plantillas listas.
• Mide tu Gym Score (fuerza, constancia, progreso, volumen, calidad y variedad). Es exigente: necesita 3 semanas de uso para ser fiable.
• Sigue tu nivel, tu racha y tus récords.
• Ranking con mapa para ver tu zona.
• Apartado Partner para encontrar compañeros de entreno.
• Sigue a tus amigos, comenta sus entrenos y compite en ligas semanales.

Tu cuenta y tus entrenos se sincronizan de forma segura, así que no pierdes nada al cambiar de móvil. Sin anuncios y sin rastreo publicitario: nunca compartimos tus datos con terceros con fines de marketing.

## Palabras clave (Keywords, máx. 100 caracteres, separadas por comas)
gimnasio,entreno,rutina,fuerza,pesas,fitness,workout,progreso,gym,musculacion,ranking,entrenamiento

## Clasificación por edad
- Apta para 4+ (no contiene contenido sensible). Responde "Ninguno/No" a todas las categorías del cuestionario.

## App Privacy (etiquetas de privacidad en App Store Connect)

> ⚠️ Reescrito el 2026-07-28. La versión anterior decía «no recopilo datos», cierto en la época local-first y **FALSO** desde que Supabase está en vivo. Declarar de menos aquí es motivo de rechazo y de retirada posterior.

- **¿Recopilas datos?** **Sí.** Todo va a Supabase y está **vinculado a la identidad** del usuario (`user_id`):
  - **Datos de contacto:** correo (auth), nombre y @usuario.
  - **Contenido de usuario:** foto de perfil, fotos de entreno, notas, mensajes, comentarios.
  - **Identificadores:** `user_id`, token de notificaciones (`device_tokens`).
  - **Salud y forma física:** entrenos, series, volumen, y **frecuencia cardíaca** (`avg_hr`/`max_hr`, leída de HealthKit y guardada en `workout_sessions`).
  - **Ubicación aproximada:** `geo_cell_lat`/`geo_cell_lon` en `profiles` (`Backend.updatePresence`), redondeada a celdas de 0,05° (~5 km) para el Ranking y Partner. **Sale del dispositivo** — no se puede declarar como on-device.
  - **Datos opcionales del perfil:** sexo, fecha de nacimiento, país, ciudad, gimnasio, redes sociales.
- **Tracking:** No. No hay SDKs de publicidad ni se comparten datos con terceros para marketing.
- **Finalidad:** funcionalidad de la app (todo). Nada de publicidad ni analítica de terceros.
- ⚠️ **`PrivacyInfo.xcprivacy` sigue declarando `NSPrivacyCollectedDataTypes: []`** (= no recopilo nada). **Hay que actualizarlo antes de enviar a revisión** para que cuadre con lo de arriba; hoy se contradicen.

## Notas para el revisor (App Review Information → Notes)

> ⚠️ Reescrito el 2026-07-28: lo anterior describía la app envuelta en WKWebView y con lo social simulado. Las dos cosas son falsas desde la migración a SwiftUI nativo y la llegada del backend.

Forge Loop es una app nativa de SwiftUI para registrar entrenamientos de gimnasio y compartir el progreso.

Requiere cuenta: se puede entrar con Sign in with Apple, Google o un código de un solo uso enviado por correo. El backend es Supabase y las funciones sociales son **reales** entre usuarios (seguir, feed, comentarios, mensajes, ranking).

Contenido generado por usuarios: hay bloqueo de usuarios, denuncia de contenido y política de tolerancia cero (tablas `blocks` y `reports`).

La ubicación es opcional y se usa para el Ranking y para encontrar compañeros de entreno cerca; se envía **redondeada a ~5 km**, nunca la posición exacta.

La frecuencia cardíaca se lee de HealthKit **solo con permiso** y únicamente para adjuntarla al entreno. La app **no escribe** nada en Salud.

Se puede **eliminar la cuenta desde la propia app** (Perfil → Ajustes → Eliminar cuenta), que borra los datos del servidor.

⚠️ **PENDIENTE: crear una cuenta de prueba y ponerla aquí.** Al haber login, Apple **exige** credenciales de demo. Como el acceso por correo es con código de un solo uso, hay que darles o bien un buzón al que puedan acceder, o bien un usuario con contraseña fija habilitado para la revisión.

## Capturas (Screenshots) — pendiente
Apple exige al menos el tamaño de iPhone 6.9" (1320×2868). Recomendado capturar 3–6:
1. Pantalla de entreno (tarjeta + "Iniciar entreno").
2. Gym Score con desglose.
3. Plan / biblioteca de entrenos.
4. Ranking con mapa.
5. Mensajes o perfil de amigo.

Generar desde el simulador iPhone 16 Pro Max / 17 Pro Max:
```
xcrun simctl io booted screenshot captura-1.png
```
