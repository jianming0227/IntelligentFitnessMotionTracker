# FitForm — Milestone Tracker

## How to use
- `[x]` = Done
- `[ ]` = Not started
- `[~]` = Partially built (see notes below the item)

Add new requirements under the relevant module at any time.
Check off items as each feature is confirmed working on device.

---

## Module 1 — User & Authentication 🟡 Mostly Complete

### FR-1.1 — Email / Password Auth
- [x] User registration (email + password via Supabase)
- [x] User login
- [x] Auth-aware routing — GoRouter redirect (logged in → /home, logged out → /login)
- [x] Sign out from Profile tab

### FR-1.2 — Biometric Profile ❌ Not built
- [ ] Profile screen: input height, weight, fitness goal
- [ ] Store profile in Supabase (users table)
- [ ] Load profile on login — used to calibrate Gemini prompts

---

## Module 2 — Motion Tracking & Form Correction 🟡 In Progress

### FR-2.1 — Live Camera Feed + 33 Skeletal Landmarks
- [x] Camera permission (permission_handler)
- [x] Live camera preview (camera package)
- [x] ML Kit PoseDetector in stream mode
- [x] 33 landmark extraction per frame
- [x] Skeleton overlay drawn on camera feed (PosePainter — green dots + blue bones)
- [x] Front / back camera flip button

### FR-2.2 — Joint Angle Calculation & Form Evaluation
- [x] Knee angle calculation (hip → knee → ankle) — used for squat
- [x] Semicircular form gauge (needle shows deviation from target angle range)
- [x] Gauge toggle (tap to hide/show)
- [ ] Hip angle calculation (squat / lunge depth evaluation)
- [ ] Elbow angle calculation (push-up, bicep curl)
- [ ] Form evaluation logic for push-ups (elbow 0–90° ROM check)
- [ ] Form evaluation logic for bicep curls (elbow full ROM check)
- [ ] Per-exercise target angle config (currently only squat is tuned)

### FR-2.3 — Low-Latency TTS Corrective Voice-overs ❌ Not built
- [ ] Add flutter_tts package
- [ ] Squat corrections: "Go deeper", "Keep your chest up", "Knees track over toes"
- [ ] Push-up corrections: "Lower your chest", "Keep your core tight"
- [ ] Bicep curl corrections: "Full extension at the bottom"
- [ ] Trigger: angle out of target range for > 1.5 seconds
- [ ] Debounce: same cue cannot repeat within 4 seconds
- [ ] Respect device volume / mute

### FR-2.4 — Rep Counter + Interactive Endurance Bar (TUT + ROM) 🟡 Partial
- [x] Basic rep counter (angle threshold crossing — down < targetAngleMax, up > 160°)
- [x] Set progress dots (3 sets of 10 reps)
- [ ] Time Under Tension (TUT): measure milliseconds spent in the bottom position per rep
- [ ] Range of Motion (ROM): record max angle deviation reached per rep
- [ ] Replace current angle gauge with TUT × ROM composite Endurance Bar
- [ ] Animate Endurance Bar fill in real time during each rep

### Additional — Gesture-Based Session Start ❌ Not built
- [ ] Detect "both wrists raised above shoulders" pose before session begins
- [ ] OR detect open palm (5 fingers spread) as alternative start signal
- [ ] Display 3-2-1 countdown after gesture is confirmed
- [ ] Only start rep counting and data recording after countdown ends

### Additional — Per-Rep & Per-Set Data Collection ❌ Not built
- [ ] Timestamp each rep completion (used to calculate fatigue)
- [ ] Fatigue index: compare average time-per-rep of first 3 reps vs last 3 reps in a set
  - High fatigue = late reps take > 30% longer than early reps
