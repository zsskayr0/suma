-- Suma - schema for cross-device "rede familiar" accounts.
--
-- Run this once in your Supabase project's SQL Editor (Project ->
-- SQL Editor -> New query -> paste this whole file -> Run). It is
-- idempotent-ish for a fresh project but not meant to be re-run after
-- you already have data - if you need to change something later, add a
-- new migration file instead of editing this one.
--
-- Model:
--   auth.users        Supabase's built-in auth table (email + password).
--   public.families    One row per "rede familiar" (household), with a
--                       short invite_code used to join it from another
--                       device/account.
--   public.profiles    One row per person, 1:1 with an auth.users row.
--                       Holds the same per-user preferences Suma already
--                       tracks locally (height, goal, unit, theme, ...).
--                       role is 'admin' (created the family, or was made
--                       admin) or 'member'.
--   public.weight_entries  One row per logged measurement, always owned
--                       by exactly one profile.
--
-- Privacy (per your choice): every user only ever writes their own
-- entries. A family's admin can additionally *read* (never edit/delete)
-- the entries of every member in their own family - matching what the
-- local-only version of Suma already did with "Usuários" + CSV export.

create extension if not exists pgcrypto;

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  family_id uuid references public.families (id) on delete set null,
  name text not null,
  role text not null default 'admin' check (role in ('admin', 'member')),
  height_cm numeric,
  goal_weight_kg numeric,
  goal_type text not null default 'lose' check (goal_type in ('lose', 'gain')),
  goal_start_weight_kg numeric,
  unit_pref text not null default 'kg' check (unit_pref in ('kg', 'lb')),
  theme_pref text not null default 'system' check (theme_pref in ('system', 'light', 'dark')),
  onboarded boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  date date not null,
  weight_kg numeric not null,
  body_fat_pct numeric,
  hydration_pct numeric,
  notes text,
  created_at timestamptz not null default now(),
  unique (user_id, date)
);

alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.weight_entries enable row level security;

-- ---------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER: bypass RLS internally). Policies
-- on `profiles` must never query `profiles` directly in their own USING
-- clause - Postgres detects that as infinite recursion. Going through
-- these functions instead avoids it.
-- ---------------------------------------------------------------------

create or replace function public.my_family_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select family_id from public.profiles where id = auth.uid();
$$;

create or replace function public.my_role()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.profile_family_id(uid uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select family_id from public.profiles where id = uid;
$$;

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------

create policy "profiles_select_self_or_family_admin"
  on public.profiles for select
  using (
    id = auth.uid()
    or (
      family_id is not null
      and family_id = public.my_family_id()
      and public.my_role() = 'admin'
    )
  );

create policy "profiles_insert_self"
  on public.profiles for insert
  with check (id = auth.uid());

create policy "profiles_update_self"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- The policy above only restricts *which row* can be updated, not which
-- columns - without this, any member could set their own `role` to
-- 'admin' and read the rest of the family's data. `family_id`/`role`
-- must only ever change through the SECURITY DEFINER RPCs below, which
-- validate authorization properly.
revoke update on public.profiles from authenticated;
grant update (name, height_cm, goal_weight_kg, goal_type, goal_start_weight_kg, unit_pref, theme_pref, onboarded)
  on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- families
-- ---------------------------------------------------------------------

create policy "families_select_members"
  on public.families for select
  using (id = public.my_family_id());

create policy "families_insert_self"
  on public.families for insert
  with check (created_by = auth.uid());

-- ---------------------------------------------------------------------
-- weight_entries
-- ---------------------------------------------------------------------

create policy "entries_all_own"
  on public.weight_entries for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "entries_select_family_admin"
  on public.weight_entries for select
  using (
    public.my_role() = 'admin'
    and public.my_family_id() is not null
    and public.my_family_id() = public.profile_family_id(weight_entries.user_id)
  );

-- ---------------------------------------------------------------------
-- RPCs used by the app's "criar minha rede" / "entrar com código" flows.
-- ---------------------------------------------------------------------

-- Creates a brand-new family, owned by the caller, who becomes its admin.
-- Returns the new family's invite code so the app can show it right away.
create or replace function public.create_family(family_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_family_id uuid;
  new_code text;
begin
  new_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.families (name, invite_code, created_by)
    values (family_name, new_code, auth.uid())
    returning id into new_family_id;

  update public.profiles
    set family_id = new_family_id, role = 'admin'
    where id = auth.uid();

  return new_code;
end;
$$;

-- Joins the caller into an existing family by its invite code. The
-- caller becomes a regular 'member' (never overwrites an existing
-- admin). Raises a clear error if the code doesn't exist.
create or replace function public.join_family_by_code(code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_id uuid;
begin
  select id into target_family_id from public.families where invite_code = upper(code);

  if target_family_id is null then
    raise exception 'Código de convite inválido.';
  end if;

  update public.profiles
    set family_id = target_family_id, role = 'member'
    where id = auth.uid();

  return target_family_id;
end;
$$;

-- Lets a family's admin remove a member from the family (the member's
-- own account/data is untouched - they just stop being part of the
-- network and become the sole admin of their own, unlinked profile).
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

-- Lets a member leave their own family (self-service version of
-- remove_member_from_family, which only an admin can use on others).
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

-- Every new auth.users row needs a matching profiles row. This trigger
-- creates a minimal one automatically right after sign-up (name comes
-- from the "name" field passed as user metadata during signUp); the app
-- fills in the rest during onboarding.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'name', 'Usuário'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
