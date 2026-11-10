import 'streak.dart';

/// Mood of Flick, the Progress-tab mascot. Index matches the design brief's
/// `mood` number (0 idle, 1 happy, 2 sleepy, 3 sad).
enum MascotMood { idle, happy, sleepy, sad }

/// One day of the adaptive plan, parsed from a `SessionCard`. [label] is the
/// card's exercise (e.g. "Squat", "Active Recovery").
/// [done] = an own (non-tracked) workout the user ticked off by hand.
typedef PlanDay = ({DateTime date, bool isRest, String label, bool done});

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Plan cards carry dates like `"Wed, Jun 3"` with no year. Picks the year
/// that puts the date nearest to [now], so a plan made on Dec 30 for
/// "Thu, Jan 1" resolves to next year.
DateTime? parsePlanDate(String raw, DateTime now) {
  final m = RegExp(
    r'([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2})',
  ).firstMatch(raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw);
  if (m == null) return null;
  final month = _months[m.group(1)!.toLowerCase()];
  final day = int.tryParse(m.group(2)!);
  if (month == null || day == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  DateTime? best;
  for (final y in [now.year - 1, now.year, now.year + 1]) {
    final d = DateTime(y, month, day);
    if (d.month != month) continue; // Feb 30 etc.
    if (best == null ||
        d.difference(today).abs() < best.difference(today).abs()) {
      best = d;
    }
  }
  return best;
}

/// One plan card is a rest day when the user skipped it, or (for AI cards)
/// its day/exercise name says "Active Recovery" or "Rest", or it has no start
/// action. The coach tip and volume are not checked: "rest 60 s between
/// sets" is still a workout. A user's own exercise (`custom`) has no start
/// action but is still a workout.
bool isRestSession(Map<dynamic, dynamic> s) {
  if (s['skipped'] == true) return true;
  if (s['custom'] == true) return false;
  final name = [
    s['day'],
    s['exercise'],
  ].whereType<String>().join(' ').toLowerCase();
  final action = s['actionId'];
  return name.contains('active recovery') ||
      RegExp(r'\brest\b').hasMatch(name) ||
      action is! String ||
      !action.startsWith('start_');
}

/// Reads the `sessions` list of a plan JSON (see [isRestSession]).
List<PlanDay> planDays(Map<String, dynamic>? plan, DateTime now) {
  final sessions = plan?['sessions'];
  if (sessions is! List) return const [];
  final days = <PlanDay>[];
  for (final s in sessions.whereType<Map>()) {
    final date = s['date'] is String ? parsePlanDate(s['date'], now) : null;
    if (date == null) continue;
    final isRest = isRestSession(s);
    final label =
        s['exercise'] is String && (s['exercise'] as String).trim().isNotEmpty
        ? (s['exercise'] as String).trim()
        : (isRest ? 'Active Recovery' : 'Workout');
    days.add((
      date: date,
      isRest: isRest,
      label: label,
      done: s['done'] == true && !isRest,
    ));
  }
  days.sort((a, b) => a.date.compareTo(b.date));
  return days;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Days trained: real sessions plus own workouts ticked off on the plan.
Set<DateTime> _trainedDays(
  Iterable<DateTime> sessionDates,
  Map<String, dynamic>? plan,
  DateTime now,
) => {
  ...sessionDates.map(_day),
  for (final d in planDays(plan, now))
    if (d.done) d.date,
};

/// Picks the mascot mood. Never guilt-trips for long: sad only lasts until
/// the user trains again.
///
/// 1. Trained today → happy.
/// 2. No plan → idle.
/// 3. Today is a planned rest / active-recovery day → sleepy.
/// 4. A planned training day passed with no session, and nothing trained
///    since → sad.
/// 5. Today is a planned training day not done yet → idle.
/// 6. Otherwise: happy if at least one plan day is behind us and all were
///    done (on track), idle if the plan hasn't started.
MascotMood mascotMoodFor({
  required Map<String, dynamic>? plan,
  required Iterable<DateTime> sessionDates,
  required DateTime now,
}) {
  final trained = _trainedDays(sessionDates, plan, now);
  final today = _day(now);
  if (trained.contains(today)) return MascotMood.happy;

  final days = planDays(plan, now);
  if (days.isEmpty) return MascotMood.idle;

  final todayEntry = days.where((d) => d.date == today).firstOrNull;
  if (todayEntry != null && todayEntry.isRest) return MascotMood.sleepy;

  final pastTraining = days.where((d) => !d.isRest && d.date.isBefore(today));
  final missed = pastTraining.where((d) => !trained.contains(d.date));
  if (missed.isNotEmpty) {
    final lastMissed = missed.last.date;
    final trainedSince = trained.any((t) => t.isAfter(lastMissed));
    if (!trainedSince) return MascotMood.sad;
  }

  if (todayEntry != null) return MascotMood.idle;
  return pastTraining.isNotEmpty ? MascotMood.happy : MascotMood.idle;
}

/// Key for a one-shot celebration, or null when there's nothing new to
/// celebrate. The card stores the last key it played so each event fires once.
///
/// * every training day of the current plan is done → `plan:<first>-<last>`
/// * a personal record was set today → `pr:<kind>:<value>:<yyyy-mm-dd>`
String? celebrationKey({
  required Map<String, dynamic>? plan,
  required Iterable<DateTime> sessionDates,
  required DateTime now,
  ({int value, DateTime? date})? mostRepsRecord,
  ({int value, DateTime? date})? bestFormRecord,
}) {
  final trained = _trainedDays(sessionDates, plan, now);
  final today = _day(now);
  String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final training = planDays(plan, now).where((d) => !d.isRest).toList();
  if (training.isNotEmpty && training.every((d) => trained.contains(d.date))) {
    return 'plan:${ymd(training.first.date)}-${ymd(training.last.date)}';
  }
  for (final (kind, r) in [
    ('reps', mostRepsRecord),
    ('form', bestFormRecord),
  ]) {
    final d = r?.date;
    if (r != null && d != null && _day(d) == today) {
      return 'pr:$kind:${r.value}:${ymd(today)}';
    }
  }
  return null;
}

/// One-line speech bubble for the mascot card. Encouraging, never guilt.
String mascotLine(
  MascotMood mood, {
  required int streak,
  required bool hasPlan,
}) => switch (mood) {
  MascotMood.happy when streak >= 2 =>
    '$streak-day streak! Keep the fire going.',
  MascotMood.happy => 'Nice work! That one counts.',
  MascotMood.sleepy => 'Rest day. Recovery is training too.',
  MascotMood.sad => 'Missed one? A quick set gets us back on track.',
  MascotMood.idle when !hasPlan =>
    'Finish a workout and I\'ll help plan your week.',
  MascotMood.idle => 'Ready when you are. Today\'s session awaits!',
};

/// Re-export so callers computing [mascotLine] need one import.
int mascotStreak(Iterable<DateTime> sessionDates, DateTime now) =>
    currentStreak(sessionDates, now);

// ── Explaining Flick to the user ─────────────────────────────────────────────

enum ChecklistState { done, todo, missed, rest, upcoming }

/// One line of the "keep Flick happy" checklist.
class ChecklistItem {
  const ChecklistItem(this.text, this.state, {this.detail});

  final String text;
  final ChecklistState state;
  final String? detail;
}

/// Why Flick looks the way he does, plus what the user can do about it.
class MascotStatus {
  const MascotStatus({
    required this.mood,
    required this.headline,
    required this.reason,
    required this.checklist,
  });

  final MascotMood mood;

  /// "Flick is happy", "Flick is waiting"…
  final String headline;

  /// One sentence on why, naming the actual day/exercise where relevant.
  final String reason;
  final List<ChecklistItem> checklist;
}

String shortDate(DateTime d) {
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${wd[d.weekday - 1]}, ${mo[d.month - 1]} ${d.day}';
}

/// Same rules as [mascotMoodFor], but returns the explanation and a checklist
/// (today's workout first, then each plan day) so the sheet can never
/// disagree with the mood Flick is showing.
MascotStatus mascotStatusFor({
  required Map<String, dynamic>? plan,
  required Iterable<DateTime> sessionDates,
  required DateTime now,
}) {
  final mood = mascotMoodFor(plan: plan, sessionDates: sessionDates, now: now);
  final trained = _trainedDays(sessionDates, plan, now);
  final today = _day(now);
  final trainedToday = trained.contains(today);
  final days = planDays(plan, now);
  final todayEntry = days.where((d) => d.date == today).firstOrNull;

  bool trainedSince(DateTime d) => trained.any((t) => t.isAfter(d));
  final missed = days
      .where(
        (d) => !d.isRest && d.date.isBefore(today) && !trained.contains(d.date),
      )
      .toList();
  final lastMissed = missed.isEmpty ? null : missed.last;

  final checklist = <ChecklistItem>[
    ChecklistItem(
      todayEntry != null && todayEntry.isRest
          ? 'Rest day: a workout is optional'
          : 'Do one workout today',
      trainedToday
          ? ChecklistState.done
          : (todayEntry != null && todayEntry.isRest
                ? ChecklistState.rest
                : ChecklistState.todo),
      detail: trainedToday
          ? 'Done. Flick is happy!'
          : 'Any exercise counts. Flick cheers up right away.',
    ),
    if (days.isEmpty)
      const ChecklistItem(
        'Get your 3-day plan',
        ChecklistState.todo,
        detail: 'Finish a workout, then open the Plan tab',
      ),
    for (final d in days)
      ChecklistItem(
        '${shortDate(d.date)} · ${d.label}',
        d.isRest
            ? ChecklistState.rest
            : trained.contains(d.date)
            ? ChecklistState.done
            : d.date.isBefore(today)
            ? ChecklistState.missed
            : d.date == today
            ? ChecklistState.todo
            : ChecklistState.upcoming,
      ),
  ];

  final (headline, reason) = switch (mood) {
    MascotMood.happy when trainedToday => (
      'Flick is happy',
      'You trained today. Keep the streak going!',
    ),
    MascotMood.happy => ('Flick is happy', "You're on track with your plan."),
    MascotMood.sleepy => (
      'Flick is resting',
      "It's a planned rest day. Recovery is training too.",
    ),
    MascotMood.sad => (
      'Flick is a little sad',
      lastMissed != null && !trainedSince(lastMissed.date)
          ? 'You missed ${shortDate(lastMissed.date)} (${lastMissed.label}). One workout cheers him up.'
          : 'You missed a plan day. One workout cheers him up.',
    ),
    MascotMood.idle when days.isEmpty => (
      'Flick is waiting',
      "No plan yet. Finish a workout and he'll help plan your week.",
    ),
    MascotMood.idle when todayEntry != null => (
      'Flick is waiting',
      "Today's ${todayEntry.label} session is still to do.",
    ),
    MascotMood.idle => (
      'Flick is waiting',
      'Your plan starts ${shortDate(days.first.date)}.',
    ),
  };

  return MascotStatus(
    mood: mood,
    headline: headline,
    reason: reason,
    checklist: checklist,
  );
}
