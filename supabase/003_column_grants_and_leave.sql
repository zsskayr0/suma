-- Suma - terceira migração: fecha uma falha de segurança e adiciona a
-- função de "sair da rede". Rode isto no SQL Editor do Supabase.
--
-- Falha: a policy "profiles_update_self" permitia UPDATE em QUALQUER
-- coluna da própria linha, inclusive `role` e `family_id` - ou seja,
-- qualquer membro podia se autopromover a admin (`role = 'admin'`) e
-- passar a enxergar o peso de todo mundo da rede via
-- "entries_select_family_admin" / "profiles_select_self_or_family_admin".
-- Isso contraria a regra de privacidade escolhida ("só o admin vê tudo").
--
-- Correção: restringe, a nível de coluna (GRANT), quais campos o cliente
-- pode alterar direto via UPDATE. `role` e `family_id` passam a só mudar
-- através das funções SECURITY DEFINER (create_family,
-- join_family_by_code, remove_member_from_family, leave_family), que já
-- validam a autorização corretamente.

revoke update on public.profiles from authenticated;
grant update (name, height_cm, goal_weight_kg, unit_pref, theme_pref, onboarded)
  on public.profiles to authenticated;

-- Deixa um membro sair da própria rede (equivalente "self-service" do
-- remove_member_from_family, que só o admin pode usar sobre outros).
create or replace function public.leave_family()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set family_id = null, role = 'admin' where id = auth.uid();
end;
$$;
