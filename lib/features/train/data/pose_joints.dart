import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/side_selector.dart';

/// ML Kit landmarks for an exercise's `joints` (e.g. `['hip','knee','ankle']`)
/// on one side of the body: `hip` + left → `PoseLandmarkType.leftHip`.
/// Names are checked against `trackableJoints` when the catalog loads, so a
/// lookup here can't fail for a loaded exercise.
List<PoseLandmarkType> landmarksFor(List<String> joints, BodySide side) {
  final prefix = side == BodySide.left ? 'left' : 'right';
  final byName = PoseLandmarkType.values.asNameMap();
  return [
    for (final j in joints)
      byName['$prefix${j[0].toUpperCase()}${j.substring(1)}']!,
  ];
}
