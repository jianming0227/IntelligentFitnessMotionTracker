import 'dart:math';

// FR-3.1: Per-set performance snapshot — collected by CameraView after each set
// and passed to GeminiService for coaching + session analysis.
class SetMetrics {
  const SetMetrics({
    required this.setNumber,
    required this.repsCompleted,
    required this.formScore,
    required this.fatigueIndex,
    required this.repDurationsMs,
    required this.completedAt,
    this.tutMs = 0,
    this.romScore = 0,
    this.repRomSpans = const [],
    this.setDurationMs = 0,
  });

  final int setNumber;
  final int repsCompleted;

  // FR-3.1: Fraction of frames (0.0–1.0) where the joint angle was within the
  // target range — higher means more time spent in the correct position.
  final double formScore;

  // FR-3.1: (lastRepMs / firstRepMs) − 1; positive means the user slowed down
  // across the set (fatigue), negative means they sped up (warm-up effect).
  final double fatigueIndex;

  final List<int> repDurationsMs;
  final DateTime completedAt;

  // FR-2.4: Total milliseconds the joint spent inside the target angle zone.
  final int tutMs;

  // FR-2.4 ROM: mean per-rep joint excursion as a 0.0–1.0 fraction of the
  // exercise's ideal full-range rep. Low means the user is cutting reps short.
  final double romScore;

  // FR-2.4 ROM: raw per-rep excursion in degrees, kept for the Gemini prompt.
  final List<double> repRomSpans;

  // FR-2.4: wall-clock length of the set — the denominator for [tutRatio].
  final int setDurationMs;

  String get formPercent => '${(formScore * 100).round()}%';

  String get romPercent => '${(romScore * 100).round()}%';

  // FR-2.4: fraction of the set spent inside the target zone. Clamped because
  // frame timestamps accumulate independently of the 1-second set ticker, so
  // rounding can push TUT slightly past elapsed time.
  double get tutRatio =>
      setDurationMs <= 0 ? 0.0 : (tutMs / setDurationMs).clamp(0.0, 1.0);

  // FR-2.4: Endurance = geometric mean of range of motion and time under
  // tension. Geometric, not the product: two 0.7 inputs read as 0.7 rather
  // than collapsing to 0.49, which keeps the Endurance Bar legible. Static so
  // the live HUD bar and the stored set metrics share one formula.
  static double endurance(double romScore, double tutRatio) =>
      sqrt(romScore.clamp(0.0, 1.0) * tutRatio.clamp(0.0, 1.0));

  double get enduranceScore => endurance(romScore, tutRatio);

  String get endurancePercent => '${(enduranceScore * 100).round()}%';

  String get enduranceLabel {
    if (enduranceScore >= 0.7) return 'Strong';
    if (enduranceScore >= 0.4) return 'Fair';
    return 'Low';
  }

  String get fatigueLabel {
    if (fatigueIndex < 0.15) return 'Low';
    if (fatigueIndex < 0.35) return 'Moderate';
    return 'High';
  }

  // e.g. "4.2s" — used in the HUD and Gemini prompt.
  String get tutLabel => '${(tutMs / 1000).toStringAsFixed(1)}s';

  // One-line text summary used as input to Gemini session history.
  String toHistorySummary() =>
      'Set $setNumber: $repsCompleted reps, form $formPercent, fatigue $fatigueLabel, TUT $tutLabel, ROM $romPercent, endurance $endurancePercent';
}
