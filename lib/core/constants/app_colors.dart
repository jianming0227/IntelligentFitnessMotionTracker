import 'package:flutter/material.dart';

/// Brand + semantic color tokens.
///
/// Static fields default to the **dark** palette so existing widgets that
/// reference `AppColors.background` etc. keep working. For light-theme-aware
/// widgets, read from `Theme.of(context).colorScheme` instead.
class AppColors {
  AppColors._();

  // ── Brand accents ────────────────────────────────────────────────────────
  /// Orange accent used in the dark theme (CTAs, active nav, highlights).
  static const Color accentOrange = Color(0xFFFF9A2E);
  /// Lime accent used in the light theme.
  static const Color accentLime = Color(0xFFC8FF2D);

  // ── Dark palette ─────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF14161B);
  static const Color darkSurfaceElevated = Color(0xFF1E2127);
  static const Color darkBorder = Color(0xFF24272F);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9AA0AC);
  static const Color darkTextMuted = Color(0xFF5B6170);

  // ── Light palette ────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF4F5F7);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE6E8EC);
  static const Color lightTextPrimary = Color(0xFF0B0C0F);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFFA2A8B4);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF39E08B);
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF4F6B);

  // ── Legacy aliases (dark defaults — keep existing widgets compiling) ─────
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color border = darkBorder;
  static const Color primary = accentLime;
  static const Color secondary = accentOrange;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;

  // Gradient + glow (used by gradient_background)
  static const Color backgroundTop = Color(0xFF111317);
  static const Color backgroundBottom = Color(0xFF000000);
  static const Color primaryGlow = Color(0x40C8FF2D);
}
