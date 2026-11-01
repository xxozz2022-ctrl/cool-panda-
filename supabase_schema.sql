-- Run this in Supabase > SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 email text,
 role text not null default 'user' check (role in ('user','admin')),
 welcome_message text not null default 'أهلاً بيك في Cool Panda',
 created_at timestamptz not null default now()
);
create table if not exists public.accounts (
 id uuid primary key default gen_random_uuid(),
 username text not null unique,
 url text not null,
 coins bigint not null default 0,
 created_at timestamptz not null default now()
);
create table if not exists public.visits (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 account_id uuid not null references public.accounts(id) on delete cascade,
 contacted boolean not null default false,
 visited_at timestamptz not null default now(),
 unique(user_id,account_id)
);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,email) values(new.id,new.email); return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
alter table public.profiles enable row level security;
alter table public.accounts enable row level security;
alter table public.visits enable row level security;
drop policy if exists "profile read own" on public.profiles;
create policy "profile read own" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
drop policy if exists "profile update own" on public.profiles;
create policy "profile update own" on public.profiles for update to authenticated using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());
drop policy if exists "accounts read authenticated" on public.accounts;
create policy "accounts read authenticated" on public.accounts for select to authenticated using(true);
drop policy if exists "accounts admin write" on public.accounts;
create policy "accounts admin write" on public.accounts for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "visits own read" on public.visits;
create policy "visits own read" on public.visits for select to authenticated using(user_id=auth.uid() or public.is_admin());
drop policy if exists "visits own insert" on public.visits;
create policy "visits own insert" on public.visits for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "visits own update" on public.visits;
create policy "visits own update" on public.visits for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
-- After creating your own account, promote ONLY your account to admin:
-- update public.profiles set role='admin' where email='YOUR_LOGIN_EMAIL';
