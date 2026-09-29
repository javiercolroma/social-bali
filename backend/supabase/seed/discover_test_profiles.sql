-- ─────────────────────────────────────────────────────────────────────────────
-- PERFILES DE PRUEBA para Discover (Fase 2). NO es una migración: vive fuera de
-- `migrations/` para que una reconstrucción del backend no los vuelva a meter.
--
-- 20 personas FICTICIAS de Bali, marcadas con `is_seed = true`. Idempotente.
-- Borrarlas antes de abrir a gente real (la cascada se lleva perfil, fecha y mazos):
--   delete from auth.users where id in (select id from public.profiles where is_seed);
-- ─────────────────────────────────────────────────────────────────────────────

-- Lena
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed01@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000001', date '1989-03-11')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000001', 'lena.waves', 'Lena', 'Sunrise surf → coffee → work. Always up for a padel game.', array['surf','padel','yoga']::text[], 'pererenan', 'Berlin', 'Alemania',
          'until', (public.bali_today() + 11), array['training','friends','dating']::text[], now() - interval '0 days', 62, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Mateo
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed02@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000002', 'mateo.bjj', 'Mateo', 'Rolling most evenings at the academy in Berawa. Looking for training partners.', array['bjj','gym','surf']::text[], 'berawa', 'Buenos Aires', 'Argentina',
          'livingHere', null, array['training','friends']::text[], now() - interval '1 days', 78, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Chloé
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed03@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000003', date '1991-03-13')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000003', 'chloe.flow', 'Chloé', 'Yoga teacher, reformer addict, bad surfer (improving).', array['yoga','pilates','surf']::text[], 'canggu', 'Lyon', 'Francia',
          'longTerm', null, array['friends','dating']::text[], now() - interval '2 days', 40, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Jack
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed04@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000004', 'jackruns', 'Jack', 'Training for the Bali marathon. Sunday long runs, anyone?', array['running','gym','cycling']::text[], 'canggu', 'Melbourne', 'Australia',
          'until', (public.bali_today() + 45), array['training']::text[], now() - interval '0 days', 85, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Sofia
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed05@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000005', 'sofi.moves', 'Sofia', 'Designer by day, muay thai by night.', array['muayThai','gym','dance']::text[], 'berawa', 'Lisbon', 'Portugal',
          'longTerm', null, array['training','friends']::text[], now() - interval '3 days', 55, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Noah
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed06@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000006', date '1994-03-16')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000006', 'noah.freedive', 'Noah', 'Freediving instructor in Amed on weekends, Uluwatu the rest.', array['freediving','surf','swimming']::text[], 'uluwatu', 'Amsterdam', 'Países Bajos',
          'livingHere', null, array['friends','dating']::text[], now() - interval '1 days', 48, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Aiko
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed07@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000007', 'aiko.climbs', 'Aiko', 'Climbing, hiking volcanoes, finding the best nasi campur.', array['climbing','hiking','yoga']::text[], 'ubud', 'Osaka', 'Japón',
          'until', (public.bali_today() + 20), array['friends']::text[], now() - interval '5 days', 33, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Lucas
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000008', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed08@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000008', date '1996-03-18')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000008', 'lucas.lifts', 'Lucas', 'Powerlifting + beach volleyball at sunset. New to Bali.', array['gym','beachVolleyball','crossfit']::text[], 'pererenan', 'São Paulo', 'Brasil',
          'until', (public.bali_today() + 60), array['training','friends','dating']::text[], now() - interval '0 days', 91, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Emma
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000009', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed09@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000009', 'emma.sea', 'Emma', 'Marine biologist. Surf at dawn, dive when the sea allows.', array['surf','freediving','swimming']::text[], 'bingin', 'Stockholm', 'Suecia',
          'longTerm', null, array['friends']::text[], now() - interval '2 days', 37, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Diego
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000010', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed10@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000010', 'diego.padel', 'Diego', 'Padel every evening in Berawa, need a fourth!', array['padel','tennis','gym']::text[], 'berawa', 'Madrid', 'España',
          'livingHere', null, array['training','friends']::text[], now() - interval '0 days', 70, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Maya
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000011', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed11@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000011', date '1990-03-21')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000011', 'maya.kite', 'Maya', 'Chasing wind in Sanur, working remote from anywhere.', array['kitesurf','surf','yoga']::text[], 'sanur', 'Tel Aviv', 'Israel',
          'until', (public.bali_today() + 9), array['friends','dating']::text[], now() - interval '4 days', 29, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Oliver
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000012', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed12@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000012', 'olly.cycles', 'Oliver', 'Early rides up to Bedugul. Coffee snob.', array['cycling','running','hiking']::text[], 'umalas', 'London', 'Reino Unido',
          'longTerm', null, array['training']::text[], now() - interval '1 days', 66, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Valentina
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000013', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed13@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000013', date '1992-03-23')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000013', 'vale.dance', 'Valentina', 'Salsa, pilates and slow mornings.', array['dance','pilates','yoga']::text[], 'seminyak', 'Bogotá', 'Colombia',
          'until', (public.bali_today() + 30), array['friends','dating']::text[], now() - interval '6 days', 22, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Kai
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000014', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed14@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000014', 'kai.skate', 'Kai', 'Skating the bowls in Canggu, surfing when it''s small.', array['skate','surf','running']::text[], 'canggu', 'San Diego', 'Estados Unidos',
          'livingHere', null, array['friends']::text[], now() - interval '0 days', 58, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Isabella
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000015', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed15@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000015', 'bella.hybrid', 'Isabella', 'Hyrox training block. Accountability buddies welcome.', array['crossfit','running','gym']::text[], 'pererenan', 'Milan', 'Italia',
          'until', (public.bali_today() + 4), array['training','friends']::text[], now() - interval '0 days', 88, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Tom
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000016', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed16@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000016', date '1995-03-26')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000016', 'tom.wanders', 'Tom', 'Here for a few months, mostly surfing Bingin and eating.', array['surf','hiking','football']::text[], 'bingin', 'Toronto', 'Canadá',
          'longTerm', null, array['friends','dating']::text[], now() - interval '8 days', 18, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Putu
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000017', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed17@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000017', 'putu.surf', 'Putu', 'Born in Uluwatu. Surf coach, happy to show you the breaks.', array['surf','football','swimming']::text[], 'uluwatu', 'Denpasar', 'Indonesia',
          'livingHere', null, array['training','friends']::text[], now() - interval '0 days', 74, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Nora
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000018', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed18@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000018', 'nora.yin', 'Nora', 'Yin yoga, sound baths and the occasional 10k.', array['yoga','running','pilates']::text[], 'ubud', 'Copenhagen', 'Dinamarca',
          'until', (public.bali_today() + 16), array['friends']::text[], now() - interval '3 days', 30, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Rafael
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000019', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed19@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000019', 'rafa.boxing', 'Rafael', 'Boxing coach looking for sparring partners in Canggu.', array['boxing','muayThai','gym']::text[], 'canggu', 'Mexico City', 'México',
          'longTerm', null, array['training']::text[], now() - interval '1 days', 81, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;

