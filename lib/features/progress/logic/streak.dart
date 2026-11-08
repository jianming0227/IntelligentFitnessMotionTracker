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

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
