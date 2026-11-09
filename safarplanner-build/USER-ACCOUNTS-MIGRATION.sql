-- Safar Planner customer accounts, personal trips, rewards and savings
-- Run once in Supabase SQL Editor. Does not delete or replace existing data.
create extension if not exists pgcrypto;

create table if not exists public.customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  phone text,
  city text,
  avatar_url text,
  account_status text not null default 'active' check (account_status in ('active','suspended')),
  savings_total numeric not null default 0 check (savings_total >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  destination_name text not null,
  start_date date,
  end_date date,
  travellers integer not null default 1,
  budget numeric,
  estimated_cost numeric,
  status text not null default 'planned' check (status in ('planned','upcoming','confirmed','completed','cancelled')),
  itinerary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reward_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  points integer not null,
  reason text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.customer_profiles add column if not exists email text;
alter table public.bookings add column if not exists user_id uuid references auth.users(id) on delete set null;

-- Create a customer profile automatically for every new signup.
create or replace function public.handle_new_customer_signup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.customer_profiles(user_id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.email)
  on conflict (user_id) do nothing;
  insert into public.profiles(id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), 'customer')
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_customer on auth.users;
create trigger on_auth_user_created_customer after insert on auth.users
for each row execute procedure public.handle_new_customer_signup();

alter table public.customer_profiles enable row level security;
alter table public.user_trips enable row level security;
alter table public.reward_transactions enable row level security;

drop policy if exists "Customers read own profile" on public.customer_profiles;
create policy "Customers read own profile" on public.customer_profiles for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Customers update own profile" on public.customer_profiles;
create policy "Customers update own profile" on public.customer_profiles for update to authenticated using (auth.uid() = user_id and account_status = 'active') with check (auth.uid() = user_id);
drop policy if exists "Admins manage customer profiles" on public.customer_profiles;
create policy "Admins manage customer profiles" on public.customer_profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Customers manage own trips" on public.user_trips;
create policy "Customers manage own trips" on public.user_trips for all to authenticated using (auth.uid() = user_id and exists(select 1 from public.customer_profiles cp where cp.user_id=auth.uid() and cp.account_status='active')) with check (auth.uid() = user_id and exists(select 1 from public.customer_profiles cp where cp.user_id=auth.uid() and cp.account_status='active'));
drop policy if exists "Admins manage customer trips" on public.user_trips;
create policy "Admins manage customer trips" on public.user_trips for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Customers read own rewards" on public.reward_transactions;
create policy "Customers read own rewards" on public.reward_transactions for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Admins manage rewards" on public.reward_transactions;
create policy "Admins manage rewards" on public.reward_transactions for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Customers read own bookings" on public.bookings;
create policy "Customers read own bookings" on public.bookings for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Customers create own bookings" on public.bookings;
create policy "Customers create own bookings" on public.bookings for insert to authenticated with check (auth.uid() = user_id);

create index if not exists user_trips_user_date_idx on public.user_trips(user_id,start_date);
create index if not exists reward_transactions_user_idx on public.reward_transactions(user_id,created_at desc);
create index if not exists bookings_user_idx on public.bookings(user_id,created_at desc);

-- Prevent customers from editing admin-controlled account status or savings.
create or replace function public.protect_customer_account_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() = old.user_id and not public.is_admin() then
    new.account_status := old.account_status;
    new.savings_total := old.savings_total;
  end if;
  return new;
end;
$$;
drop trigger if exists protect_customer_account_fields_trigger on public.customer_profiles;
create trigger protect_customer_account_fields_trigger before update on public.customer_profiles
for each row execute function public.protect_customer_account_fields();
