# Semana 1 de lanzamiento — Bali Circle

Objetivo de la semana: **30–40 personas reales en Canggu dentro de la app antes de hacer ruido.**
Métrica que manda: usuarios que envían un mensaje en sus primeras 24 h y reciben respuesta.
Las descargas no cuentan.

Regla: antes de abrir Xcode cada día, mira los tres números de `medicion.md`.
Si no puedes responderlos, la tarea del día no es programar.

Cabeza de playa: **Canggu + Uluwatu, surf primero**. Toda la comunicación habla de surf y gym aunque la app haga más.
Canggu y Uluwatu están a 40+ min: sus rejillas no se mezclan, así que cada zona necesita su propia densidad (objetivo: 25 personas en Canggu y 15 en Uluwatu antes de hacer ruido).

---

## Estado al día (se actualiza en cada sesión)

Leyenda: [x] hecho · [ ] pendiente · [~] en curso · ⛔ bloqueado. Entre paréntesis, quién lo hace.

### Cuentas y presencia
- [x] Instagram `@balicircleclub` creado (Javier) — 25 oct
- [x] Instagram: acceso desde el ordenador resuelto (Javier) — 27 oct. Claude tiene acceso vía Chrome
- [x] Instagram: bio puesta (Claude, Chrome) — 27 oct: "Meet people. Do things. See what happens. 🌊 / A private social circle for active people in Bali. / Canggu · Uluwatu"
- [ ] Instagram: destacados (Javier o Claude)
- [x] Instagram: contraseña / acceso resuelto (Javier) — 27 oct
- [x] Instagram: vinculado a la página de Facebook (Javier) — 27 oct
- [x] TikTok `@balicircleclub` creado (Javier) y configurado: logo, nombre, bio con mención a la App Store (Claude) — 25 oct. Cuenta personal; nombre bloqueado hasta 1 nov
- [x] Perfil personal de Facebook creado (Javier) — 26 oct
- [x] Perfil de Facebook: bio "Developer. Building Bali Circle…", trabajo, ciudad, web https://balicircle.vercel.app (Javier)
- [x] Perfil de Facebook: portada = foto natural de Bali, sin logo ni texto (Javier) — la de marca va en la página, no en el perfil
- [x] Página de Facebook "Bali Circle" creada (Javier) — 26 oct. Logo y portada de marca en Descargas (`balicircle-logo.png`, `balicircle-facebook-cover.png`)
- [x] Landing en https://balicircle.vercel.app (Claude) — 26 oct. Se publica sola desde el repo forgeloop-legal
- [x] Vercel: cuenta enlazada a GitHub javiercolroma; app de Vercel limitada al repo forgeloop-legal (Javier + Claude) — 26 oct
- [ ] Dominio propio balicircle.club (Javier compra; Claude configura) — aplazado

### Credenciales
- [x] Inventario de cuentas sin contraseñas en `launch/CUENTAS.md` (Claude) — 27 oct
- [x] Grupo "Bali Circle" en la app Contraseñas creado con las cuentas (Javier) — 27 oct. GitHub, Vercel y Supabase entran con GitHub/Gmail javiercolroma@gmail.com
- [x] Apple ID de desarrollador anotado en CUENTAS.md (sin contraseña) — 27 oct
- [x] TikTok entra con Google balicircleindo@gmail.com (Javier, 27 oct)
- [x] Cambio de contraseñas de Apple ID e Instagram: descartado por decisión de Javier (27 oct)
- [x] Modelo de acceso de Claude definido (27 oct): sesiones de Chrome de Javier + claves en el Mac (Supabase, App Store Connect, SSH de GitHub). Claude nunca lee ni escribe contraseñas; Javier inicia sesión cuando caduque y da los códigos 2FA
- [ ] Guardar copia de las claves .p8 de App Store Connect en Contraseñas (Javier)

### Medición
- [x] Vista `analytics.launch_weekly` en Supabase (Claude) — 26 oct. Uso: `select * from analytics.launch_weekly;`
- ⛔ Enlaces de campaña de App Store Connect (Javier) — cuando Apple apruebe la app; luego Claude pone el de `landing` en el botón

