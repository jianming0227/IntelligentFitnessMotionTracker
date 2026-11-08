/// Estimated energy burned: kcal = MET × body weight (kg) × active hours.
double caloriesBurned({
  required double met,
  required double weightKg,
  required Duration active,
}) =>
    met * weightKg * active.inMilliseconds / Duration.millisecondsPerHour;
