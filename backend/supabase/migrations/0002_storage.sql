-- Forge Loop — buckets de Storage para fotos (avatares y fotos de entreno)
-- Ejecuta después de 0001_init.sql.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('session-photos', 'session-photos', true)
on conflict (id) do nothing;

-- Lectura pública (los buckets son públicos: las URLs de avatar/foto se muestran en el feed).
drop policy if exists "public read avatars" on storage.objects;
create policy "public read avatars" on storage.objects for select
  using (bucket_id in ('avatars', 'session-photos'));

-- Subida/borrado: cada usuario gestiona SOLO los archivos bajo su carpeta `<uid>/…`.
drop policy if exists "own write avatars" on storage.objects;
create policy "own write avatars" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars','session-photos') and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "own update avatars" on storage.objects;
create policy "own update avatars" on storage.objects for update to authenticated
  using (bucket_id in ('avatars','session-photos') and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "own delete avatars" on storage.objects;
create policy "own delete avatars" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars','session-photos') and (storage.foldername(name))[1] = auth.uid()::text);
