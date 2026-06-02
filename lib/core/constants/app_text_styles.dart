import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens.
///
/// Colors are intentionally omitted so each style adapts to the active theme
/// via `TextTheme`. If you need a one-off colored variant, use `.copyWith`.
class AppTextStyles {
  AppTextStyles._();

  // Hero / marketing (e.g. "PUSH YOURSELF HARDER")
  static TextStyle display = GoogleFonts.outfit(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.05,
  );

  // Section + screen titles
  static TextStyle titleLarge = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle titleMedium = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static TextStyle titleSmall = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Body
  static TextStyle bodyLarge = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle bodyMedium = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Buttons / pill CTAs (uppercase in the reference)
  static TextStyle button = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  // Chips, tags, meta
  static TextStyle caption = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}
