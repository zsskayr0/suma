-- Suma - décima migração: subperfis de pet. Cada usuário pode cadastrar até
-- 3 pets (nome, data de nascimento, espécie, raça) com seu próprio
-- histórico de peso, totalmente separado do histórico humano do dono - os
-- dados nunca se misturam, só compartilham a mesma conta como "dono".
--
-- Privacidade: dono tem CRUD completo sobre seus próprios pets/registros.
-- O admin da rede familiar pode VER (nunca editar/excluir) os pets e
-- registros de qualquer membro da rede - mesma regra já aplicada a
-- weight_entries. Um membro comum só vê os próprios pets (não os de
-- outros membros), mesmo sendo da mesma rede.
--
-- Rode isto no SQL Editor do Supabase, depois de 000_schema.sql.

create table public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  birth_date date,
  species text not null,
  breed text,
  created_at timestamptz not null default now()
);

create table public.pet_weight_entries (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  date date not null,
  weight_kg numeric not null,
  notes text,
  created_at timestamptz not null default now(),
  unique (pet_id, date)
);

alter table public.pets enable row level security;
alter table public.pet_weight_entries enable row level security;

-- ---------------------------------------------------------------------
-- pets
-- ---------------------------------------------------------------------

create policy "pets_all_own"
  on public.pets for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Only the family *admin* sees other members' pets - a regular member's
-- visibility never extends past their own (the "pets_all_own" policy
-- above already covers that on its own, so there's no separate
-- "members see each other's pets" policy at all).
create policy "pets_select_family_admin"
  on public.pets for select
  using (
    public.my_role() = 'admin'
    and public.my_family_id() is not null
    and public.my_family_id() = public.profile_family_id(pets.owner_id)
  );

-- Enforced server-side too, not just in the app's UI - "até 3 pets" should
-- hold even against a direct API call.
create or replace function public.enforce_pet_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.pets where owner_id = new.owner_id) >= 3 then
    raise exception 'Você já tem o máximo de 3 pets cadastrados.';
  end if;
  return new;
end;
$$;

create trigger pets_limit_check
  before insert on public.pets
  for each row execute function public.enforce_pet_limit();

-- ---------------------------------------------------------------------
-- pet_weight_entries - same shape/policy pair as weight_entries, just
-- keyed by pet_id (via pets.owner_id) instead of user_id directly.
-- ---------------------------------------------------------------------

create policy "pet_entries_all_own"
  on public.pet_weight_entries for all
  using (exists (select 1 from public.pets p where p.id = pet_weight_entries.pet_id and p.owner_id = auth.uid()))
  with check (exists (select 1 from public.pets p where p.id = pet_weight_entries.pet_id and p.owner_id = auth.uid()));

create policy "pet_entries_select_family_admin"
  on public.pet_weight_entries for select
  using (
    public.my_role() = 'admin'
    and public.my_family_id() is not null
    and exists (
      select 1 from public.pets p
      where p.id = pet_weight_entries.pet_id
        and public.my_family_id() = public.profile_family_id(p.owner_id)
    )
  );
