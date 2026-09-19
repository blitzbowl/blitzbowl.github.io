-- Blitz Bowl · online leaderboard + ranked matchmaking
-- Run in the Supabase SQL editor, or: supabase db push

create table if not exists public.profiles (
  client_id   text primary key,
  team        text not null,
  coach       text,
  color       text,
  rp          integer not null default 0,
  wins        integer not null default 0,
  losses      integer not null default 0,
  tier        text    not null default 'Bronze',
  squad       jsonb   not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);

create index if not exists profiles_rp_idx on public.profiles (rp desc);

alter table public.profiles enable row level security;

-- the board is public to read
create policy "read all profiles"
  on public.profiles for select
  using (true);

-- anyone may claim an unused client_id and keep updating that one row.
-- client_id is a random string the game generates and keeps in localStorage.
create policy "insert own profile"
  on public.profiles for insert
  with check (true);

create policy "update own profile"
  on public.profiles for update
  using (true)
  with check (true);

-- NOTE: this is deliberately open, which suits a game where the only stored
-- data is a team name and a made-up roster. If it ever holds anything real,
-- switch to Supabase anonymous auth and scope these policies to auth.uid().
