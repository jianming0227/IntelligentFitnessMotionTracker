import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_log.dart';
import '../models/exercise.dart';

/// The exercise catalog, from the Supabase `exercises` table.
///
/// Loaded once at startup by [init], in this order, each step replacing the
/// previous one when it works:
///   1. `assets/data/exercises.json`, the copy bundled in the app (same
///      columns as the table), so a first launch offline still works
///   2. the last list downloaded, cached in SharedPreferences
///   3. the live table (waits at most [_timeout])
/// Rows that can't be read are skipped and logged, so one bad row never
/// breaks the app. A new row shows up on the next app launch.
class ExerciseCatalog {
  ExerciseCatalog._();

  static const bundledAsset = 'assets/data/exercises.json';
  static const _cacheKey = 'exercise_catalog_rows';
  static const _timeout = Duration(seconds: 4);

  static List<Exercise> _current = const [];

  /// Catalog in use, sorted by `sort_order`.
  static List<Exercise> get current => _current;

  /// Replaces the catalog (startup, tests).
  static void use(List<Exercise> exercises) => _current = exercises;

  /// Exercises from table rows: active ones only, bad rows skipped, sorted.
  static List<Exercise> parse(Iterable<Object?> rows) {
    final out = <Exercise>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      if (row['is_active'] == false) continue;
      try {
        out.add(Exercise.fromJson(row));
      } on FormatException catch (e) {
        AppLog.warn('Catalog', 'Skipped row: ${e.message}');
      }
    }
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return out;
  }

  static List<Exercise> parseJson(String json) =>
      parse(jsonDecode(json) as List);

  static Future<void> init() async {
    // 1. Bundled copy.
    try {
      _current = parseJson(await rootBundle.loadString(bundledAsset));
    } catch (e) {
      AppLog.warn('Catalog', 'Bundled catalog unreadable: $e');
    }

    // 2. Last download.
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final list = parseJson(cached);
        if (list.isNotEmpty) _current = list;
      } catch (e) {
        AppLog.warn('Catalog', 'Cached catalog unreadable: $e');
      }
    }

    // 3. Live table.
    try {
      final rows = await Supabase.instance.client
          .from('exercises')
          .select()
          .timeout(_timeout);
      final list = parse(rows);
      if (list.isNotEmpty) {
        _current = list;
        await prefs.setString(_cacheKey, jsonEncode(rows));
      }
      AppLog.ok('Catalog', 'Loaded ${list.length} exercises from Supabase');
    } catch (e) {
      AppLog.warn(
        'Catalog',
        'Using ${cached != null ? 'cached' : 'bundled'} catalog '
            '(${_current.length} exercises): $e',
      );
    }
  }
}
