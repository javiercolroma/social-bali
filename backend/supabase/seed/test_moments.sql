-- Momentos de prueba (0034/0036) para los perfiles is_seed. Como historias: ~la mitad
-- de los perfiles tiene 1-3 Momentos de las últimas horas; algunos fijados más antiguos.
delete from public.moments where user_id in (select id from public.profiles where is_seed);

insert into public.moments (user_id, media, activity, area, happened_at, created_at, note, pinned)
select p.id,
       jsonb_build_object('kind','photo','url','https://picsum.photos/seed/m' || substr(md5(p.id::text || n), 1, 8) || '/900/1600','w',900,'h',1600),
       coalesce(p.sports[1 + (n - 1) % greatest(cardinality(p.sports), 1)], 'surf'),
       p.neighborhood,
       now() - make_interval(hours => n * 3 + (('x' || substr(md5(p.id::text || n), 5, 2))::bit(8)::int % 3)),
       now() - make_interval(hours => n * 3 + (('x' || substr(md5(p.id::text || n), 5, 2))::bit(8)::int % 3)),
       (array['Perfect conditions today 🌊', 'Leg day done', 'Sunset coffee after surf', null, 'Glassy and empty out there', null])
         [1 + (('x' || substr(md5(p.id::text || n), 9, 2))::bit(8)::int % 6)],
       false
  from public.profiles p
  cross join generate_series(1, 1 + (('x' || substr(md5(p.id::text), 1, 2))::bit(8)::int % 3)) n
 where p.is_seed and p.handle <> 'test.viewer'
   and (('x' || substr(md5(p.id::text), 3, 2))::bit(8)::int % 2) = 0;

-- Un Momento fijado antiguo para algunos (sigue en el perfil con anillo neutro).
insert into public.moments (user_id, media, activity, area, happened_at, created_at, note, pinned)
select p.id,
       jsonb_build_object('kind','photo','url','https://picsum.photos/seed/h' || substr(md5(p.id::text), 1, 8) || '/900/1600','w',900,'h',1600),
       coalesce(p.sports[1], 'surf'), p.neighborhood, now() - interval '6 days', now() - interval '6 days', 'One of those days.', true
  from public.profiles p
 where p.is_seed and p.handle <> 'test.viewer'
   and (('x' || substr(md5(p.id::text), 7, 2))::bit(8)::int % 3) = 0;