### Investigación
- [x] 45 sitios verificados: 30 Canggu + 15 Uluwatu, en `dm-venues.md` (Claude) — 26 oct
- [x] Grupos de Facebook y Reddit verificados, en `post-grupos.md` (Claude) — 26 oct
- [x] Buscar con sesión iniciada grupos sociales de Uluwatu/Bukit y de surf buddies de Canggu (Claude, Chrome) — 26 oct. Hallazgo: Uluwatu Community (100k, sin regla anti-promo). No existe grupo social de surf buddies: solo compraventa de tablas
- [x] Unirse a Uluwatu Community (100k) y ULUWATU COMMUNITY (34k) (Claude, Chrome) — 26 oct, miembro de los dos
- [x] Investigación Veo / Google AI Studio para vídeo IA (Flow, créditos, prompts, política IG/TikTok), en `~/Downloads/balicircle-instagram/references/viral/VEO-AISTUDIO-oct2026.md` (Claude) — 30 oct. Hallazgo clave: Veo 3.1 ya no está en AI Studio/Gemini API (apagado 22 oct); se usa en Flow con los 1.000 créditos/mes de AI Pro

### Grupos de Facebook
- [x] Unirse a los 6 grupos (Claude, Chrome) — 26 oct
  - [x] Canggu Community Bali ❤ — miembro
  - [x] Uluwatu Digital Nomads — miembro
  - [x] Canggu Community-Bali — miembro
  - [x] Digital Nomads Bali — miembro; el editor de publicaciones ya se abre sin pedir preguntas (si al publicar las pide, respuestas aprobadas: "Yes, I'm a software developer and I work remotely." / "Yes, I promise.")
  - [~] Bali Digital Nomads - Borderless Entrepreneurship (privado) — respuestas enviadas 26 oct ("Ok, understood." / "Ok."); esperando aprobación del admin
  - [~] Canggu Digital Nomads (privado) — reglas aceptadas y enviado 26 oct; esperando aprobación del admin
- [ ] Calentar el perfil: 2–3 comentarios útiles en posts de otros, texto aprobado por Javier antes de publicar (Claude, Chrome) — empezar 27 oct, durante 3–4 días. Candidato: post de Digital Nomads Bali "Do you prefer being self employed or having a job as a nomad? Why?" (22 oct)
- [ ] Pedir permiso al admin de Canggu Community (151k) para publicar (Javier o Claude con texto aprobado)
- [ ] Primer post en grupos — no antes del 30 oct para que el perfil no sea tan nuevo

