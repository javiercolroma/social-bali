# Dirección de producto — The social club for active people in Bali

> Documento canónico de producto (2026-09-28). El README es la memoria **técnica**;
> esto es el **porqué**. Ante una duda de alcance, manda este documento.

## La frase

> Un **club social privado para personas activas en Bali**, donde el fitness, el lifestyle
> y las actividades sirven para **descubrir y conectar personas**.

No es «una app de fitness con funciones sociales». No es «Tinder para gente de gimnasio».
No es una app global que casualmente empieza en Bali.

El bucle:

```
FITNESS → IDENTIDAD → DISCOVER → CONEXIÓN → VIDA REAL
```

El deporte funciona como identidad, filtro natural de comunidad, contenido, interés
compartido, contexto para empezar una conversación y **excusa para verse en persona**.

## El filtro para cualquier decisión futura

> ¿Esta funcionalidad ayuda a que personas activas e interesantes que están en Bali se
> **descubran**, **conecten** y terminen **haciendo algo juntas**?

Si solo aumenta tiempo de pantalla sin aumentar conexiones reales, no entra.

## Principios

1. **Social first. Dating can happen naturally.** Alguien debe poder entrar sin buscar
   pareja y obtener igualmente mucho valor («acabo de llegar a Bali», «quiero gente para
   surfear»). La **ambigüedad social es deseada**: dos personas empiezan entrenando y
   acaban siendo amigas, o al revés.
2. **Dating existe, pero es una de varias formas de conexión.** Nunca una pestaña
   `DATING` que parta el producto en dos. Vive dentro de Discover como una intención más.
3. **Una sola comunidad, no tres apps.** Las preferencias de conexión (Dating / Friends /
   Training) afinan Discover; **no** crean compartimentos separados.
4. **Conectar tiene contexto.** No un ❤️ mudo: *train together*, *surf sometime*, *grab a
   coffee*, *interested*. La conversación nace con un motivo y mata el «hola, qué tal».
5. **El objetivo no es chatear: es quedar.** El producto debe empujar fuera de la app.
   `DISCOVER → CONNECT → CHAT → HACER ALGO`, no `→ chat durante semanas`.
6. **Escasez, no swipe infinito.** Un número limitado de perfiles al día («Today's
   People», 10-15). Cuando terminas, terminas. Cada perfil pesa más.
7. **Densidad antes que crecimiento.** 500 personas adecuadas en Canggu/Uluwatu valen más
   que 50.000 repartidas por el mundo.
8. **Exclusividad por curaduría, jamás por atractivo físico.** Nada de «beauty score».
   Se filtra por *lifestyle fit*, *profile quality* y *community fit*. La sensación de
   club la produce **la gente que hay dentro**, no un cartel que diga «exclusive».
9. **Identidad demostrada, no declarada.** La ventaja competitiva frente a una dating app
   normal: aquí hay señales **reales** de actividad (entrena 4×/semana, activo 8 semanas).

## Bali forma parte del producto

Cultura: surf, fitness, wellness, running, yoga, beach lifestyle, nómadas, expatriados,
gente de paso y gente que se queda meses. Comunidad internacional.

Arranque concentrado en **Canggu, Berawa, Pererenan, Uluwatu, Bingin, Pecatu**.

**«In Bali until…» es información crítica**, no un detalle escondido del perfil: *living
here*, *until Nov 12*, *2 weeks left*, *1-3 months*, *long term*. Cambia por completo la
utilidad de una conexión.

---

# Qué hay ya construido (más de lo que parece)

Auditoría del código a 2026-09-28. **Esto es reutilizable tal cual o con poco cambio:**

