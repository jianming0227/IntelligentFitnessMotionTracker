-- plan_sessions: one row per planned workout, with a real date.
--
-- The app still keeps the whole plan as JSON in public.plans (it draws the
-- Schedule from it). Every time the plan is saved, the app mirrors each card
-- here so the database can answer "what is planned on Nov 12?" and "was it
-- done?". Past rows are kept when a new plan is generated, so this table is
-- also the plan history.
--
-- Additive only: no existing column or constraint changes, so older app
-- builds keep working against the same database.

create table if not exists public.plan_sessions (
  id                   uuid primary key,              -- the card's "id" in plan_json
  user_id              uuid not null references auth.users (id) on delete cascade,
  plan_id              uuid references public.plans (id) on delete set null,
  session_date         date not null,
  session_time         text,                          -- "08:00 AM", as shown in the app
  day_label            text,                          -- "Day 1", "Added"
  exercise_id          text,                          -- 'squat', 'bicep_curl'; null = own exercise
  exercise_name        text not null,
  sets                 integer,
  reps                 integer,
  status               text not null default 'planned'
                         check (status in ('planned', 'done', 'skipped')),
  source               text not null default 'ai'
                         check (source in ('ai', 'user')),
  is_custom            boolean not null default false, -- own exercise, not camera-tracked
  ai_exercise          text,                          -- what the coach suggested before an edit
  ai_volume            text,
  completed_session_id uuid,                          -- the workout that completed it
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists plan_sessions_user_date_idx
  on public.plan_sessions (user_id, session_date);

alter table public.plan_sessions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'plan_sessions' and policyname = 'Users manage own plan sessions') then
    create policy "Users manage own plan sessions" on public.plan_sessions
      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
end $$;

-- Link a finished workout to the plan card it was started from.
alter table public.workout_sessions
  add column if not exists plan_session_id uuid
  references public.plan_sessions (id) on delete set null;

alter table public.plan_sessions
  drop constraint if exists plan_sessions_completed_session_fkey;
alter table public.plan_sessions
  add constraint plan_sessions_completed_session_fkey
  foreign key (completed_session_id)
  references public.workout_sessions (id) on delete set null;
