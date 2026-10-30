# Cuentas de Bali Circle — inventario (SIN contraseñas)

**Las contraseñas y códigos viven en la app Contraseñas de Apple, grupo compartido "Bali Circle".**
Este fichero nunca debe contener contraseñas, tokens ni códigos de recuperación.
Actualizado: 2026-10-27.

## Correo y Meta
| Servicio | Usuario / identificador | Cómo se entra | Notas |
|---|---|---|---|
| Gmail personal | javiercolroma@gmail.com | Contraseña + 2FA | Llave de GitHub javiercolroma y, a través de él, de Vercel y probablemente Supabase |
| Gmail | balicircleindo@gmail.com | Contraseña + 2FA | Correo de la marca: llave de Meta (Instagram, Facebook, Threads) y de TikTok. Recuperaciones de Instagram llegan aquí |
| Cuenta de Meta (Centro de cuentas) | balicircleindo@gmail.com | Contraseña | Agrupa Facebook, Instagram y Threads |
| Instagram | @balicircleclub | Contraseña (cuenta de Meta) | Perfil profesional, categoría Comunidad |
| Threads | @balicircleclub | Vía Instagram | |
| Facebook (perfil personal) | Javier Colás | Contraseña (cuenta de Meta) | Necesario para grupos y para administrar la página |
| Página de Facebook | Bali Circle | Vía perfil personal | Vinculada a Instagram |
| Meta Business Suite | Cartera "Bali Circle" (id 40016862001238151) | Vía perfil personal | |

## Redes
| Servicio | Usuario | Cómo se entra | Notas |
|---|---|---|---|
| TikTok | @balicircleclub | Google: balicircleindo@gmail.com | Cuenta personal, no de empresa. Sin contraseña propia: depende de ese Gmail |

## Desarrollo y web
| Servicio | Usuario | Cómo se entra | Notas |
|---|---|---|---|
| GitHub | javiercolroma | Google: javiercolroma@gmail.com | **Cuenta de Bali Circle.** Repos: social-bali (privado), forgeloop-legal (público, web). Sin contraseña propia: depende de ese Gmail |
| GitHub (otra) | javiercolas | — | No usar para Bali Circle (no tiene acceso a los repos) |
| Vercel | Equipo "Bali Circle" | Continue with GitHub (javiercolroma → Gmail javiercolroma@gmail.com) | Proyecto `balicircle` → https://balicircle.vercel.app |
| Apple Developer / App Store Connect | Apple ID javiercolroma@gmail.com | Apple ID + 2FA | App id 6817778105, bundle com.javiercolroma.balicircle |
| App Store Connect API | Claves en `~/.appstoreconnect/private_keys/` | Fichero .p8 | Hacer copia del .p8 en Contraseñas (no se puede volver a descargar) |
| Supabase | javiercolroma@gmail.com (usuario javiercolroma) | Probablemente "Continue with GitHub" (confirmar) | Organización "bali", proyecto tmwgcvnibyvxedpqjqkr. Token de gestión en `~/.supabase/access-token-balicircle` |

## Pendientes
- Dominio balicircle.club (no comprado). Cuando se compre: añadir registrador aquí.
- Correo de soporte: sigue siendo soporte@forgeloop.app. Cambiar a uno de Bali Circle.
- Confirmar cómo se entra en Supabase (probablemente GitHub).
