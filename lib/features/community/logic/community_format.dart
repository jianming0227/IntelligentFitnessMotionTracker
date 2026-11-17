import '../../progress/models/session_record.dart';
import '../../train/models/set_metrics.dart';
import '../models/post.dart';

/// Totals of a finished workout for the share card and the post.
/// kcal uses the exercise MET: kcal = MET × kg × active hours.
PostStats statsFromSets(
  List<SetMetrics> sets, {
  required double met,
  required double weightKg,
}) {
  final reps = sets.fold(0, (sum, s) => sum + s.repsCompleted);
  final ms = sets.fold(0, (sum, s) => sum + s.setDurationMs);
  final avgForm = sets.isEmpty
      ? null
      : (sets.fold(0.0, (sum, s) => sum + s.formScore) / sets.length * 100)
            .round();
  final kcal = ms == 0 ? null : (met * weightKg * ms / 3600000).round();
  return PostStats(
    reps: reps,
    sets: sets.length,
    durationMs: ms,
    avgFormPct: avgForm,
    kcal: kcal,
  );
}

/// Same numbers for a saved workout from history (Home "Share your workout").
/// Local history has no set times, so time and kcal can be missing.
PostStats statsFromRecord(SessionRecord r, {required double weightKg}) =>
    PostStats(
      reps: r.totalReps,
      sets: r.sets.length,
      durationMs: r.activeDuration.inMilliseconds,
      avgFormPct: r.sets.isEmpty ? null : r.avgFormPct,
      kcal: r.calories(weightKg)?.round(),
    );

/// Up to [max] distinct author names, newest poster first.
List<String> recentAuthors(Iterable<Post> posts, {int max = 3}) {
  final seen = <String>{};
  return [
    for (final p in posts)
      if (seen.add(p.userId)) p.authorName,
  ].take(max).toList();
}

/// "8 workouts" / "1 workout" / "No workouts".
String workoutsCount(int n) => switch (n) {
  0 => 'No workouts',
  1 => '1 workout',
  _ => '$n workouts',
};

/// "1:48" for 108 000 ms; "–" when there is no time.
String formatDuration(int ms) {
  if (ms <= 0) return '–';
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// "now", "5m", "3h", "2d", then "Nov 3" (and the year when it differs).
String timeAgo(DateTime t, DateTime now) {
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final base = '${months[t.month - 1]} ${t.day}';
  return t.year == now.year ? base : '$base, ${t.year}';
}

/// First letter for an avatar circle.
String initialOf(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : t[0].toUpperCase();
}

/// Display names: 1-40 characters after trimming.
String? validDisplayName(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.isEmpty || t.length > 40 ? null : t;
}

const maxCaptionLength = 280;
