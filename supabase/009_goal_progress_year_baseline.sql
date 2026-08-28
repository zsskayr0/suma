-- Suma - nona migração: o progresso da meta (ranking "Mais perto da meta"
-- em Usuários) passa a ser medido sempre contra o peso de exatamente um
-- ano atrás, em vez do snapshot fixo de quando a meta foi definida -
-- mesma mudança já feita no cálculo do app (card de meta do Hoje). Rode
-- isto no SQL Editor do Supabase.

create or replace function public.family_goal_progress()
returns table(member_id uuid, member_name text, progress numeric)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  fam uuid := public.my_family_id();
  rec record;
  start_kg numeric;
  current_kg numeric;
  total_delta numeric;
  done_delta numeric;
  remaining numeric;
begin
  if fam is null then
    return;
  end if;

  for rec in
    select p.id, p.name, p.goal_weight_kg
    from public.profiles p
    where p.family_id = fam and p.goal_weight_kg is not null
  loop
    select e.weight_kg into current_kg from public.weight_entries e where e.user_id = rec.id order by e.date desc limit 1;
    if current_kg is null then
      continue; -- sem nenhum registro ainda, nada pra ranquear
    end if;

    -- Entrada mais recente que ainda cai em ou antes de 365 dias atrás -
    -- mesma lógica do goalBaselineWeightKg() no Dart. Sem uma entrada tão
    -- antiga assim, usa a mais antiga disponível.
    select e.weight_kg into start_kg
      from public.weight_entries e
      where e.user_id = rec.id and e.date <= (current_date - 365)
      order by e.date desc
      limit 1;
    if start_kg is null then
      select e.weight_kg into start_kg from public.weight_entries e where e.user_id = rec.id order by e.date asc limit 1;
    end if;

    total_delta := rec.goal_weight_kg - start_kg;
    done_delta := current_kg - start_kg;
    remaining := abs(rec.goal_weight_kg - current_kg);

    member_id := rec.id;
    member_name := rec.name;
    if abs(total_delta) < 0.05 then
      progress := case when remaining < 0.05 then 1.0 else 0.0 end;
    else
      progress := greatest(0.0, least(1.0, done_delta / total_delta));
    end if;
    return next;
  end loop;
end;
$$;

grant execute on function public.family_goal_progress() to authenticated;
