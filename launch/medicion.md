# Medición del lanzamiento

## Enlaces de campaña (App Store Connect → App Analytics → Campaigns)
Crea uno por canal. Formato: `https://apps.apple.com/app/id6817778105?pt=PROVIDER_TOKEN&ct=CANAL`

| Canal | ct= | Dónde se usa |
|---|---|---|
| facebook | `facebook` | Posts en grupos de Facebook |
| whatsapp | `whatsapp` | Versión corta en grupos de WhatsApp |
| reddit | `reddit` | r/bali |
| venues | `venues` | QR en camps/gyms/hostels (o uno por venue si quieres detalle) |
| instagram | `instagram` | Link en bio (vía landing) |
| landing | `landing` | Botón de la landing |

Las instalaciones por canal se ven en App Analytics con 24–48 h de retraso. Apunta aquí cada viernes.

## Los tres números de cada semana

**Atajo (aplicado el 2026-10-26, migración 0038):** en el SQL editor de Supabase ejecuta solo esto y te da la tabla semana a semana, sin perfiles semilla:

```sql
select * from analytics.launch_weekly;
```

Las consultas de abajo son el detalle de lo que calcula esa vista.


Guarda estas consultas en Supabase (SQL editor → "Lanzamiento"). Ajusta nombres de columna si cambian.

```sql
-- 1. Nuevos usuarios con perfil completo en los últimos 7 días
select count(*) as nuevos
from public.profiles
where created_at >= now() - interval '7 days';

-- 2. De esos, cuántos enviaron al menos un mensaje en sus primeras 24 h
select count(distinct p.id) as escribieron
from public.profiles p
join public.messages m
  on m.sender_id = p.id
 and m.created_at <= p.created_at + interval '24 hours'
where p.created_at >= now() - interval '7 days';

-- 3. De esos, cuántos recibieron respuesta en las 24 h siguientes a su primer mensaje
with primero as (
  select m.sender_id, m.recipient_id, min(m.created_at) as t0
  from public.messages m
  join public.profiles p on p.id = m.sender_id
  where p.created_at >= now() - interval '7 days'
  group by m.sender_id, m.recipient_id
)
select count(distinct f.sender_id) as respondidos
from primero f
join public.messages r
  on r.sender_id = f.recipient_id
 and r.recipient_id = f.sender_id
 and r.created_at between f.t0 and f.t0 + interval '24 hours';
```

## Tabla semanal

| Semana | Nuevos | Escribieron | Respondidos | Mejor canal | Qué aprendí |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |

Objetivo a 4 semanas: 100 nuevos, 50 escribieron, 35 respondidos.

## Señales de alarma
- Nuevos altos, "escribieron" bajo → la rejilla está vacía o no invita a hablar. Problema de densidad o de UX del primer mensaje.
- "Escribieron" alto, "respondidos" bajo → la gente instala y se va. Hacen falta notificaciones push que funcionen y gente que vuelva.
- Un canal trae el 80 % → dobla ahí, deja los demás.
