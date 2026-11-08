-- FitForm demo account seed.
--
-- Run in Supabase dashboard → SQL Editor → paste → Run. Safe to re-run:
-- creates the demo user once, then wipes and re-inserts its profile, plan and
-- 14 days of workout sessions so every run starts from the same data.
--
-- Login in the app with:  demo@fitform.app / FitFormDemo123
-- (throwaway demo credentials, change them below if this project is public)
--
-- Timestamps: the app stores and reads session times as the phone's local
-- wall clock (no timezone). Set v_tz to the phone's timezone so "today" in
-- the seed matches "today" on the phone.

do $$
declare
  v_email    text := 'demo@fitform.app';
  v_password text := 'FitFormDemo123';
  v_tz       text := 'Asia/Kuala_Lumpur';
  v_uid      uuid;
  v_today    timestamp := date_trunc('day', now() at time zone v_tz);
  v_days     int[] := array[13, 12, 10, 9, 7, 5, 4, 2, 1, 0];
  d          int;
  i          int := 0;
  s          int;
  p          numeric;        -- progress 0 → 1 across the two weeks
  is_squat   boolean;
  reps       int;
  form       numeric;
  rom        numeric;
  dur_ms     int;
  tut_ms     int;
  fatigue    numeric;
  started    timestamp;
  sets       jsonb;
begin
  -- 1. Demo auth user (created once) ---------------------------------------
  select id into v_uid from auth.users where email = v_email;

  if v_uid is null then
    v_uid := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_uid,
      'authenticated', 'authenticated', v_email,
      extensions.crypt(v_password, extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}', '{}',
      now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_uid, v_uid::text,
      jsonb_build_object('sub', v_uid::text, 'email', v_email,
                         'email_verified', true),
      'email', now(), now(), now()
    );
    raise notice 'Created demo user %', v_email;
  end if;

  -- 2. Reset demo data ------------------------------------------------------
  delete from public.workout_sessions where user_id = v_uid;
  delete from public.plans where user_id = v_uid;

  insert into public.profiles (
    id, gender, age, height_cm, weight_kg, goal, experience_level, updated_at
  ) values (
    v_uid, 'Male', 23, 175, 70, 'Build muscle', 'Intermediate', now()
  )
  on conflict (id) do update set
    gender = excluded.gender, age = excluded.age,
    height_cm = excluded.height_cm, weight_kg = excluded.weight_kg,
    goal = excluded.goal, experience_level = excluded.experience_level,
    updated_at = excluded.updated_at;

  -- 3. Sessions: squat and curl alternate. Squat form climbs past 80%;
  --    curl form stays in the 60s so the body map shows biceps as
  --    "needs form" (orange) next to green quads/glutes.
  foreach d in array v_days loop
    p := (13 - d) / 13.0;
    is_squat := i % 2 = 0;
    started := v_today - make_interval(days => d) + interval '8 hours';
    sets := '[]'::jsonb;

    for s in 1..3 loop
      reps    := 8 + round(p * 3)::int - (s - 1);
      form    := case when is_squat then 0.64 + 0.22 * p
                      else 0.56 + 0.10 * p end - 0.03 * (s - 1);
      rom     := 0.74 + 0.16 * p - 0.02 * (s - 1);
      dur_ms  := reps * 3000 + 4000;
      tut_ms  := round(dur_ms * form * 0.8)::int;
      fatigue := 0.05 + 0.12 * (s - 1);

      sets := sets || jsonb_build_object(
        'set', s,
        'reps', reps,
        'form_score', round(form, 3),
        'fatigue_index', fatigue,
        'fatigue_label', case when fatigue < 0.15 then 'Low'
                              when fatigue < 0.35 then 'Moderate'
                              else 'High' end,
        'tut_ms', tut_ms,
        'set_duration_ms', dur_ms,
        'rom_score', round(rom, 3),
        'rep_rom_spans', (
          select jsonb_agg(round((case when is_squat then 105 else 140 end)
                                 * rom + (r % 3) - 1, 1))
          from generate_series(1, reps) r
        ),
        'endurance_score', round(sqrt(rom * tut_ms::numeric / dur_ms), 3),
        'completed_at', to_char(started + make_interval(mins => s * 3),
                                'YYYY-MM-DD"T"HH24:MI:SS')
      );
    end loop;

    insert into public.workout_sessions (
      user_id, exercise_type, sets_completed, session_data, created_at
    ) values (
      v_uid, case when is_squat then 'Squat' else 'Bicep Curl' end,
      3, sets, started
    );
    i := i + 1;
  end loop;

  -- 4. Ready-made plan so the Plan tab isn't empty --------------------------
  insert into public.plans (user_id, plan_json, exercise_name, created_at)
  values (v_uid, $json${
    "type": "WorkoutPlanView",
    "title": "Muscle Building: Progressive Overload Block",
    "coachNote": "Squat form is up to the low 80s. Curl form is still in the 60s, so this block slows the curl down and adds one squat rep.",
    "sessions": [
      {"type": "SessionCard", "day": "Day 1", "date": "Mon", "time": "08:00 AM",
       "exercise": "Squat", "volume": "3 sets x 11 reps",
       "intensity": "Keep knee angle below 95 degrees at the bottom.",
       "actionId": "start_squat"},
      {"type": "SessionCard", "day": "Day 2", "date": "Wed", "time": "08:00 AM",
       "exercise": "Bicep Curl", "volume": "3 sets x 10 reps",
       "intensity": "Slow 3-second lowering, full extension every rep.",
       "actionId": "start_bicep_curl"},
      {"type": "SessionCard", "day": "Day 3", "date": "Fri", "time": "08:00 AM",
       "exercise": "Squat", "volume": "4 sets x 10 reps",
       "intensity": "Add a fourth set. Depth and knee tracking over speed.",
       "actionId": "start_squat"}
    ]
  }$json$::jsonb, 'Squat', now())
  on conflict (user_id) do update set
    plan_json = excluded.plan_json,
    exercise_name = excluded.exercise_name,
    created_at = excluded.created_at;

  raise notice 'Seeded % sessions for %', array_length(v_days, 1), v_email;
end $$;
