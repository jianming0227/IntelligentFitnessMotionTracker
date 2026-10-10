import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/set_metrics.dart';

// FR-2.4: Composite endurance readout — the live companion to FormGauge.
//
// The gauge answers "is this rep deep enough right now". This bar answers
// "how well has the whole set gone so far", combining range of motion (are
// reps full-range) with time under tension (is the joint actually loaded).
// Fill comes from SetMetrics.endurance so the live bar and the stored set
// metrics share one formula.
//
// Reads 0% until the first rep closes: ROM is undefined before then.
class EnduranceBar extends StatelessWidget {
  const EnduranceBar({
    super.key,
    required this.romScore, // 0..1 mean per-rep excursion vs ideal
    required this.tutRatio, // 0..1 fraction of set time in the target zone
    required this.visible,
    required this.onTap,
  });

  final double romScore;
  final double tutRatio;
  final bool visible;
  final VoidCallback onTap;

  static const double _trackHeight = 10;

  double get _score => SetMetrics.endurance(romScore, tutRatio);

  // Same thresholds as SetMetrics.enduranceLabel.
  Color get _fillColor {
    if (_score >= 0.7) return AppColors.success;
    if (_score >= 0.4) return AppColors.warning;
    return AppColors.error;
  }

  String get _label {
    if (_score >= 0.7) return 'Strong';
    if (_score >= 0.4) return 'Fair';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final fill = _score.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.25,
        duration: const Duration(milliseconds: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'ENDURANCE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(fill * 100).round()}%  $_label',
                  style: TextStyle(
                    color: _fillColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              // SizedBox + StackFit.expand gives both layers a tight width;
              // a bare Container in a Stack would collapse.
              child: SizedBox(
                height: _trackHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.white.withValues(alpha: 0.14)),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      widthFactor: fill,
                      // Default is centre — the fill has to grow from the left.
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _fillColor,
                          boxShadow: [
                            BoxShadow(
                              color: _fillColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            // The two inputs stay visible so the user knows which one to fix:
            // low ROM means go deeper, low TUT means slow down.
            Text(
              'ROM ${(romScore * 100).round()}%   ·   '
              'TUT ${(tutRatio * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
