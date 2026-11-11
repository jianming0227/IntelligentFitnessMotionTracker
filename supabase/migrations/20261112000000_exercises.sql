-- exercises: the exercise catalog, read by the app at startup.
--
-- Every exercise the app can show, track with the camera, coach and plan is a
-- row here. Adding a row (dashboard → Table Editor) adds the exercise to the
-- app on its next launch: Train list, Home carousel, camera tracking, spoken
-- form tips, AI plan catalog, plan editor and body map all read this table.
-- Column guide with an example row: supabase/README_exercises.md
--
-- Additive only. Squat and Bicep Curl are inserted with the exact values the
-- app used to hardcode.

create table if not exists public.exercises (
  id                      text primary key,       -- 'squat'; plan actionId is 'start_' || id
  name                    text not null unique,   -- shown in the app, stored in workout_sessions.exercise_type
  category                text not null check (category in ('legs', 'upper', 'core')),
  description             text not null default '',
  sort_order              integer not null default 100,
  is_active               boolean not null default true,

  -- Camera tracking (FR-2.2 / FR-2.4)
  joints                  text[] not null,        -- 3 ML Kit points, e.g. {hip,knee,ankle}; angle measured at the middle one
  angle_at_bottom         text not null check (angle_at_bottom in ('small', 'large')),
                                                  -- joint angle at the bottom of a rep: squat 'small' (deep knee bend), curl 'large' (arm straight)
  target_angle_min        double precision not null,  -- form gauge green zone
  target_angle_max        double precision not null,
  rep_bottom_angle        double precision not null,  -- must pass this to count "down"
  rep_top_angle           double precision not null,  -- then this to count "up" (one rep)
  rom_full_span_deg       double precision not null,  -- degrees of travel in a perfect rep
  min_rep_ms              integer not null default 700,
  min_landmark_confidence double precision not null default 0.55,
  rest_seconds            integer not null default 30,

  -- Coaching
  form_cues               text[] not null default '{}',  -- spoken when form drops

  -- Analytics
  met                     double precision not null default 3.5,
  primary_muscles         text[] not null default '{}',  -- body-map names: quads, glutes, biceps ...
  secondary_muscles       text[] not null default '{}',

  -- Media (asset path 'assets/...' or a public Storage URL 'https://...')
  image_url               text,
  image_framing           jsonb,  -- {"alignX","alignY","zoom","zoomX","zoomY"}: Home card crop
  tutorial                jsonb,  -- 3D demo: model, poster, animation, loopSeconds, camera, cues

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  constraint exercises_three_joints check (array_length(joints, 1) = 3)
);

alter table public.exercises enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'exercises' and policyname = 'Anyone can read active exercises') then
    -- Read-only for the app (signed in or not); edits happen in the dashboard.
    create policy "Anyone can read active exercises" on public.exercises
      for select to anon, authenticated using (is_active);
  end if;
end $$;

insert into public.exercises (
  id, name, category, description, sort_order,
  joints, angle_at_bottom,
  target_angle_min, target_angle_max, rep_bottom_angle, rep_top_angle,
  rom_full_span_deg, min_rep_ms,
  form_cues, met, primary_muscles, secondary_muscles,
  image_url, image_framing, tutorial
) values
(
  'squat', 'Squat', 'legs', 'Full body lower compound', 10,
  -- Knee angle: ~180° standing, ~90° parallel, <70° deep.
  '{hip,knee,ankle}', 'small',
  70, 100, 95, 168,
  105, 800,
  '{"Go deeper","Keep your chest up","Knees track over toes"}',
  3.5, '{quads,glutes}', '{hamstrings,calves,core}',
  'assets/images/squat.png',
  '{"alignX": 0, "alignY": 0.35, "zoom": 1.4, "zoomX": -1, "zoomY": 0.5}',
  '{
    "model": "assets/models/squat.glb",
    "poster": "assets/tutorials/squat_poster.png",
    "animation": "Squat",
    "loopSeconds": 5.8,
    "heroOrbit": "-60deg 80deg 4.6m",
    "heroTarget": "0m 0.85m 0m",
    "heroFieldOfView": "30deg",
    "fullOrbit": "-60deg 80deg auto",
    "fullTarget": "auto auto auto",
    "cues": [
      {"at": 0.2, "text": "Target muscles: quads and glutes"},
      {"at": 1.4, "text": "Hips back, knees track over toes"},
      {"at": 3.9, "text": "Chest up, drive up through your heels"}
    ]
  }'
),
(
  'bicep_curl', 'Bicep Curl', 'upper', 'Elbow flexion, full ROM', 20,
  -- Elbow angle: ~170° arm extended (rep bottom), ~40° curled (rep top).
  '{shoulder,elbow,wrist}', 'large',
  30, 100, 162, 40,
  140, 600,
  '{"Full extension at the bottom","Squeeze at the top","Keep your elbow still"}',
  3.5, '{biceps}', '{forearms}',
  'assets/images/bicep.png',
  '{"alignX": 0, "alignY": 0, "zoom": 1.4, "zoomX": -1.01, "zoomY": -0.5}',
  '{
    "model": "assets/models/bicep_curl.glb",
    "poster": "assets/tutorials/bicep_curl_poster.png",
    "animation": "BicepCurl",
    "loopSeconds": 5.6,
    "heroOrbit": "-30deg 80deg 2.9m",
    "heroTarget": "0m 1.15m 0m",
    "heroFieldOfView": "28deg",
    "fullOrbit": "-30deg 80deg auto",
    "fullTarget": "auto auto auto",
    "cues": [
      {"at": 0.2, "text": "Target muscle: biceps"},
      {"at": 1.4, "text": "Elbows pinned to your sides"},
      {"at": 3.0, "text": "Squeeze at the top"},
      {"at": 3.7, "text": "Lower slowly to full extension"}
    ]
  }'
)
on conflict (id) do nothing;

-- Planned workouts point at a real catalog entry (null = own exercise / rest).
alter table public.plan_sessions
  drop constraint if exists plan_sessions_exercise_fkey;
alter table public.plan_sessions
  add constraint plan_sessions_exercise_fkey
  foreign key (exercise_id) references public.exercises (id) on delete set null;

-- Public bucket for images and .glb models of new exercises. Files are read
-- through their public URL; uploads happen in the dashboard.
insert into storage.buckets (id, name, public)
values ('exercise-media', 'exercise-media', true)
on conflict (id) do nothing;
