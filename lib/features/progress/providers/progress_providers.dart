import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/session_record.dart';

/// Workout history for analytics, oldest first.
///
/// Signed in: Supabase `workout_sessions` (survives sign-out and new phones).
/// Demo mode, offline, or an empty cloud table: the local `session_history`
/// strings. Re-runs on every auth change so a new account never sees the
/// previous one's data. Invalidate it after saving a session.
final sessionHistoryProvider = FutureProvider<List<SessionRecord>>((ref) async {
  ref.watch(authStateStreamProvider);
  final service = ref.watch(supabaseServiceProvider);

  final rows = await service.fetchWorkoutSessions();
  if (rows != null && rows.isNotEmpty) {
    return rows.map(SessionRecord.fromSupabaseRow).toList();
  }

  final prefs = await SharedPreferences.getInstance();
  final uid = service.currentUser?.id ?? 'demo';
  final raw = prefs.getStringList('${uid}_session_history') ?? [];
  return raw.map(SessionRecord.fromLocalHistory).toList();
});