-- Camille
insert into auth.users(id, instance_id, aud, role, email)
  values ('5eed0000-0000-4000-8000-000000000020', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed20@forgeloop.test')
  on conflict (id) do nothing;
insert into public.profile_private(id, birthdate) values ('5eed0000-0000-4000-8000-000000000020', date '1990-03-30')
  on conflict (id) do update set birthdate = excluded.birthdate;
insert into public.profiles(id, handle, name, bio, sports, neighborhood, home_city, home_country,
                            stay_kind, stay_until, intents, active_at, gym_score, is_seed)
  values ('5eed0000-0000-4000-8000-000000000020', 'cami.golf', 'Camille', 'Golf at Nirwana, beach club after. Opposites attract.', array['golf','tennis','swimming']::text[], 'pecatu', 'Paris', 'Francia',
          'until', (public.bali_today() + 25), array['friends','dating']::text[], now() - interval '2 days', 44, true)
  on conflict (id) do update set handle = excluded.handle, name = excluded.name, bio = excluded.bio,
    sports = excluded.sports, neighborhood = excluded.neighborhood, home_city = excluded.home_city,
    home_country = excluded.home_country, stay_kind = excluded.stay_kind, stay_until = excluded.stay_until,
    intents = excluded.intents, active_at = excluded.active_at, gym_score = excluded.gym_score, is_seed = true;