- [ ] Per-frame green zone counter (frames where angle is in target range / total frames)
- [ ] Package all into a SetMetrics object at set completion:
  ```
  SetMetrics {
    setNumber, exercise,
    repsCompleted, targetReps,
    formScore (%),         // green zone frames / total frames
    avgRepTimeMs,          // average ms per rep
    fatigueIndex (%),      // slowdown from first to last rep
    totalTUT_ms,           // total time under tension
    avgROM_degrees,        // average range of motion per rep
  }
  ```

---

## Module 3 — Personalized Workout Plans ❌ Not started

### FR-3.1 — Transmit Performance Data to Gemini
- [ ] Add google_generative_ai package
- [ ] Add GEMINI_API_KEY to .env
- [ ] Create gemini_service.dart (reads key, initialises gemini-1.5-flash model)
- [ ] Post-set coaching: stream Gemini tip after each set (uses SetMetrics)
  - Prompt includes: exercise, set number, repsCompleted, formScore, fatigueIndex
  - Response streams word-by-word into a bottom sheet
- [ ] Post-session summary: after final set, send full session summary to Gemini
  - Prompt includes: all sets' SetMetrics, biometric profile (FR-1.2)
  - Gemini determines if user should progress or repeat current load

### FR-3.2 — Personalized Weekly Workout Block
- [ ] Gemini prompt: biometric profile + last N session summaries from Supabase
- [ ] Generate a weekly plan (exercise name, sets, reps, intensity level, rest days)
- [ ] Parse and display plan on Home screen
- [ ] "Start today's session" button on Home → navigates to Train with pre-selected exercise

---

## Module 4 — Progress Tracking & Analytics ❌ Not started

### FR-4.1 — Supabase Session Logging
- [ ] Design DB schema:
  - `sessions` table: user_id, exercise, started_at, ended_at, total_reps, avg_form_score
  - `sets` table: session_id, set_number, reps, form_score, fatigue_index, TUT_ms
- [ ] Write session to Supabase on workout end
- [ ] Read last N sessions → feed to Gemini as context (FR-3.2)

### FR-4.2 — Performance Dashboard (Home Screen)
- [ ] Recent sessions list (exercise, date, reps, form score)
- [ ] Weekly rep count chart
- [ ] Streak counter (consecutive days trained)
- [ ] Estimated calories burned (reps × MET factor per exercise)

---

## Module 5 — Video Tutorials & Community ❌ Not started (Could-Have)

### FR-5.1 — Mirror-Coach Interface
- [ ] Split-screen: YouTube exercise tutorial (top) + live skeleton feed (bottom)
- [ ] Pause/resume tutorial synced with user's rep pace

### FR-5.2 — Community Forum
- [ ] Post session summary to Supabase community table (reps, form score, calories)
- [ ] Community feed: scrollable list of others' session posts

---

## Recommended Build Order

| # | Task | Module | Status |
|---|---|---|---|
| 1 | Email/password auth + routing | M1 | ✅ Done |
| 2 | Camera + ML Kit skeleton + basic form gauge | M2 | ✅ Done |
| 3 | Per-rep timing + fatigue index + SetMetrics | M2 | 🔲 Next |
| 4 | TTS corrective voice-overs | M2 | 🔲 |
| 5 | Gesture-based session start | M2 | 🔲 |
| 6 | TUT + ROM endurance bar | M2 | 🔲 |
| 7 | Hip + elbow angle (push-up, bicep curl) | M2 | 🔲 |
| 8 | Gemini post-set coaching (streaming bottom sheet) | M3 | 🔲 |
| 9 | Gemini post-session summary + progression advice | M3 | 🔲 |
| 10 | Biometric profile screen | M1 | 🔲 |
| 11 | Supabase session + sets logging | M4 | 🔲 |
| 12 | Gemini weekly workout plan | M3 | 🔲 |
| 13 | Home dashboard (history, streak, calories) | M4 | 🔲 |
| 14 | Mirror-Coach interface | M5 | 🔲 |
| 15 | Community forum | M5 | 🔲 |
