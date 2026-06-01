import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// FR-2.1: Skeleton overlay — draws all 33 ML Kit landmarks and their bone
// connections on top of the live camera feed in real time.
class PosePainter extends CustomPainter {
  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.cameraLensDirection,
  });

  final List<Pose> poses;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;

  // FR-2.1: Skeleton connections — each tuple is one bone segment (joint A → joint B)
  static const _bones = [
    (PoseLandmarkType.leftShoulder,  PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder,  PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow,     PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow,    PoseLandmarkType.rightWrist),
    (PoseLandmarkType.leftShoulder,  PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip,       PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip,       PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee,      PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip,      PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee,     PoseLandmarkType.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = const Color(0xFF4F8EF7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = const Color(0xFF39E08B)
      ..style = PaintingStyle.fill;

    for (final pose in poses) {
      // Draw bones first so joints render on top
      for (final (typeA, typeB) in _bones) {
        final a = pose.landmarks[typeA];
        final b = pose.landmarks[typeB];
        if (a == null || b == null) continue;
        canvas.drawLine(_scale(a, size), _scale(b, size), bonePaint);
      }

      // Draw joint dots for landmarks with enough confidence
      for (final lm in pose.landmarks.values) {
        if (lm.likelihood > 0.5) {
          canvas.drawCircle(_scale(lm, size), 5, jointPaint);
        }
      }
    }
  }

  // FR-2.1: Scale landmark from camera image-space to canvas-space.
  // Mirrors x-axis for front camera so overlay matches the mirrored preview.
  Offset _scale(PoseLandmark lm, Size canvasSize) {
    double x = lm.x / imageSize.width * canvasSize.width;
    double y = lm.y / imageSize.height * canvasSize.height;
    if (cameraLensDirection == CameraLensDirection.front) {
      x = canvasSize.width - x;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(PosePainter old) => old.poses != poses;
}
