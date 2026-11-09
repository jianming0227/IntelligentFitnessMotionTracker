/// Consecutive days with at least one session, counting back from [now]'s day
/// (or the day before, so an unfinished today doesn't break the streak).
int currentStreak(Iterable<DateTime> sessionDates, DateTime now) {
  final days = sessionDates.map(_day).toSet();
  var cursor = _day(now);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Longest run of consecutive training days anywhere in [sessionDates].
int longestStreak(Iterable<DateTime> sessionDates) {
  final days = sessionDates.map(_day).toSet().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final d in days) {
    // Calendar-day difference, not Duration: a DST change makes a 23 h "day".
    final consecutive = prev != null &&
        DateTime(prev.year, prev.month, prev.day + 1) == d;
    run = consecutive ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
