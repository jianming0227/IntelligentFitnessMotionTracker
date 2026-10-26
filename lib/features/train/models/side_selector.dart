/// Which side of the body the joint angle is read from.
enum BodySide { left, right }

/// B2: picks the body side facing the camera so angles are not read from
/// the occluded side. Pure Dart, unit-tested like [RepStateMachine].
///
/// Each frame feeds the mean landmark confidence of the exercise's three
/// joints on each side. Confidence is summed rather than compared per frame so
/// one noisy frame cannot flip the choice. After [lockAfterSamples] frames the
/// leader is locked until [reset] — switching sides mid-set would put a jump
/// in the angle stream and corrupt the ROM span of the rep in progress.
class SideSelector {
  SideSelector({this.lockAfterSamples = 10});

  final int lockAfterSamples;

  double _leftTotal = 0;
  double _rightTotal = 0;
  int _samples = 0;

  bool get isLocked => _samples >= lockAfterSamples;

  /// Current leader. Ties go to left, the side the app used before B2.
  BodySide get side =>
      _rightTotal > _leftTotal ? BodySide.right : BodySide.left;

  /// Feeds one frame's per-side confidence. Returns the side to use for it.
  BodySide feed(double leftConfidence, double rightConfidence) {
    if (!isLocked) {
      _leftTotal += leftConfidence;
      _rightTotal += rightConfidence;
      _samples++;
    }
    return side;
  }

  /// Called when a new set begins — the user may switch arms between sets.
  void reset() {
    _leftTotal = 0;
    _rightTotal = 0;
    _samples = 0;
  }
}
