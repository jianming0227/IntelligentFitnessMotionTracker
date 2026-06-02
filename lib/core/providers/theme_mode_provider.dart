import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the user-selected ThemeMode. Defaults to system; the home-screen
/// toggle flips between light and dark so the design can be previewed in both.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
