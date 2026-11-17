update public.exercises
set tutorial = jsonb_set(tutorial, '{heroTarget}', '"0m 0.65m 0m"')
where id = 'lunge';

update public.exercises
set rep_bottom_angle = 105, rep_top_angle = 160
where id = 'lunge';
