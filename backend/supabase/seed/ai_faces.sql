-- Caras generadas por IA (thispersondoesnotexist.com) como foto principal de los perfiles de prueba.
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/aiko.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/aiko.jpg'
 where is_seed and name = 'Aiko';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/camille.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/camille.jpg'
 where is_seed and name = 'Camille';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/chloe.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/chloe.jpg'
 where is_seed and name = 'Chloé';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/emma.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/emma.jpg'
 where is_seed and name = 'Emma';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/isabella.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/isabella.jpg'
 where is_seed and name = 'Isabella';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/lena.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/lena.jpg'
 where is_seed and name = 'Lena';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/maya.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/maya.jpg'
 where is_seed and name = 'Maya';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/nora.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/nora.jpg'
 where is_seed and name = 'Nora';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/sofia.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/sofia.jpg'
 where is_seed and name = 'Sofia';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/valentina.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/valentina.jpg'
 where is_seed and name = 'Valentina';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/diego.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/diego.jpg'
 where is_seed and name = 'Diego';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/jack.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/jack.jpg'
 where is_seed and name = 'Jack';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/kai.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/kai.jpg'
 where is_seed and name = 'Kai';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/lucas.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/lucas.jpg'
 where is_seed and name = 'Lucas';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/mateo.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/mateo.jpg'
 where is_seed and name = 'Mateo';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/noah.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/noah.jpg'
 where is_seed and name = 'Noah';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/oliver.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/oliver.jpg'
 where is_seed and name = 'Oliver';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/putu.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/putu.jpg'
 where is_seed and name = 'Putu';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/rafael.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/rafael.jpg'
 where is_seed and name = 'Rafael';
update public.profiles set
  media = jsonb_build_array(jsonb_build_object('kind','photo','url','https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/tom.jpg','w',800,'h',1000)) || coalesce((select jsonb_agg(e) from jsonb_array_elements(media) e where e->>'url' not like '%/object/public/media/%'), '[]'::jsonb),
  avatar_url = 'https://tmwgcvnibyvxedpqjqkr.supabase.co/storage/v1/object/public/media/5eed0000-0000-4000-8000-0000000000aa/seed/tom.jpg'
 where is_seed and name = 'Tom';
