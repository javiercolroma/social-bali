-- ─────────────────────────────────────────────────────────────────────────────
-- BALI CIRCLE · Chat tipo WhatsApp + buscador de miembros (2026-10-01)
--
-- Mensajes con fotos, vídeos, ubicación y notas de voz. El texto sigue siendo
-- obligatorio en la tabla (puede ir vacío en un mensaje multimedia) para no romper
-- builds anteriores, que solo leen `text`.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.messages add column if not exists kind       text not null default 'text';
alter table public.messages add column if not exists media_url  text;   -- foto, vídeo o audio
alter table public.messages add column if not exists poster_url text;   -- portada del vídeo
alter table public.messages add column if not exists media_w    int;
alter table public.messages add column if not exists media_h    int;
alter table public.messages add column if not exists duration   double precision;   -- vídeo / audio (s)
alter table public.messages add column if not exists lat        double precision;   -- ubicación compartida
alter table public.messages add column if not exists lon        double precision;

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (kind in ('text', 'image', 'video', 'location', 'audio'));
alter table public.messages drop constraint if exists messages_payload_check;
alter table public.messages add constraint messages_payload_check check (
  case kind
    when 'text'     then char_length(trim(text)) > 0
    when 'location' then lat is not null and lon is not null
    else media_url is not null
  end
);

-- Las notas de voz también van al bucket «media» (0029).
update storage.buckets
   set allowed_mime_types = array['image/jpeg','image/png','image/heic','video/mp4','video/quicktime',
                                  'audio/mp4','audio/x-m4a','audio/m4a','audio/aac']
 where id = 'media';

-- Buscador: miembros por nombre (sin bloqueados ni uno mismo), con lo justo para la lista.
create or replace function public.search_members(q text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  term text := trim(coalesce(q, ''));
begin
  if uid is null then raise exception 'not authenticated'; end if;
  if char_length(term) < 2 then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(c order by (c->>'online')::boolean desc nulls last, c->>'name')
      from (
        select public.circle_card(p, uid,
                 public.is_adult(uid) and exists (select 1 from public.profiles m where m.id = uid and 'dating' = any(coalesce(m.intents, '{}'))),
                 false) as c
          from public.profiles p
         where p.id <> uid
           and p.name ilike '%' || replace(replace(term, '%', ''), '_', '') || '%'
           and not public.is_blocked_pair(uid, p.id)
         limit 25
      ) s
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.search_members(text) from public, anon;
grant execute on function public.search_members(text) to authenticated;

-- Quién de mis chats está activo ahora (respeta show_online).
create or replace function public.online_among(ids uuid[])
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(p.id), '{}') from public.profiles p
   where p.id = any(ids) and p.show_online and public.is_online(p.id)
     and not public.is_blocked_pair(auth.uid(), p.id)
$$;
revoke all on function public.online_among(uuid[]) from public, anon;
grant execute on function public.online_among(uuid[]) to authenticated;
