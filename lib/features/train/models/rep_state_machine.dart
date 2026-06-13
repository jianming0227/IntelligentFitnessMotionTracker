import 'exercise.dart';

/// FR-2.4: Hardened rep state machine — extracted from CameraView so the
/// counting logic is pure Dart and unit-testable.
///
/// Three guards reject false positives:
///   1. Landmark confidence — handled upstream: low-confidence frames never
///      produce an angle, so they never reach [feed].
///   2. Strict thresholds   — angle must cross [Exercise.repBottomAngleStrict]
///      then [Exercise.repTopAngleStrict], which sit tighter than the form
///      gauge green zone.
///   3. Min phase duration  — once a phase is entered, the opposite phase
///      cannot fire until [Exercise.minRepDurationMs] has elapsed. Kills
///      sub-second jitter from landmark wobble.
class RepStateMachine {
  RepStateMachine({required this.exercise});

  final Exercise exercise;

  bool _isDown = false;
  DateTime? _phaseEnteredAt;
  DateTime? _repStartTime;

  int repCount = 0;
  final List<int> repDurationsMs = [];

  /// Feeds one confidence-checked angle sample with its timestamp.
  /// Returns true exactly when a rep completes.
  bool feed(double angle, DateTime now) {
    final bool atBottom;
    final bool atTop;
    if (exercise.id == 'bicep_curl') {
      atBottom = angle > exercise.repBottomAngleStrict; // arm extended
      atTop = angle < exercise.repTopAngleStrict; // arm curled
    } else {
      atBottom = angle < exercise.repBottomAngleStrict; // squat depth
      atTop = angle > exercise.repTopAngleStrict; // standing
    }

    final phaseAgeMs = _phaseEnteredAt == null
        ? 0
        : now.difference(_phaseEnteredAt!).inMilliseconds;

    if (!_isDown && atBottom && phaseAgeMs >= exercise.minRepDurationMs) {
      _isDown = true;
      _phaseEnteredAt = now;
      _repStartTime = now;
    } else if (_isDown && atTop && phaseAgeMs >= exercise.minRepDurationMs) {
      _isDown = false;
      _phaseEnteredAt = now;
      if (_repStartTime != null) {
        repDurationsMs.add(now.difference(_repStartTime!).inMilliseconds);
        _repStartTime = null;
      }
      repCount++;
      return true;
    } else {
      // If the state isn't ready to flip, still anchor the phase start the
      // first time we land in a recognisable position so the guard works.
      _phaseEnteredAt ??= now;
    }
    return false;
  }

  /// Called when a new set begins — restarts the phase duration clock.
  void resetPhase() => _phaseEnteredAt = null;

  /// Called when the rest countdown starts — next set counts from zero.
  void resetRepCount() => repCount = 0;

  /// Called after set metrics are captured — durations belong to that set.
  void clearDurations() => repDurationsMs.clear();
}
