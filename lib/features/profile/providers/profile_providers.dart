import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile_biometrics.dart';

// FR-1.2: Persists and exposes the user's biometric profile, keyed by Supabase
// user ID so multiple accounts on the same device stay fully isolated.
// Returns null until the survey has been completed at least once.
class ProfileController extends AsyncNotifier<UserProfileBiometrics?> {
  // Returns the current user's UID, or 'demo' in offline/demo mode.
  String get _uid =>
      Supabase.instance.client.auth.currentUser?.id ?? 'demo';

  String get _keyGender => '${_uid}_profile_gender';
  String get _keyAge => '${_uid}_profile_age';
  String get _keyHeight => '${_uid}_profile_height_cm';
  String get _keyWeight => '${_uid}_profile_weight_kg';
  String get _keyGoal => '${_uid}_profile_fitness_goal';
  String get _keyLevel => '${_uid}_profile_experience_level';

  @override
  Future<UserProfileBiometrics?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString(_keyGender);
    final age = prefs.getInt(_keyAge);
    final h = prefs.getDouble(_keyHeight);
    final w = prefs.getDouble(_keyWeight);
    final g = prefs.getString(_keyGoal);
    final l = prefs.getString(_keyLevel);
    if (gender == null || age == null || h == null ||
        w == null || g == null || l == null) {
      return null;
    }
    return UserProfileBiometrics(
      gender: gender,
      age: age,
      heightCm: h,
      weightKg: w,
      fitnessGoal: g,
      experienceLevel: l,
    );
  }

  Future<void> save({
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
    required String experienceLevel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, gender);
    await prefs.setInt(_keyAge, age);
    await prefs.setDouble(_keyHeight, heightCm);
    await prefs.setDouble(_keyWeight, weightKg);
    await prefs.setString(_keyGoal, fitnessGoal);
    await prefs.setString(_keyLevel, experienceLevel);
    state = AsyncData(UserProfileBiometrics(
      gender: gender,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      fitnessGoal: fitnessGoal,
      experienceLevel: experienceLevel,
    ));
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileController, UserProfileBiometrics?>(
        ProfileController.new);
