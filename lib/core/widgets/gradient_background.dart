import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6),       // slightly above center
          radius: 1.2,
          colors: [
            AppColors.backgroundTop,
            AppColors.backgroundBottom,
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}
