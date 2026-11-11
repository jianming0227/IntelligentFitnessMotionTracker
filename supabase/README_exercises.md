# Adding an exercise

The app has no exercise list in its code. Every exercise is a row in the
Supabase `exercises` table (migration `migrations/20261112000000_exercises.sql`).
Add a row, restart the app, and the exercise appears everywhere: Train list,
Home carousel, camera tracking + rep counting, spoken form tips, the AI plan
catalog, the plan editor and the Progress body map.

## Steps

1. (Optional) Upload a photo and/or a `.glb` 3D model to the public Storage
   bucket **exercise-media** (dashboard → Storage). Copy each file's public URL.
2. Dashboard → Table Editor → `exercises` → Insert row (or run the SQL below).
3. Restart the app. If a row is invalid the app skips it and logs
   `[Catalog] Skipped row: ...` in the console; the other exercises still load.
4. Optional: refresh the bundled offline copy `assets/data/exercises.json` with
   the new row (same column names) before the next app build, so a first launch
   without internet also has it.

To hide an exercise without deleting its history, set `is_active = false`.

## Columns

| Column | Required | Meaning |
|---|---|---|
| `id` | yes | Short key, e.g. `lunge`. The AI plan uses `start_<id>`. Never change it once used. |
| `name` | yes | Shown in the app and saved in workout history. |
| `category` | yes | `legs`, `upper` or `core`. |
| `description` | | One line under the name. |
| `sort_order` | | Lower comes first (Squat 10, Bicep Curl 20). |
| `joints` | yes | Exactly 3 of `shoulder, elbow, wrist, hip, knee, ankle, heel, footIndex`. The angle is measured at the **middle** one, on whichever side moves. |
| `angle_at_bottom` | yes | `small` if the joint bends to a small angle at the bottom of the rep (squat knee), `large` if the rep starts straight (curl elbow). |
| `target_angle_min` / `_max` | yes | Green zone of the form gauge, degrees. |
| `rep_bottom_angle` | yes | Joint must pass this to count "down". |
| `rep_top_angle` | yes | Then pass this to count one rep. |
| `rom_full_span_deg` | yes | Degrees of travel in a perfect rep (ROM score). |
| `min_rep_ms` | | Ignore crossings faster than this (default 700). |
| `min_landmark_confidence` | | Ignore frames below this ML Kit confidence (default 0.55). |
| `rest_seconds` | | Countdown between sets (default 30). |
| `form_cues` | | Spoken tips when form drops, e.g. `{"Front knee over ankle"}`. |
| `met` | | Calories: kcal = MET × kg × hours (default 3.5). |
| `primary_muscles` / `secondary_muscles` | | Body-map names: `quads, glutes, hamstrings, calves, hipFlexors, core, biceps, forearms, shoulders, chest, back, triceps`. Unknown names are ignored. |
| `image_url` | | `assets/...` (bundled) or a Storage public URL. Empty = dumbbell icon. |
| `image_framing` | | Home card crop: `{"alignX":0,"alignY":0.35,"zoom":1.4,"zoomX":-1,"zoomY":0.5}`. |
| `tutorial` | | 3D demo: `model`, `poster`, `animation` (clip name in the .glb) are required; `loopSeconds`, `heroOrbit`, `heroTarget`, `heroFieldOfView`, `fullOrbit`, `fullTarget`, `cues` (`[{"at":0.2,"text":"..."}]`) optional. |

**Limit:** tracking works for exercises whose rep is one joint bending and
straightening (lunge, shoulder press, leg raise, tricep extension ...).
Movements that need two joints at once or no joint angle (jumping jacks,
plank holds) need new code.

## Example

```sql
insert into public.exercises (
  id, name, category, description, sort_order,
  joints, angle_at_bottom,
  target_angle_min, target_angle_max, rep_bottom_angle, rep_top_angle, rom_full_span_deg,
  form_cues, met, primary_muscles, secondary_muscles, image_url
) values (
  'shoulder_press', 'Shoulder Press', 'upper', 'Overhead press, full lockout', 30,
  '{hip,shoulder,elbow}', 'small',   -- arm angle at the shoulder: small at the bottom
  60, 160, 70, 150, 100,
  '{"Press straight up","Keep your core tight"}',
  3.5, '{shoulders}', '{triceps}',
  'https://<project>.supabase.co/storage/v1/object/public/exercise-media/shoulder_press.png'
);
```
