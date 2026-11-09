-- Safar Planner Blog CMS migration
-- Run once in Supabase SQL Editor. Does not modify existing tables.
create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  excerpt text not null default '',
  content text not null default '',
  category text not null default 'General',
  author text not null default 'Safar Planner',
  cover_url text,
  read_time_min integer not null default 5 check (read_time_min between 1 and 120),
  is_featured boolean not null default false,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists blog_posts_published_idx on public.blog_posts (is_published, published_at desc);
create index if not exists blog_posts_slug_idx on public.blog_posts (slug);
alter table public.blog_posts enable row level security;
drop policy if exists "Anyone can read published blog posts" on public.blog_posts;
create policy "Anyone can read published blog posts" on public.blog_posts for select to anon, authenticated using (is_published = true);
drop policy if exists "Admins manage blog posts" on public.blog_posts;
create policy "Admins manage blog posts" on public.blog_posts for all to authenticated using (public.is_admin()) with check (public.is_admin());
