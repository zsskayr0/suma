-- Suma - sexta migração: a aba "Usuários" passa a ser visível pra qualquer
-- membro da rede, não só pro admin. Rode isto no SQL Editor do Supabase.
--
-- Antes, um membro comum não conseguia nem carregar a lista de nomes dos
-- outros (a policy de SELECT em `profiles` exigia ser admin). Isso não
-- muda a regra de privacidade dos PESOS - só o admin continua podendo ler
-- `weight_entries` de outra pessoa (policy "entries_select_family_admin",
-- inalterada). Um membro comum passa a ver quem está na rede (nome, foto,
-- papel) mas não os registros/meta de ninguém além de si mesmo.

drop policy if exists "profiles_select_self_or_family_admin" on public.profiles;

create policy "profiles_select_self_or_family_member"
  on public.profiles for select
  using (
    id = auth.uid()
    or (family_id is not null and family_id = public.my_family_id())
  );