### Marca
- [x] Borrador v0 de plataforma de marca en `launch/MARCA.md` (Claude) — 28 oct
- [x] MARCA.md v1 con los 10 principios de Javier: exclusiva, deseable, understated; público incluye viajeros de 2 semanas e influencers (Claude) — 28 oct
- [ ] Cerrar las 5 preguntas abiertas de MARCA.md §11 (Javier)
- [ ] Decidir el criterio real de aprobación y si se actualiza PRODUCT.md §8 ("jamás por atractivo físico") (Javier)
- [x] Sistema creativo permanente creado en `~/Downloads/balicircle-instagram/` (Claude) — 28 oct: CLAUDE.md, WORKFLOW.md, brand/ (6 docs), references/, approved/, rejected/, campaigns/launch/ (inventario y clasificación). Generador y fotos rescatados de la carpeta temporal
- [x] Approved/rejected decididos (Claude, autonomía delegada por Javier) — 28 oct: 12 fotos de Javier + 3 posts aprobados; 12 lecciones en rejected
- [ ] Aportar primeras referencias a `references/` (fotografía, cuentas de Instagram, tipografía) (Javier)
- [x] Post 7 rehecho y sustituido en Instagram y Threads (Claude) — 28 oct, 29 oct 18:00 Bali, verificado
- [x] Logo nuevo (aro zen terracota) aplicado a los 8 posts; versión marfil sobre fotos (Claude) — 28 oct. `brand/assets/logo-ring*.png`
- [x] Relanzamiento v4 renderizado: `~/Downloads/balicircle-instagram/output/relaunch-28oct/` (Claude) — portadas sin solo-texto, fotos de gym/stock sustituidas, captions más cortas
- [x] Post de prueba con IA (Gemini, 3 imágenes): "Someone new is in Uluwatu" (Claude) — `campaigns/ai-test-oct/`
- [x] TikTok: borrados todos los posts antiguos y republicado (Claude) — 28 oct. Publicados 1 y 2; programados 3 (29), 6 (30), 7 (31), 9 (1 nov), 10 (2 nov), IA (3 nov, con etiqueta "Contenido generado por IA"). Verificado
- [x] Instagram (Claude) — 28-29 oct: borrado todo lo antiguo. Publicados 1, 2, 3, 6 (28 oct) y 7 (29 oct). Programados 9 (30 oct), 10 (31 oct) e IA (1 nov, con etiqueta de IA), a las 17:00 GMT+7 = 18:00 Bali
- [x] Threads (Claude) — 29 oct: borrados los 5 antiguos (incl. el post 7 viejo que salió hoy) y los 2 programados viejos. 1, 2, 3, 6 llegaron desde Instagram; 7 publicado a mano; 9 y 10 programados
- [x] Post IA en Threads programado para el 1 nov sin etiqueta de IA (decisión de Javier, 30 oct) (Claude)
- [x] 3 reels foto + gancho (Instrument Serif) programados en TikTok 4, 5 y 6 nov con música comercial (Claude) — `campaigns/reels-oct/`
- [x] Reels foto+zoom descartados por Javier (calidad). Sustituidos por 5 reels con vídeo de stock real 4K de Pexels + música Mixkit, generador en `campaigns/reels-nov/` (Claude) — 30 oct. TikTok: programados 4–8 nov
- [ ] **Javier: revisar el tipo de contenido (reels en `~/Downloads/balicircle-instagram/output/reels-nov/`) antes de publicar más.** Pausado: reels en IG/FB/Threads e historias
- [ ] **Javier: borrar en la página de Facebook los 5 posts publicados hoy (1, 2, 3, 6, 7) y los 3 programados (9, 10, IA)**. Claude no hace borrados definitivos y "Mover a borradores" da error en Business Suite
- [x] Pruebas de contenido más arriesgado (Claude) — 30 oct: `output/reels-nov/x1-rating-ways-to-meet-people.mp4` (formato ranking) y `launch-spot-20s.mp4` (guion de lanzamiento de Javier, stock 4K + música generada con Gemini). Herramientas IA probadas: Google Vids (cuota agotada, 720p/3 s), Gemini vídeo (bloqueado, requiere plan), Higgsfield (requiere plan Plus), Kling/Runway/Hailuo (sin sesión), Sora (cerrado). Gemini música: funciona
- [x] Investigación Flow/Veo/Omni (`references/viral/VEO-AISTUDIO-oct2026.md`): la cuenta es Google AI Pro → generar en flow.google.com (1.000 cr/mes + 50/día), no en AI Studio (Omni de pago por uso) (Claude) — 30 oct
- [~] Tanda A de reels con vídeo IA, plan en `campaigns/reels-nov/BATCH-A.md` (Claude). A1 primer corte hecho (160 créditos) → `output/reels-nov/A1-nobody-tells-you-this.mp4`, pendiente de que Javier lo vea. Luego A3 y A2
- [ ] (antiguo) Reels en Instagram: la web no tiene biblioteca de música. Opciones: Javier los sube desde el móvil con audio en tendencia (los archivos están en `output/reels-30oct/`), o se descarga música libre de derechos (Claude)
- [x] Historias de IG: se pueden publicar y programar desde Meta Business Suite (probado sin publicar) (Claude)
- [ ] Plan de historias diarias de IG (Claude)
- [x] App: logo nuevo (icono, arranque, carga, tapas) en rama `logo-ring` del repo, compila; sin subir (Claude) — falta revisar y fusionar a `circle` y subir build cuando Apple termine la revisión (Javier)
- [ ] Capturas de la app para posts de producto: hace falta una sesión iniciada en el simulador (cuenta de prueba de Javier) (Javier + Claude)
- [x] Tipografía decidida: Instrument Serif para piezas nuevas (Claude) — 30 oct
- [ ] Javier: volver a fijar los posts 1 y 2 en Instagram desde el móvil (al republicar se pierden las fijaciones)
- [x] Fotos de perfil con el logo nuevo en Instagram, Threads, TikTok y página de Facebook + portada de Facebook nueva (Claude) — 29 oct. `brand/assets/profile-picture.png`, `facebook-cover.png`
- [ ] Bio de TikTok y página de Facebook prometen "Search Bali Circle on the App Store" / "Free on iPhone": cambiar cuando se sepa la fecha de Apple (Claude)
- [ ] Landing: logo nuevo en balicircle.vercel.app (Claude)
- [ ] App iOS: icono con el logo nuevo (otra sesión / Javier)
- [ ] Aplicar la marca cerrada a las plantillas de posts (tipografía, tono) (Claude) — solo cuando Javier lo pida

