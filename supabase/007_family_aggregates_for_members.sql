-- Suma - sétima migração: "Mais perto da meta", o heatmap e a contagem de
-- registros por membro passam a valer pra qualquer pessoa da rede, não só
-- pro admin - mas SEM abrir o peso bruto de ninguém. Rode isto no SQL
-- Editor do Supabase.
--
-- Em vez de relaxar a policy de SELECT em `weight_entries` (o que deixaria
-- qualquer membro ler o peso exato de todo mundo direto pela API, não só
-- pela tela), essas três funções SECURITY DEFINER calculam só o que é
-- seguro mostrar - porcentagem de progresso da meta e contagens - e nunca
-- devolvem `weight_kg`/`date` linha a linha. `entries_select_family_admin`
-- continua intacta: só o admin lê os registros crus (usado pra exportar
-- CSV e editar/remover membro).

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
    select p.id, p.name, p.goal_weight_kg, p.goal_start_weight_kg
    from public.profiles p
    where p.family_id = fam and p.goal_weight_kg is not null
  loop
    select e.weight_kg into current_kg from public.weight_entries e where e.user_id = rec.id order by e.date desc limit 1;
    if current_kg is null then
      continue; -- sem nenhum registro ainda, nada pra ranquear
    end if;

    start_kg := rec.goal_start_weight_kg;
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

create or replace function public.family_contribution_counts(days int default 126)
returns table(entry_date date, cnt bigint)
language sql
security definer
set search_path = public
stable
as $$
  select e.date, count(*)::bigint
  from public.weight_entries e
  join public.profiles p on p.id = e.user_id
  where p.family_id = public.my_family_id()
    and e.date >= (current_date - days)
  group by e.date;
$$;

grant execute on function public.family_contribution_counts(int) to authenticated;

create or replace function public.family_entry_counts(days int default 60)
returns table(member_id uuid, total_count bigint, recent_count bigint)
language sql
security definer
set search_path = public
stable
as $$
  select
    p.id,
    count(e.id) as total_count,
    count(e.id) filter (where e.date >= (current_date - days)) as recent_count
  from public.profiles p
  left join public.weight_entries e on e.user_id = p.id
  where p.family_id = public.my_family_id()
  group by p.id;
$$;

grant execute on function public.family_entry_counts(int) to authenticated;
