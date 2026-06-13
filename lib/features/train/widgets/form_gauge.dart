import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// FR-2.2: Interactive form quality gauge — visualises live joint angle deviation
// from the exercise's target range. Semicircular arc: left red = too shallow,
// centre green = good form, right red = too deep. Tap to toggle visibility.
class FormGauge extends StatelessWidget {
  const FormGauge({
    super.key,
    required this.angle,       // current measured joint angle in degrees, null = no pose
    required this.minAngle,    // target range lower bound (good form)
    required this.maxAngle,    // target range upper bound (good form)
    required this.visible,
    required this.onTap,
  });

  final double? angle;
  final double minAngle;
  final double maxAngle;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.25,
        duration: const Duration(milliseconds: 300),
        child: SizedBox(
          height: 90,
          child: CustomPaint(
            painter: _GaugePainter(
              angle: angle,
              minAngle: minAngle,
              maxAngle: maxAngle,
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.angle,
    required this.minAngle,
    required this.maxAngle,
  });

  final double? angle;
  final double minAngle;
  final double maxAngle;

  static const _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Pivot point sits at the bottom-centre of the canvas
    final center = Offset(size.width / 2, size.height);
    final radius = size.height - _strokeWidth;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Draw 3 arc segments.
    // Upper semicircle = start at pi (left), sweep +pi clockwise (through top to right).
    // Left red = 90°, orange = 60°, right red = 30° — orange sits right of centre.
    const leftSweep  = pi / 2;           // 90°
    const midSweep   = pi / 3;           // 60°
    const rightSweep = pi / 6;           // 30°
    _arc(canvas, arcRect, pi,                        leftSweep,  AppColors.error);     // left red
    _arc(canvas, arcRect, pi + leftSweep,            midSweep,   AppColors.secondary); // orange
    _arc(canvas, arcRect, pi + leftSweep + midSweep, rightSweep, AppColors.error);    // right red

    // Zone boundary tick marks
    _tick(canvas, center, radius, pi + leftSweep);
    _tick(canvas, center, radius, pi + leftSweep + midSweep);

    // Needle
    if (angle != null) {
      final needleRad = _toNeedleRad(angle!, minAngle, maxAngle);
      final tip = Offset(
        center.dx + (radius - 10) * cos(needleRad),
        center.dy + (radius - 10) * sin(needleRad),
      );
      canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      // Outer ring
      canvas.drawCircle(center, 8, Paint()..color = Colors.white);
      // Inner dot (creates a ring look)
      canvas.drawCircle(center, 4, Paint()..color = AppColors.background);
    } else {
      canvas.drawCircle(center, 8, Paint()..color = Colors.white38);
    }
  }

  void _arc(Canvas canvas, Rect rect, double start, double sweep, Color color) {
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt,
    );
  }

  void _tick(Canvas canvas, Offset center, double radius, double rad) {
    canvas.drawLine(
      Offset(center.dx + (radius - 20) * cos(rad),
             center.dy + (radius - 20) * sin(rad)),
      Offset(center.dx + (radius + 4) * cos(rad),
             center.dy + (radius + 4) * sin(rad)),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 2,
    );
  }

  // FR-2.2: Map measured joint angle → needle radian on the gauge arc.
  // Large angle (too shallow) → left red | Mid-target → green centre | Small (too deep) → right red
  double _toNeedleRad(double currentAngle, double minTarget, double maxTarget) {
    const margin = 50.0;
    final lo = minTarget - margin;
    final hi = maxTarget + margin;
    final normalized = ((hi - currentAngle) / (hi - lo)).clamp(0.0, 1.0);
    return pi + normalized * pi;
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.angle != angle;
}
