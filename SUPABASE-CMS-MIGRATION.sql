
-- SAFAR PLANNER: destination content CMS migration
-- Run once in Supabase SQL Editor. Existing destinations/bookings tables are preserved.
create extension if not exists pgcrypto;

create table if not exists public.destination_places (
 id uuid primary key default gen_random_uuid(), destination_id uuid not null references public.destinations(id) on delete cascade,
 name text not null, category text, description text, entry_fee numeric, opening_hours text, visit_duration text,
 address text, map_url text, image_urls text[] default '{}', tips text, sort_order int default 0, is_published boolean default true,
 created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.destination_food (
 id uuid primary key default gen_random_uuid(), destination_id uuid not null references public.destinations(id) on delete cascade,
 name text not null, cuisine text, description text, price_min numeric, price_max numeric, must_try text,
 address text, contact text, map_url text, image_urls text[] default '{}', meal_type text, sort_order int default 0,
 is_published boolean default true, created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.destination_stays (
 id uuid primary key default gen_random_uuid(), destination_id uuid not null references public.destinations(id) on delete cascade,
 name text not null, stay_type text, description text, price_min numeric, price_max numeric, facilities text,
 address text, contact text, booking_url text, map_url text, image_urls text[] default '{}', sort_order int default 0,
 is_published boolean default true, created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.destination_transport (
 id uuid primary key default gen_random_uuid(), destination_id uuid not null references public.destinations(id) on delete cascade,
 name text not null, transport_type text, description text, fare_min numeric, fare_max numeric, route text,
 duration text, contact text, booking_url text, image_urls text[] default '{}', sort_order int default 0,
 is_published boolean default true, created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.destination_itineraries (
 id uuid primary key default gen_random_uuid(), destination_id uuid not null references public.destinations(id) on delete cascade,
 title text not null, day_number int default 1, start_time text, end_time text, description text, place_name text,
 estimated_cost numeric, notes text, image_urls text[] default '{}', sort_order int default 0, is_published boolean default true,
 created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.destination_travel_options (
 id uuid primary key default gen_random_uuid(), destination_id uuid not null references public.destinations(id) on delete cascade,
 mode text not null, origin text, details text, typical_fare_min numeric, typical_fare_max numeric, duration text,
 provider_name text, booking_url text, is_live boolean default false, sort_order int default 0, is_published boolean default true,
 created_at timestamptz default now(), updated_at timestamptz default now()
);

do $$ declare t text; begin
 foreach t in array array['destination_places','destination_food','destination_stays','destination_transport','destination_itineraries','destination_travel_options'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists "Public can read published destination content" on public.%I',t);
  execute format('create policy "Public can read published destination content" on public.%I for select using (is_published = true)',t);
  execute format('drop policy if exists "Admins manage destination content" on public.%I',t);
  execute format('create policy "Admins manage destination content" on public.%I for all using (public.is_admin()) with check (public.is_admin())',t);
 end loop;
end $$;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('destination-media','destination-media',true,10485760,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set public=true;

drop policy if exists "Public read destination media" on storage.objects;
create policy "Public read destination media" on storage.objects for select using (bucket_id='destination-media');
drop policy if exists "Admins upload destination media" on storage.objects;
create policy "Admins upload destination media" on storage.objects for insert with check (bucket_id='destination-media' and public.is_admin());
drop policy if exists "Admins update destination media" on storage.objects;
create policy "Admins update destination media" on storage.objects for update using (bucket_id='destination-media' and public.is_admin()) with check (bucket_id='destination-media' and public.is_admin());
drop policy if exists "Admins delete destination media" on storage.objects;
create policy "Admins delete destination media" on storage.objects for delete using (bucket_id='destination-media' and public.is_admin());
