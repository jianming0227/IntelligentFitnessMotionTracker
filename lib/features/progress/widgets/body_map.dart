import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../train/models/muscle.dart';
import '../logic/muscle_status.dart';

/// Colour for each [MuscleStatus]. Untracked is a dim grey so it reads as
/// "no data" on the dark figure.
Color muscleStatusColor(MuscleStatus s, ColorScheme cs) => switch (s) {
  MuscleStatus.good => AppColors.success,
  MuscleStatus.needsForm => AppColors.warning,
  MuscleStatus.needsWork => AppColors.error,
  MuscleStatus.untracked => AppColors.darkTextMuted.withValues(alpha: 0.45),
};

String muscleStatusLabel(MuscleStatus s) => switch (s) {
  MuscleStatus.good => 'Trained well',
  MuscleStatus.needsForm => 'Needs better form',
  MuscleStatus.needsWork => 'Needs work',
  MuscleStatus.untracked => 'Not tracked yet',
};

/// Front and back anatomy figures side by side: dark body, white outlines,
/// each muscle filled with its status colour. Tapping a muscle calls
/// [onMuscleTap].
///
/// Shapes are drawn on a 200 Ã— 420 design canvas and scaled to fit, so the
/// same paths serve painting and hit-testing.
class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.stats,
    required this.onMuscleTap,
  });

  final Map<Muscle, MuscleStat> stats;
  final ValueChanged<Muscle> onMuscleTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final front in [true, false])
          Expanded(
            child: Column(
              children: [
                _Figure(front: front, stats: stats, onMuscleTap: onMuscleTap),
                const SizedBox(height: 6),
                Text(front ? 'Front' : 'Back', style: tt.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.front,
    required this.stats,
    required this.onMuscleTap,
  });

  final bool front;
  final Map<Muscle, MuscleStat> stats;
  final ValueChanged<Muscle> onMuscleTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: _designSize.aspectRatio,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / _designSize.width;
          final regions = front ? _frontRegions : _backRegions;
          return GestureDetector(
            onTapUp: (d) {
              final p = d.localPosition / scale;
              // Last drawn = on top, so test in reverse paint order.
              for (final (muscle, path) in regions.reversed) {
                if (path.contains(p)) return onMuscleTap(muscle);
              }
            },
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxWidth / _designSize.aspectRatio),
              painter: _BodyPainter(
                regions: regions,
                scale: scale,
                fills: {
                  for (final m in Muscle.values)
                    m: muscleStatusColor(
                      stats[m]?.status ?? MuscleStatus.untracked,
                      cs,
                    ),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.regions,
    required this.scale,
    required this.fills,
  });

  final List<(Muscle, Path)> regions;
  final double scale;
  final Map<Muscle, Color> fills;

  static const _body = AppColors.darkSurfaceElevated;
  static const _line = AppColors.darkTextPrimary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    canvas.drawPath(_silhouette, Paint()..color = _body);
    canvas.drawPath(
      _silhouette,
      Paint()
        ..color = _line.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    final stroke = Paint()
      ..color = _line.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;
    for (final (muscle, path) in regions) {
      canvas.drawPath(path, Paint()..color = fills[muscle]!);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      !identical(old.regions, regions) ||
      old.scale != scale ||
      !Muscle.values.every((m) => old.fills[m] == fills[m]);
}

// â”€â”€ Geometry (200 Ã— 420 design canvas, figure facing the viewer) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//
// Shapes are listed as a few points on the viewer's left half and smoothed
// into curves, then mirrored to the right. Tweak a point to reshape a muscle.

const _designSize = Size(200, 420);

/// x â†’ 200 âˆ’ x: mirrors across the figure's centre line (column-major 4Ã—4).
final _mirror = Float64List.fromList([
  -1, 0, 0, 0, //
  0, 1, 0, 0, //
  0, 0, 1, 0, //
  200, 0, 0, 1,
]);

/// Closed smooth curve through [pts] (Catmull-Rom converted to cubics).
Path _smooth(List<(double, double)> pts) {
  final p = [for (final (x, y) in pts) Offset(x, y)];
  final n = p.length;
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = p[(i - 1 + n) % n];
    final p1 = p[i];
    final p2 = p[(i + 1) % n];
    final p3 = p[(i + 2) % n];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// Left half points plus their mirror, as one closed symmetric shape.
/// [half] runs top to bottom on the left side, ending near x = 100.
Path _symmetric(List<(double, double)> half) => _smooth([
  ...half,
  for (final (x, y) in half.reversed) (200 - x, y),
]);

Path _oval(double cx, double cy, double w, double h) =>
    Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h));

Path _rrect(double l, double t, double r, double b, double radius) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

/// Left shape plus its mirror image on the right.
List<Path> _pair(Path left) => [left, left.transform(_mirror)];

List<(Muscle, Path)> _both(Muscle m, List<(double, double)> leftPts) => [
  for (final p in _pair(_smooth(leftPts))) (m, p),
];

/// Whole body outline as one path, so the white line has no seams inside.
final Path _silhouette = () {
  final pieces = <Path>[
    _oval(100, 30, 32, 40), // head
    _rrect(90, 42, 110, 68, 4), // neck
    _symmetric(const [
      (90, 60), (66, 66), (54, 76), (58, 108), (64, 140), //
      (70, 172), (66, 198), (64, 214), (100, 222),
    ]), // torso
    ..._pair(_smooth(const [
      (58, 70), (46, 82), (41, 110), (39, 140), (42, 154), //
      (55, 154), (59, 128), (62, 96),
    ])), // upper arm
    ..._pair(_smooth(const [
      (40, 146), (33, 172), (31, 202), (34, 230), (45, 230), //
      (49, 202), (55, 172), (57, 148),
    ])), // forearm
    ..._pair(_oval(39, 242, 16, 26)), // hand
    ..._pair(_smooth(const [
      (66, 198), (61, 232), (63, 272), (69, 322), (84, 328), //
      (95, 322), (97, 262), (99, 214),
    ])), // thigh
    ..._pair(_smooth(const [
      (70, 316), (65, 350), (72, 392), (82, 400), (92, 396), //
      (94, 360), (95, 318),
    ])), // lower leg
    ..._pair(_oval(84, 408, 24, 14)), // foot
  ];
  return pieces.reduce((a, b) => Path.combine(PathOperation.union, a, b));
}();

final List<(Muscle, Path)> _frontRegions = [
  ..._both(Muscle.shoulders, const [
    (60, 69), (50, 77), (45, 92), (49, 102), (58, 92), (65, 78),
  ]),
  ..._both(Muscle.chest, const [
    (67, 72), (64, 86), (68, 104), (82, 111), (98, 106), (98, 78), (84, 70),
  ]),
  ..._both(Muscle.biceps, const [
    (49, 100), (45, 116), (45, 134), (49, 147), (55, 140), (58, 118), (56, 102),
  ]),
  ..._both(Muscle.forearms, const [
    (41, 154), (37, 174), (37, 198), (41, 216), (47, 200), (51, 176), (53, 156),
  ]),
  // Six-pack: three blocks per side, then the lower abs.
  for (final (t, b) in const [(112.0, 128.0), (131.0, 147.0), (150.0, 166.0)])
    for (final p in _pair(_rrect(88, t, 98, b, 4))) (Muscle.core, p),
  ..._both(Muscle.core, const [(89, 170), (88, 184), (95, 196), (98, 192), (98, 170)]),
  ..._both(Muscle.core, const [
    (70, 118), (68, 142), (72, 168), (80, 182), (84, 160), (84, 124),
  ]), // obliques
  ..._both(Muscle.hipFlexors, const [
    (74, 188), (80, 202), (92, 216), (98, 214), (90, 200),
  ]),
  ..._both(Muscle.quads, const [
    (68, 228), (65, 262), (71, 300), (79, 312), (80, 270), (77, 238),
  ]), // outer quad
  ..._both(Muscle.quads, const [
    (83, 224), (81, 262), (84, 300), (89, 314), (93, 302), (94, 258), (93, 230),
  ]), // inner quad
  ..._both(Muscle.calves, const [
    (70, 332), (68, 352), (72, 374), (76, 362), (77, 340),
  ]),
];

final List<(Muscle, Path)> _backRegions = [
  (
    Muscle.back,
    _symmetric(const [(100, 52), (88, 62), (68, 70), (80, 80), (92, 102), (100, 132)]),
  ), // traps
  ..._both(Muscle.shoulders, const [
    (60, 69), (50, 77), (45, 92), (49, 102), (58, 92), (65, 78),
  ]),
  ..._both(Muscle.back, const [
    (66, 84), (62, 106), (68, 140), (80, 170), (92, 176), (96, 150), (88, 114), (78, 92),
  ]), // lats
  ..._both(Muscle.back, const [(91, 180), (89, 198), (98, 202), (98, 178)]), // lower back
  ..._both(Muscle.triceps, const [
    (47, 92), (43, 112), (43, 136), (48, 149), (55, 141), (58, 114), (56, 96),
  ]),
  ..._both(Muscle.forearms, const [
    (41, 154), (37, 174), (37, 198), (41, 216), (47, 200), (51, 176), (53, 156),
  ]),
  ..._both(Muscle.glutes, const [
    (67, 206), (64, 226), (72, 242), (90, 244), (98, 236), (98, 212), (84, 202),
  ]),
  ..._both(Muscle.hamstrings, const [
    (68, 252), (66, 282), (72, 310), (81, 316), (83, 282), (79, 254),
  ]),
  ..._both(Muscle.hamstrings, const [
    (86, 252), (86, 290), (88, 316), (93, 310), (95, 282), (94, 252),
  ]),
  ..._both(Muscle.calves, const [
    (70, 334), (68, 354), (74, 378), (82, 372), (83, 342), (78, 328),
  ]),
  ..._both(Muscle.calves, const [
    (86, 328), (85, 352), (88, 374), (92, 368), (93, 348), (91, 330),
  ]),
];

/// Colour key under the map.
class BodyMapLegend extends StatelessWidget {
  const BodyMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final s in MuscleStatus.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: muscleStatusColor(s, cs),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(muscleStatusLabel(s), style: tt.bodyMedium?.copyWith(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}
