import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  // const no change, static belongs to class itself, so we can write from other class
  //Backgrounds
  static const Color background = Color(0xFF0F1115);
  static const Color surface = Color(0xFF1A1D24);
  static const Color border = Color(0xFF2A2E38);

  // Brand
  static const Color primary = Color(0xFF4F8EF7); // action blue
  static const Color secondary = Color(0xFF39E08B); // success green

  // Status
  static const Color error = Color(0xFFFF4F6B); // warning

  // Gradient stops for premium tech atmosphere
  static const Color backgroundTop = Color(0xFF1A1F2E);  // slightly lighter at top
  static const Color backgroundBottom = Color(0xFF0A0C12); // darker at bottom

  // Glow color for focused elements
  static const Color primaryGlow = Color(0x404F8EF7); // primary @ 25% opacity

  // Text
  static const Color textPrimary = Color(0xFFECEFF8);
  static const Color textSecondary = Color(0xFF8A93AD);
  static const Color textMuted = Color(0xFF4A5270);
}
