-- Photos for the exercises added in 20261114000000_more_exercises.sql.
-- Bundled assets (assets/images). image_framing = Home card crop, tune in the
-- dashboard without a rebuild. Keep in sync with assets/data/exercises.json.

update public.exercises set
  image_url = 'assets/images/lunge.jpg',
  image_framing = '{"alignX": 0, "alignY": 0, "zoom": 1.4, "zoomX": 0, "zoomY": -0.2}'::jsonb
where id = 'lunge';

update public.exercises set
  image_url = 'assets/images/shoulderpress.jpg',
  image_framing = '{"alignX": 0, "alignY": 0, "zoom": 1.4, "zoomX": 0, "zoomY": -0.5}'::jsonb
where id = 'shoulder_press';

update public.exercises set
  image_url = 'assets/images/lateralraise.jpg',
  image_framing = '{"alignX": 0, "alignY": 0, "zoom": 1.3, "zoomX": 0, "zoomY": -0.5}'::jsonb
where id = 'lateral_raise';