### Contenido
- [x] Imágenes v1 de 6 posts (Claude) — 26 oct. Descartadas por Javier
- [x] Guion v2 de 10 posts y regla 70/30 (Javier) — 26 oct, en `instagram.md`
- [x] Fotos de Unsplash para v2 (Claude) — 26 oct, 23 fotos en `~/Downloads/balicircle-instagram/fotos/`
- [x] Render de los 10 posts v2, 45 slides (Claude) — 26 oct, `~/Downloads/balicircle-instagram/v2/`. Generador: scratchpad de la sesión (igposts2/gen.py); cambiar una foto = sustituir el jpg en fotos/ y re-renderizar
- [x] Sustituir fotos de surf y playa por las 12 que eligió Javier (Claude) — 26 oct, 12 slides en posts 1, 2, 4, 6, 7, 8 y 10. Las de Unsplash sustituidas quedan en `fotos/unsplash-anteriores/`
- [x] v3 de los 10 posts (Claude) — 26 oct, `~/Downloads/balicircle-instagram/v3/` en JPG: sin números de página, logo en la cabecera de cada slide y grande en la última, fotos y render a doble resolución. **Usar v3, no v2**
- [x] Ajustes v3 (Claude) — 26 oct: quitados los "Swipe →"; logo solo en la portada (con el nombre) y pequeño en la última; el resto solo "BALI CIRCLE" en texto. Fotos de trabajo en el scratchpad de la sesión (las carpetas fotos y v2 de Descargas están en la Papelera)
- [ ] Decidir qué significa "Apply to join" / "Membership is limited": formulario + lista de espera, códigos de acceso, o suavizar el texto (Javier)
- [~] Publicar posts 1, 2 y 8 (Javier) — 1 y 2 publicados el 27 oct; falta el 8
- [ ] Fijar posts 1, 2 y 8 desde la app del móvil (Javier) — la web de Instagram no permite fijar. Orden: fijar 8, luego 2, luego 1 (el último fijado sale primero)
- [x] Ritmo de publicación decidido: uno al día (Javier) — 27 oct
- [ ] Calendario Instagram (Claude publica desde Chrome tras aprobar cada texto):
  - [x] 27 oct — post 3 "Maybe you meet for a workout" (Claude, Chrome). Ubicación Canggu, Bali
  - [x] 28 oct 18:00 Bali — post 6 PROGRAMADO en Instagram (Claude, 27 oct). Ubicación Uluwatu
  - [x] 29 oct 18:00 Bali — post 7 Moments PROGRAMADO en Instagram (Claude, 27 oct). Ubicación Canggu
  - [x] 30 oct 18:00 Bali — post 9 marca PROGRAMADO en Instagram (Claude, 27 oct). Ubicación Canggu
  - [x] 31 oct 18:00 Bali — post 10 PROGRAMADO en Instagram (Claude, 27 oct). Ubicación Uluwatu. Verificado en instagram.com/scheduled_content
  - Nota: programar desde la web de Instagram (Business Suite no sirve: su selector de archivos es el del Mac y Claude no puede usarlo)
  - Nota: el Mac de Javier está en hora de Bangkok (UTC+7); Bali es UTC+8 → 18:00 Bali = 17:00 en su ordenador
  - Nota: al programar, Instagram desactiva "Compartir en Threads" → Threads se programa aparte desde threads.com (menú … → Programar…)
- [ ] Facebook: la página Bali Circle no recibe estos posts (se programaron en Instagram, no en Business Suite). Si se quiere, publicarlos en la página (Claude, con OK de Javier)
- [ ] Próximo lote de contenido (posts 4, 5, 8) tras aprobación de Apple y decisión "Apply to join" (Javier)
  - ⛔ posts 4, 5 y 8 — esperan a la aprobación de Apple y a decidir lo de los códigos de acceso
