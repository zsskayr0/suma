-- Suma - quinta migração: foto de perfil.
-- Rode isto no SQL Editor do Supabase (Project -> SQL Editor -> New query
-- -> cole tudo -> Run). Precisa que o Storage esteja habilitado no projeto
-- (vem habilitado por padrão).
--
-- Adiciona a coluna `avatar_url` em `profiles` e cria o bucket de Storage
-- "avatars": leitura pública (a foto só é útil se conseguir carregar sem
-- round-trip extra de auth), mas upload/edição/remoção só pelo próprio
-- dono do arquivo - cada foto vive em "<user_id>/avatar.<ext>", e a policy
-- confere que o primeiro pedaço do caminho é o uid de quem está logado.

alter table public.profiles add column if not exists avatar_url text;

grant update (avatar_url) on public.profiles to authenticated;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars_upload_own"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_update_own"
  on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_delete_own"
  on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
