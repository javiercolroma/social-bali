-- Métricas de lanzamiento (plan en launch/medicion.md).
-- Vive en el esquema `analytics`, que PostgREST NO expone: solo se consulta desde el
-- SQL editor o con la management API, nunca desde la app.
--
-- Uso semanal:  select * from analytics.launch_weekly;
--   semana        lunes de la semana de alta (UTC)
--   nuevos        perfiles creados esa semana (sin perfiles semilla)
--   escribieron   de esos, cuántos enviaron ≥1 mensaje en sus primeras 24 h
--   respondidos   de esos, cuántos recibieron respuesta ≤24 h después de su primer mensaje a alguien

create schema if not exists analytics;
revoke all on schema analytics from anon, authenticated;

create or replace view analytics.launch_weekly as
with nuevos as (
  select id, created_at
  from public.profiles
  where not is_seed
),
primero as (                       -- primer mensaje de cada nuevo a cada destinatario, en sus primeras 24 h
  select m.sender_id, m.recipient_id, min(m.created_at) as t0
  from public.messages m
  join nuevos n on n.id = m.sender_id
  where m.created_at <= n.created_at + interval '24 hours'
  group by m.sender_id, m.recipient_id
),
respondidos as (
  select distinct f.sender_id
  from primero f
  where exists (
    select 1 from public.messages r
    where r.sender_id = f.recipient_id
      and r.recipient_id = f.sender_id
      and r.created_at between f.t0 and f.t0 + interval '24 hours'
  )
)
select
  date_trunc('week', n.created_at)::date                              as semana,
  count(*)                                                             as nuevos,
  count(*) filter (where n.id in (select sender_id from primero))     as escribieron,
  count(*) filter (where n.id in (select sender_id from respondidos)) as respondidos
from nuevos n
group by 1
order by 1 desc;

revoke all on analytics.launch_weekly from anon, authenticated;