- [x] Threads: perfil creado (Javier) — 27 oct
- [x] Threads: enlace a https://balicircle.vercel.app en el perfil (Claude, Chrome) — 27 oct
- [ ] Threads: bio desde la app (Javier) — la web no la guarda. Texto: "Meet people. Do things. See what happens. 🌊 / A private social circle for active people in Bali. / Canggu · Uluwatu"
- [x] Threads: cada post de Instagram va también a Threads (regla de Javier, 27 oct). Al día hasta el post 10
- [x] Vincular Instagram a la página de Facebook (Javier) — 27 oct. El Centro de cuentas muestra Facebook, Instagram, Threads y la página Bali Circle
- [x] Meta Business Suite: cartera renombrada a "Bali Circle" (Javier) — 27 oct
- [x] Meta Business Suite: página Bali Circle como página principal (Javier) — 27 oct
- [x] Meta Business Suite: Instagram vinculado y visible junto a la página (Claude, 27 oct)
- [x] Textos de IG 6, 7, 9, 10 y TikTok 2, 3, 6, 7, 9, 10 aprobados (Javier, 27 oct) y programados (Claude)
- [x] Threads: posts 1, 2 y 3 publicados (Claude, 27 oct)
- [x] Threads: posts 6 (28 oct), 7 (29), 9 (30), 10 (31) PROGRAMADOS 18:00 Bali (Claude, 27 oct). Verificado en Borradores de Threads
- [x] TikTok: 45 slides verticales 1080×1920 con zonas seguras (Claude) — 27 oct, `~/Downloads/balicircle-tiktok/`
- [x] TikTok: comprobado que TikTok Studio web admite carruseles de fotos (pestaña "Fotos") (Claude) — 27 oct
- [x] TikTok: calendario aprobado, mismo orden que Instagram, uno al día (Javier) — 27 oct
- [x] TikTok: post 1 publicado (Claude, Chrome) — 27 oct, ubicación Canggu. Estado "en revisión" / "Solo yo" hasta que TikTok lo apruebe; comprobar
- [x] TikTok: post 1 público tras revisión (27 oct)
- [x] TikTok: post 2 PROGRAMADO 28 oct 18:00 Bali (Claude)
- [x] TikTok: posts 3 (29 oct), 6 (30), 7 (31), 9 (1 nov), 10 (2 nov) PROGRAMADOS 18:00 Bali (Claude, 27 oct). Verificado en TikTok Studio
- [ ] Publicar el resto, uno al día (Javier, móvil)

### Mensajes directos a sitios
- [~] DM a los 45 sitios de `dm-venues.md` (Claude, desde Instagram en Chrome, cada texto aprobado por Javier) — 27 oct
  - [x] Lote 1: 12 perfiles leídos y 12 borradores personalizados escritos (Claude) — en `dm-venues.md`
  - [x] Lote 1: aprobado por Javier; añadido "I live here in Bali" (Javier confirmó que está en Bali) — 27 oct
  - [x] Enviados 27 oct: @kimasurf, @pelanbali (Claude, Instagram web)
  - ⛔ Resto del lote 1 (10) y lotes 2–4: **en pausa por decisión de Javier hasta que la app esté aprobada** ("no tiene sentido sin la app")
  - [ ] Si Kima o Pelan Pelan contestan antes de la aprobación: responder que avisamos en cuanto esté en la App Store
  - [ ] Al aprobarse la app: cambiar "launching in the next few days" por el enlace y reanudar
- [x] TikTok DMs: descartado por ahora (Javier propuso, Claude desaconseja: la mayoría de negocios solo aceptan DMs de cuentas que siguen y duplicar canal parece spam) — 27 oct
  - [ ] Lotes 2–4: los 33 restantes, a ~10 por día

### Pendiente técnico (otra sesión)
- [ ] Revisión de Apple de la build de producción
- [ ] Correo de soporte: sigue siendo soporte@forgeloop.app

---

