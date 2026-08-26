-- Suma - quarta migração: tipo de meta (emagrecer/ganhar peso) + ponto de
-- partida da meta, pra barra de progresso parar de usar o primeiríssimo
-- registro histórico da pessoa (que pode ser de anos atrás e não tem nada
-- a ver com a meta atual) como referência.
-- Rode isto no SQL Editor do Supabase.

alter table public.profiles
  add column goal_type text not null default 'lose' check (goal_type in ('lose', 'gain')),
  add column goal_start_weight_kg numeric;

-- Autoriza o cliente a atualizar essas duas colunas novas (mesma restrição
-- de coluna criada na migração 003 - sem isso o UPDATE falharia em
-- silêncio, sem mudar nada).
grant update (goal_type, goal_start_weight_kg) on public.profiles to authenticated;
