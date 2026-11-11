-- Baseline: the schema as it already exists in the live project (created in
-- the dashboard before migrations were tracked). Every statement is
-- "if not exists" so running it against the live database changes nothing;
-- on a fresh project it rebuilds the original three tables.

create table if not exists public.profiles (
  id               uuid primary key references auth.users (id),
  full_name        text,
  email            text,
  goal             text,
  created_at       timestamptz default now(),
  gender           text,
  age              integer,
  height_cm        double precision,
  weight_kg        double precision,
  experience_level text,
  updated_at       timestamptz
);

-- One row per user: the active plan as Gemini's JSON (plus user edits).
create table if not exists public.plans (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null unique references auth.users (id) on delete cascade,
  plan_json     jsonb,
  exercise_name text,
  created_at    timestamptz default now()
);

-- One row per finished workout; per-set metrics live in session_data.
create table if not exists public.workout_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  exercise_type  text not null,
  sets_completed integer,
  session_data   jsonb,
  created_at     timestamptz default now()
);

alter table public.profiles         enable row level security;
alter table public.plans            enable row level security;
alter table public.workout_sessions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'profiles' and policyname = 'Users manage own profile') then
    create policy "Users manage own profile" on public.profiles
      for all using (auth.uid() = id) with check (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies
                 where tablename = 'plans' and policyname = 'Users can manage own plan') then
    create policy "Users can manage own plan" on public.plans
      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies
                 where tablename = 'workout_sessions' and policyname = 'Users can insert own sessions') then
    create policy "Users can insert own sessions" on public.workout_sessions
      for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies
                 where tablename = 'workout_sessions' and policyname = 'Users can select own sessions') then
    create policy "Users can select own sessions" on public.workout_sessions
      for select using (auth.uid() = user_id);
  end if;
end $$;
