-- Three more camera-tracked exercises (F4). Rows only; no schema change.
-- No photo or 3D demo yet (image_url / tutorial null → dumbbell icon); the
-- 3D demos are being made in a separate session (docs/HANDOFF_3D_DEMOS.md).
--
-- Angles are first estimates for a phone in front of the user (lunge also
-- works side-on). Tune them on a device by editing the row; every number is
-- read at app start. Rep rule (angle_at_bottom = 'small'): the joint angle
-- must drop below rep_bottom_angle, then rise above rep_top_angle.

insert into public.exercises (
  id, name, category, description, sort_order,
  joints, angle_at_bottom,
  target_angle_min, target_angle_max, rep_bottom_angle, rep_top_angle,
  rom_full_span_deg, min_rep_ms,
  form_cues, met, primary_muscles, secondary_muscles
) values
(
  'lunge', 'Lunge', 'legs', 'Split-stance knee bend, one leg at a time', 30,
  -- Front knee: ~175° standing, ~90° at the bottom of a full lunge.
  '{hip,knee,ankle}', 'small',
  80, 110, 105, 160,
  85, 900,
  '{"Front knee over your ankle","Keep your torso upright","Lower the back knee toward the floor"}',
  3.5, '{quads,glutes}', '{hamstrings,calves,core}'
),
(
  'shoulder_press', 'Shoulder Press', 'upper', 'Press overhead to a full lockout', 40,
  -- Elbow, seen from the front: ~90° with hands at shoulder height,
  -- ~170° with arms locked out overhead.
  '{shoulder,elbow,wrist}', 'small',
  75, 110, 100, 155,
  80, 700,
  '{"Press straight up","Keep your core tight","Lower to shoulder height"}',
  3.5, '{shoulders}', '{triceps}'
),
(
  'lateral_raise', 'Lateral Raise', 'upper', 'Raise the arms out to shoulder height', 50,
  -- Shoulder (hip → shoulder → elbow), seen from the front: ~20° with arms
  -- by the sides, ~90° at shoulder height.
  '{hip,shoulder,elbow}', 'small',
  70, 100, 35, 75,
  70, 700,
  '{"Raise to shoulder height","Soft bend in the elbows","Lower slowly"}',
  3.5, '{shoulders}', '{back}'
)
on conflict (id) do nothing;
