-- 3D tutorial demos for the exercises added in 20261114000000_more_exercises.sql.
-- Same shape as the squat / bicep_curl rows. Assets are bundled (assets/models, assets/tutorials).
-- Keep in sync with assets/data/exercises.json.

update public.exercises set tutorial = '{
  "model": "assets/models/lunge.glb",
  "poster": "assets/tutorials/lunge_poster.png",
  "animation": "Lunge",
  "loopSeconds": 5.6,
  "heroOrbit": "-65deg 78deg 5.6m",
  "heroTarget": "0m 0.45m 0m",
  "heroFieldOfView": "30deg",
  "fullOrbit": "-65deg 78deg auto",
  "fullTarget": "auto auto auto",
  "cues": [
    {"at": 0.2, "text": "Target muscles: quads and glutes"},
    {"at": 1.4, "text": "Lower straight down, chest tall"},
    {"at": 2.6, "text": "Front knee stays over the ankle"},
    {"at": 3.8, "text": "Push up through the front heel"}
  ]
}'::jsonb
where id = 'lunge';

update public.exercises set tutorial = '{
  "model": "assets/models/shoulder_press.glb",
  "poster": "assets/tutorials/shoulder_press_poster.png",
  "animation": "ShoulderPress",
  "loopSeconds": 5.2,
  "heroOrbit": "-30deg 80deg 3.6m",
  "heroTarget": "0m 1.2m 0m",
  "heroFieldOfView": "30deg",
  "fullOrbit": "-30deg 80deg auto",
  "fullTarget": "auto auto auto",
  "cues": [
    {"at": 0.2, "text": "Target muscle: shoulders"},
    {"at": 1.4, "text": "Press straight up, core tight"},
    {"at": 2.8, "text": "Lock out without shrugging"},
    {"at": 3.3, "text": "Lower back to shoulder height"}
  ]
}'::jsonb
where id = 'shoulder_press';

update public.exercises set tutorial = '{
  "model": "assets/models/lateral_raise.glb",
  "poster": "assets/tutorials/lateral_raise_poster.png",
  "animation": "LateralRaise",
  "loopSeconds": 5.2,
  "heroOrbit": "-20deg 80deg 3.8m",
  "heroTarget": "0m 1m 0m",
  "heroFieldOfView": "30deg",
  "fullOrbit": "-20deg 80deg auto",
  "fullTarget": "auto auto auto",
  "cues": [
    {"at": 0.2, "text": "Target muscle: shoulders"},
    {"at": 1.4, "text": "Lead with elbows, soft bend"},
    {"at": 2.8, "text": "Stop at shoulder height"},
    {"at": 3.3, "text": "Lower slowly, don''t swing"}
  ]
}'::jsonb
where id = 'lateral_raise';
