-- Momentos de prueba (0034) para los perfiles is_seed: 2-4 por persona según sus
-- deportes; algunos de HOY (etiqueta «SURF TODAY» en el Circle) y 1-2 fijados.
delete from public.moments where user_id in (select id from public.profiles where is_seed);

insert into public.moments (user_id, media, title, activity, area, happened_at, note, pinned)
select p.id,
       jsonb_build_object('kind','photo','url','https://picsum.photos/seed/m' || substr(md5(p.id::text || n), 1, 8) || '/800/1000','w',800,'h',1000),
       (array['Dawn patrol','Leg day','Sunset run','Morning flow','After-work padel','Coffee & laptop','Golden hour','Beach session'])
         [1 + (('x' || substr(md5(p.id::text || n), 9, 2))::bit(8)::int % 8)],
       coalesce(p.sports[1 + (n - 1) % greatest(cardinality(p.sports), 1)], 'surf'),
       p.neighborhood,
       case when n = 1 and (('x' || substr(md5(p.id::text), 3, 2))::bit(8)::int % 2) = 0
            then now() - interval '2 hours'
            else now() - make_interval(days => n * 2 + (('x' || substr(md5(p.id::text || n), 5, 2))::bit(8)::int % 3)) end,
       case when n = 1 then 'Glassy and empty out there.' end,
       n <= 2 and (('x' || substr(md5(p.id::text), 7, 2))::bit(8)::int % 2) = 0
  from public.profiles p
  cross join generate_series(1, 2 + (('x' || substr(md5(p.id::text), 1, 2))::bit(8)::int % 3)) n
 where p.is_seed and p.handle <> 'test.viewer';
