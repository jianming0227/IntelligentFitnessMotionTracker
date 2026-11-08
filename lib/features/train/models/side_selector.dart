import 'dart:math';

/// Which side of the body the joint angle is read from.
enum BodySide { left, right }

/// B2: picks the body side that is doing the exercise. Pure Dart, unit-tested
/// like [RepStateMachine].
///
/// Each frame feeds the joint angle of each side (null when that side's
/// landmarks are below the confidence threshold). The selector tracks how far
/// each side's angle has travelled (max − min) since [reset]. Landmark
/// confidence can't decide this: facing the camera both sides score ~0.99,
/// and ML Kit gives hidden joints high confidence too, so a resting arm or an
/// occluded leg could win. The working side is the one that moves.
///
/// Once either side has travelled [lockRangeDeg] the bigger mover is locked
/// until [reset] — switching sides mid-set would put a jump in the angle
/// stream and corrupt the ROM span of the rep in progress.
class SideSelector {
  SideSelector({this.lockRangeDeg = 40});

  final double lockRangeDeg;

  double? _leftMin, _leftMax, _rightMin, _rightMax;
  BodySide? _locked;

  bool get isLocked => _locked != null;

  /// Degrees each side's angle has travelled since [reset].
  double get leftRange => _range(_leftMin, _leftMax);
  double get rightRange => _range(_rightMin, _rightMax);

  /// Locked side, else the side that has moved more so far. Ties go to left,
  /// the side the app used before B2.
  BodySide get side =>
      _locked ?? (rightRange > leftRange ? BodySide.right : BodySide.left);

  /// Feeds one frame's per-side angle. Returns the side to use for it.
  BodySide feed(double? leftAngle, double? rightAngle) {
    if (_locked != null) return _locked!;
    if (leftAngle != null) {
      _leftMin = min(_leftMin ?? leftAngle, leftAngle);
      _leftMax = max(_leftMax ?? leftAngle, leftAngle);
    }
    if (rightAngle != null) {
      _rightMin = min(_rightMin ?? rightAngle, rightAngle);
      _rightMax = max(_rightMax ?? rightAngle, rightAngle);
    }
    if (max(leftRange, rightRange) >= lockRangeDeg) _locked = side;
    return side;
  }

  /// Called when a new set begins — the user may switch arms between sets.
  void reset() {
    _leftMin = _leftMax = _rightMin = _rightMax = null;
    _locked = null;
  }

  static double _range(double? lo, double? hi) =>
      lo == null || hi == null ? 0 : hi - lo;
}
