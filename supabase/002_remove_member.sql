-- Suma - segunda migração: função que faltou no schema.sql inicial.
-- Rode isto no SQL Editor do Supabase (mesmo processo do schema.sql).
--
-- Permite que o admin de uma rede familiar remova um membro (o membro
-- continua com a própria conta/dados, só deixa de fazer parte da rede
-- e vira admin da própria conta sozinho - nada é deletado).

create or replace function public.remove_member_from_family(member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.my_role() != 'admin' then
    raise exception 'Apenas administradores podem remover membros.';
  end if;

  if public.profile_family_id(member_id) is distinct from public.my_family_id() then
    raise exception 'Esse usuário não faz parte da sua rede.';
  end if;

  if member_id = auth.uid() then
    raise exception 'Você não pode remover a si mesmo. Se quiser sair da rede, peça para outro admin.';
  end if;

  update public.profiles set family_id = null, role = 'admin' where id = member_id;
end;
$$;
