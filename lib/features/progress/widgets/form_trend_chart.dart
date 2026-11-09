import 'package:flutter/material.dart';

import '../logic/muscle_status.dart';
import '../models/session_record.dart';

/// Line chart of average form % per session, oldest on the left. A dashed
/// line marks the "good form" threshold the body map uses. No chart package:
/// one CustomPainter, same approach as the Home weekly bar chart.
class FormTrendChart extends StatelessWidget {
  const FormTrendChart({super.key, required this.sessions});

  /// Oldest first, all dated (see `formTrend`).
  final List<SessionRecord> sessions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = tt.bodyMedium?.copyWith(
      fontSize: 10,
      color: cs.onSurface.withValues(alpha: 0.5),
    );
    String day(DateTime d) => '${d.day}/${d.month}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _TrendPainter(
              values: [for (final s in sessions) s.avgFormPct / 100],
              line: cs.primary,
              grid: cs.onSurface.withValues(alpha: 0.12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(day(sessions.first.date!), style: muted),
            Text(
              '- - ${(goodFormThreshold * 100).round()}% good form',
              style: muted,
            ),
            Text(day(sessions.last.date!), style: muted),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.values, required this.line, required this.grid});

  /// 0–1 per session.
  final List<double> values;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double v) => size.height * (1 - v.clamp(0.0, 1.0));
    double x(int i) => values.length == 1
        ? size.width / 2
        : 6 + (size.width - 12) * i / (values.length - 1);

    // Dashed threshold line.
    final dash = Paint()
      ..color = grid
      ..strokeWidth = 1.5;
    final ty = y(goodFormThreshold);
    for (var dx = 0.0; dx < size.width; dx += 8) {
      canvas.drawLine(Offset(dx, ty), Offset(dx + 4, ty), dash);
    }

    final points = [for (var i = 0; i < values.length; i++) Offset(x(i), y(values[i]))];
    if (points.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(points, false),
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final dot = Paint()..color = line;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.line != line ||
      old.grid != grid ||
      old.values.length != values.length ||
      Iterable.generate(values.length).any((i) => old.values[i] != values[i]);
}
