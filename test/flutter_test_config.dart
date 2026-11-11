import 'dart:async';
import 'dart:io';

import 'package:fitnessapp/features/train/data/exercise_catalog.dart';

/// Runs before every test file: loads the bundled exercise catalog (the
/// same rows the app ships), since the app no longer hardcodes exercises.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ExerciseCatalog.use(
    ExerciseCatalog.parseJson(
      File(ExerciseCatalog.bundledAsset).readAsStringSync(),
    ),
  );
  await testMain();
}
