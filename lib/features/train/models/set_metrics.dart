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

  String get formPercent => '${(formScore * 100).round()}%';

  String get fatigueLabel {
    if (fatigueIndex < 0.15) return 'Low';
    if (fatigueIndex < 0.35) return 'Moderate';
    return 'High';
  }

  // e.g. "4.2s" — used in the HUD and Gemini prompt.
  String get tutLabel => '${(tutMs / 1000).toStringAsFixed(1)}s';

  // One-line text summary used as input to Gemini session history.
  String toHistorySummary() =>
      'Set $setNumber: $repsCompleted reps, form $formPercent, fatigue $fatigueLabel, TUT $tutLabel';
}