### Producto
- [~] Puerta de entrada (decisión de Javier, 30 oct): solicitud → aprobación manual por el admin desde la app → dentro; códigos de invitación personales (3 usos) y códigos `APPLEREVIEW`/`FOUNDER`. Va en la 1.1 (la 1.0 está en revisión desde el 25 oct); el servidor lleva el interruptor `require_approval`, apagado hasta que la 1.1 esté en la tienda (Claude) — 30 oct

---

## Día 1 (lunes) — Infraestructura de lanzamiento (sin código de la app)
- [x] Crear cuenta de Instagram de la marca. Handle preferido `@balicircle`; alternativas `@balicircle.app`, `@bali.circle`. Bio en `instagram.md`.
- [x] Crear cuenta de TikTok con el mismo handle (aunque no publiques aún, reserva el nombre).
- [x] Landing de una página con el texto de `landing.md`. Botón → App Store. Enlace → Instagram.
- [ ] Generar los enlaces de campaña de App Store Connect (uno por canal, lista en `medicion.md`).
- [x] Guardar las 3 consultas de `medicion.md` en el SQL editor de Supabase como "Lanzamiento".

## Día 2 (martes) — Lista de objetivos
- [x] Rellenar `dm-venues.md` con 30 sitios reales de Canggu (8 surf, 6 gym, 8 hostels, 4 coworkings, 4 cafés) y 15 de Uluwatu (5 surf, 3 gym, 4 hostels, 1 coworking, 2 cafés). Verificar que siguen abiertos y copiar su Instagram.
- [x] Verificar los 5 grupos de Facebook de `post-grupos.md` (nombre exacto, reglas de autopromoción, día permitido para promo si lo hay).
- [ ] Publicar en Instagram los posts 1, 2 y 3 de `instagram.md`. Un perfil con 3 posts ya parece real.

## Día 3 (miércoles) — Primera ola de DMs
- [ ] Enviar el DM de `dm-venues.md` a los 15 primeros sitios (Instagram DM). Personalizar la primera frase de cada uno.
- [ ] Publicar en 2 grupos de Facebook el post largo de `post-grupos.md`.
- [ ] Responder a todo comentario y DM en menos de 2 horas. Esto es el trabajo del día.
- [ ] Publicar post 4 de Instagram.

## Día 4 (jueves) — Segunda ola
- [ ] DM a los otros 15 sitios.
- [ ] Publicar en los 3 grupos de Facebook restantes + r/bali (versión corta/pregunta de `post-grupos.md`).
- [ ] Apuntar en `medicion.md` → tabla de canales: cuántas instalaciones por enlace de campaña.
- [ ] Publicar post 5 de Instagram.

## Día 5 (viernes) — Seguimiento
- [ ] Mensaje de seguimiento (`dm-venues.md`, sección "Follow-up") a los sitios que no contestaron.
- [ ] A cada sitio que dijo sí: enviar el QR (Instagram + App Store) y la imagen para su recepción/stories.
- [ ] Publicar post 6 de Instagram.
- [ ] Escribir por la app o por Instagram a cada usuario nuevo: "Hey, I'm Javier, I built this. What were you hoping to find?" Apuntar respuestas en `feedback.md` (créalo el primer día que haya una respuesta).

## Fin de semana — Escuchar
- [ ] 20 minutos de conversación (audio o texto) con al menos 8 usuarios. Preguntas en la sección de abajo.
- [ ] Rellenar la tabla de la semana en `medicion.md`.
- [ ] Decidir las 3 únicas cosas que se arreglan en la app la semana que viene. Las demás, a una lista "después".

---

## Las 5 preguntas de las conversaciones con usuarios
1. ¿Qué hiciste el primer día que llegaste a Bali para conocer gente? ¿Cómo fue?
2. ¿Qué esperabas que hiciera la app cuando la instalaste?
3. ¿En qué momento te perdiste o dudaste?
4. ¿Has escrito a alguien? ¿Te han respondido? ¿Habéis quedado?
5. Si la app desapareciera mañana, ¿qué echarías de menos? (si la respuesta es "nada", pregunta por qué)

## Lo que NO se hace esta semana
- No se añaden features.
- No se graban vídeos con tu cara (ni sin ella hasta la semana 2).
- No se pagan anuncios.
- No se abre a Ubud, Sanur ni ninguna zona fuera de Canggu y Uluwatu.
