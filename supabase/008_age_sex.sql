-- Suma - oitava migração: idade e sexo no perfil (tela de Altura). Rode
-- isto no SQL Editor do Supabase.

alter table public.profiles add column if not exists age integer;
alter table public.profiles add column if not exists sex text check (sex in ('male', 'female', 'unspecified'));

grant update (age, sex) on public.profiles to authenticated;
