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

## URLs (publicar GitHub Pages desde la carpeta `/docs` de `main`)
- **Política de privacidad:** https://javiercolroma.github.io/gym-swipe-ios/privacy.html
- **Soporte (Support URL):** https://javiercolroma.github.io/gym-swipe-ios/support.html
- **Marketing URL (opcional):** https://javiercolroma.github.io/gym-swipe-ios/

> Cómo activar Pages: GitHub → repo → Settings → Pages → Source: `Deploy from a branch` → Branch: `main` /`docs` → Save. En ~1 min las URLs estarán activas.

## Texto promocional (Promotional Text, máx. 170)
Planifica tus entrenos, registra series con swipes y mide tu Gym Score. Todo en tu dispositivo, sin cuentas ni complicaciones.

## Descripción (Description)
Forge Loop es tu compañero de gimnasio directo y sin fricción. Planifica entrenamientos, registra cada serie con un gesto y sigue tu progreso real con un Gym Score exigente.

Qué puedes hacer:
• Entrena con tarjetas: marca series hechas o saltadas deslizando.
• Crea y guarda tus rutinas, o usa plantillas listas.
• Mide tu Gym Score (fuerza, constancia, progreso, volumen, calidad y variedad). Es exigente: necesita 3 semanas de uso para ser fiable.
• Sigue tu nivel, tu racha y tus récords.
• Ranking con mapa para ver tu zona.
• Apartado Partner para encontrar compañeros de entreno.

Local-first: tus datos viven en tu dispositivo. Sin cuentas en servidores, sin anuncios y sin rastreo.

## Palabras clave (Keywords, máx. 100 caracteres, separadas por comas)
gimnasio,entreno,rutina,fuerza,pesas,fitness,workout,progreso,gym,musculacion,ranking,entrenamiento

## Clasificación por edad
- Apta para 4+ (no contiene contenido sensible). Responde "Ninguno/No" a todas las categorías del cuestionario.

## App Privacy (etiquetas de privacidad en App Store Connect)
- **¿Recopilas datos?** No. (Todos los datos se guardan en el dispositivo y no se transmiten.)
- **Tracking:** No.
- **Ubicación:** se usa solo en el dispositivo para centrar el mapa; no se "recopila" (no sale del dispositivo) → no se declara como dato recopilado.
- Coincide con `PrivacyInfo.xcprivacy` (sin tracking, sin recopilación, sin APIs de motivo requerido).

## Notas para el revisor (App Review Information → Notes)
Forge Loop es una app de entrenamiento local-first. La interfaz se construye con tecnología web empaquetada DENTRO del binario (no carga ningún sitio remoto); funciona offline salvo el mapa.

Las funciones sociales (mensajes, amigos, notificaciones) son demostrativas y locales: los compañeros y respuestas se simulan en el propio dispositivo para mostrar el flujo de la app. No hay backend ni datos compartidos entre usuarios.

La ubicación es opcional y solo se usa en el dispositivo para centrar el mapa del Ranking.

No se requiere cuenta de prueba (la app crea un perfil local al iniciar).

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
