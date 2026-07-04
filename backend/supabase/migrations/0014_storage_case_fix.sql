-- BUG cazado en dispositivo real: las políticas de Storage comparaban la carpeta con
-- auth.uid()::text (minúsculas) y Swift sube a uid.uuidString (MAYÚSCULAS) → TODAS las
-- subidas de fotos desde la app fallaban en silencio. Doble arreglo: políticas
-- insensibles a mayúsculas (aquí) + el cliente ahora usa carpeta en minúsculas.
drop policy if exists "own write avatars" on storage.objects;
create policy "own write avatars" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars','session-photos') and lower((storage.foldername(name))[1]) = auth.uid()::text);
drop policy if exists "own update avatars" on storage.objects;
create policy "own update avatars" on storage.objects for update to authenticated
  using (bucket_id in ('avatars','session-photos') and lower((storage.foldername(name))[1]) = auth.uid()::text);
drop policy if exists "own delete avatars" on storage.objects;
create policy "own delete avatars" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars','session-photos') and lower((storage.foldername(name))[1]) = auth.uid()::text);