| Pieza | Estado | Encaje con la nueva dirección |
|---|---|---|
| **Actividades** (`training_plans` + `PartnerView`) | **Real**, en Supabase | Es el §15 casi literal: `title`, `when_text`, `place`, `spots`, `note`, celda geo, orden por distancia y «Aceptar» → abre chat real. Falta reencuadrarlo: *Sunday Run · Canggu* con **I'm in**. |
| **Grafo social** (`follows`, feed, comentarios, kudos) | Real, con RLS | Base sólida. Pero el modelo es **Instagram (asimétrico)**, no *connect mutuo con intención*. Ver hueco #3. |
| **Chat 1:1** (`messages`) | Real | Se desbloquea al conectar. Ya existe. |
| **Moderación** (`blocks`, `reports`) | Real | **Imprescindible** para un producto social/dating en la App Store. Ya está. |
| **Presencia geo** (`geo_cell_lat/lon`, `active_at`) | Real | Vale para «cerca de mí», con la salvedad de precisión (ver tensión #2). |
| **Señales de actividad** (Gym Score, racha, entrenos/semana, `verified`) | Real | **El diferenciador del §13.** La parte difícil —medir actividad real y detectar farmeo— ya está hecha. |
| **Cumplimiento** (borrado de cuenta, manifiesto de privacidad, legales, TestFlight) | Hecho | Nos ahorra semanas al relanzar. |

## Qué NO existe (el corazón de la nueva dirección)

1. **El perfil no tiene personalidad.** Hoy `Profile` es: sexo, edad, país, ciudad,
   gimnasio, goal, level, weeklyDays, motivation. **Faltan**: bio de una línea, deportes
   e intereses, **barrio** (Pererenan, no «ciudad»), país de origen, **in Bali until** e
   intenciones de conexión. Sin esto, Discover no tiene nada que mostrar.
2. **Discover de personas no existe como superficie.** `DiscoverPeopleView` es una **caja
   de búsqueda por @usuario**, no un deck curado diario. El §4/§5 es funcionalidad nueva.
3. **Conectar con contexto no existe.** Hoy solo hay *seguir*: asimétrico, sin intención
   y sin conexión mutua. Hay que añadir intents + mutuo → desbloquea chat.
4. **No hay puerta de entrada.** Cualquiera se registra y está dentro (§11).

---

# Tensiones reales (decisiones, no detalles)

Las pongo por delante porque **condicionan el orden del trabajo**.

### 1. El idioma del producto es el español · **BLOQUEANTE**
`developmentLanguage: es` y **las cadenas del código SON las claves en español**; inglés,
francés y portugués son traducciones. El público de Canggu y Uluwatu es internacional y
funciona en **inglés**. Para un club de Bali, el inglés debe ser la base, no la
traducción. Invertir la dirección de localización es trabajo real y **conviene decidirlo
antes de escribir una línea más de UI nueva**, o se paga dos veces.

### 2. La precisión geográfica no da para «barrios»
La presencia se redondea a celdas de **0,05° ≈ 5,5 km** (decisión de privacidad, buena).
Pero Canggu, Berawa y Pererenan caben en ~3 km: con esa celda son **indistinguibles**.
El barrio del §4 **no se puede derivar del GPS actual**.
→ Propuesta: el barrio es un **campo declarado** por la persona (es identidad, no
tracking) y la celda gruesa se queda solo para «cerca de mí». Sale más privado *y*
socialmente más preciso.

### 3. Clasificación por edad y App Review
Hoy la ficha declara **4+** y «sin contenido sensible». Con dating dentro: mínimo
**17+/18+**, edad mínima real en el registro y ficha rehecha. Apple mira con lupa las
apps de citas (guía 4.3, saturación): **el ángulo club social + actividades ayuda**, y
conviene que lo primero que vea un revisor no sea un deck de swipe. La moderación que
exigen (bloquear, denunciar, borrar cuenta) **ya la tenemos**.

### 4. La puerta de entrada choca con la revisión de Apple
Un revisor que se queda en una waitlist = rechazo por «no puedo acceder». Hace falta un
camino de revisión (cuenta pre-aprobada o código de invitación en las notas). Lo sé de
primera mano: ya nos tocó explicar el login por código.

### 5. La gamificación actual habla otro idioma
Ligas estilo Duolingo, XP, misiones semanales, confeti, mascota. Eso es lenguaje de app
de fitness gamificada, **no de club privado**. El §13 quiere señales de actividad
(*trains 4×/week*, *active 8 weeks*) — eso **sí**, y ya existe. Pero «¡Has ascendido a
Liga Oro!» probablemente sobra o debe volverse mucho más discreto. **Decisión de
producto, no técnica.**

### 6. Los usuarios demo envenenan la métrica clave
El feed y el ranking se rellenan con gente falsa (`seedDemo`) cuando no hay usuarios
reales. Si la métrica es *«la gente que hay aquí mola»*, el primer miembro real no puede
encontrarse muñecos. Hay que poder **apagar el demo por completo** y aceptar el vacío
mientras se siembra la comunidad a mano.

### 7. `allowShortWorkouts = true` invalida las señales de actividad
Ese flag —marcado en el código como *«APAGAR antes de cualquier lanzamiento público»*—
permite guardar entrenos implausibles, y **está encendido con la app ya en TestFlight**.
Si la actividad real va a ser la prueba de identidad del §13, hay que apagarlo.

### 8. El nombre
«Forge Loop» y el repo `gym-swipe-ios` son nombres de producto de gimnasio. El bundle ID
puede quedarse (es interno), pero el nombre de cara al público probablemente deba cambiar.

---

# Hoja de ruta propuesta

El orden no es negociable en lo esencial: **sin identidad no hay Discover**, y sin
Discover no hay conexión que medir.

### Fase 1 · Identidad (el cimiento) — 🟡 EN CURSO
Perfil nuevo: bio de una línea, deportes/intereses, barrio, país de origen, **in Bali
until** e intenciones (Dating / Friends / Training, multi-selección). Onboarding
rehecho alrededor de esto. Migración de `profiles`.
*Sin esta fase, todo lo demás muestra tarjetas vacías.*

- [x] Dominio (`SocialClub.swift`), `Profile` extendido, migración `0023`, backend en ambos sentidos.
- [x] **Onboarding rehecho**: 6 pasos nuevos (deportes, zona + gimnasio, estancia, origen, bio, intenciones), en inglés y verificados en simulador. Salen los 4 pasos de encuesta fitness (`goal`, `level`, `days`, `motivation`): se escribían y **no se leían en ninguna parte**.
- [ ] **Mostrar la identidad en el perfil** (bio, deportes, barrio, estancia, intenciones). Hoy se captura pero no se ve en ningún sitio.
- [ ] **Editar perfil**: quien ya tenga cuenta no puede rellenar estos campos — solo se piden en el alta.
- [ ] Traducir al español/francés/portugués las cadenas nuevas (`es.lproj` etc.).

### Fase 2 · Discover
«Today's People»: 10-15 perfiles al día, curados, con final explícito. Tarjeta de perfil
que mezcle fotos, personalidad, deportes, barrio, situación en Bali y actividad real.

### Fase 3 · Connect con contexto
Intents (*train* · *surf* · *coffee* · *interested*) → el receptor ve **el motivo**.
Mutuo = conexión y se abre el chat. Convive con el *follow* actual sin sustituirlo aún.

### Fase 4 · Actividades
Reencuadrar `PartnerView` → **Activities** con **I'm in**: de «buscar compañero de gym» a
*Sunday Run · Canggu*, *Sunset Surf · Batu Bolong*, *Padel · 18:00*. Es la fase con
**mejor relación valor/esfuerzo**: el backend ya está.

### Fase 5 · La puerta
Solicitud de entrada, invitaciones/referrals, waitlist, aprobación manual, perfil mínimo
obligatorio. Criterios: *lifestyle fit*, *profile quality*, *community fit*.

### Fase 6 · Bali de verdad
Barrios como ciudadanos de primera, ajuste geográfico, apagado del demo y **siembra
manual de los primeros cientos de miembros** — que son quienes definen la cultura.

## Cómo sabremos que funciona

Una persona abre Discover y piensa: *«hay varias personas aquí a las que realmente me
gustaría conocer»*. Después conecta, recibe conexiones, abre chats **y queda con
alguien**. Ese último paso es el único indicador que importa de verdad.
