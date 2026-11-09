import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A rotatable 3D demo for one exercise: an animated glTF model (made in
/// Blender with a free MakeHuman/MPFB character, see design_source/) plus a
/// still poster shown while the 3D view loads.
class ExerciseTutorial {
  const ExerciseTutorial({
    required this.model,
    required this.poster,
    required this.animation,
    required this.loopSeconds,
    required this.heroOrbit,
    required this.heroTarget,
    required this.fullOrbit,
    required this.fullTarget,
    this.heroFieldOfView = '28deg',
  });

  /// `assets/models/<id>.glb`
  final String model;

  /// `assets/tutorials/<id>_poster.png`
  final String poster;

  /// Animation clip inside the .glb.
  final String animation;

  /// Length of one loop of [animation]; the cue captions repeat with it.
  final double loopSeconds;

  /// `<model-viewer>` camera for the detail-page hero (`theta phi radius`)
  /// and the point it looks at (`x y z`, metres). Chosen per exercise: the
  /// curl frames the upper body, the squat the whole body from the side.
  final String heroOrbit;
  final String heroTarget;
  final String heroFieldOfView;

  /// Starting camera in the fullscreen viewer (the user can rotate/zoom).
  final String fullOrbit;
  final String fullTarget;
}

/// Exercises that have a 3D demo. Others keep their hero photo.
const Map<String, ExerciseTutorial> exerciseTutorials = {
  'squat': ExerciseTutorial(
    model: 'assets/models/squat.glb',
    poster: 'assets/tutorials/squat_poster.png',
    animation: 'Squat',
    // 1.4 s muscle-highlight pause (quads + glutes glow), then one rep.
    loopSeconds: 5.8,
    // Three-quarter side view: hip and knee angles read clearly.
    // Pulled back and aimed low so the legs stay above the info panel.
    heroOrbit: '-60deg 80deg 4.6m',
    heroTarget: '0m 0.85m 0m',
    heroFieldOfView: '30deg',
    // 'auto' radius/target: model-viewer frames the whole body for the screen.
    fullOrbit: '-60deg 80deg auto',
    fullTarget: 'auto auto auto',
  ),
  'bicep_curl': ExerciseTutorial(
    model: 'assets/models/bicep_curl.glb',
    poster: 'assets/tutorials/bicep_curl_poster.png',
    animation: 'BicepCurl',
    // 1.4 s muscle-highlight pause (biceps glow), then one rep.
    loopSeconds: 5.6,
    // Front three-quarter, upper body above the info panel.
    heroOrbit: '-30deg 80deg 2.9m',
    heroTarget: '0m 1.15m 0m',
    fullOrbit: '-30deg 80deg auto',
    fullTarget: 'auto auto auto',
  ),
};

ExerciseTutorial? tutorialFor(String exerciseId) =>
    exerciseTutorials[exerciseId];

/// One form cue shown from [at] seconds into each loop.
class TutorialCue {
  const TutorialCue({required this.at, required this.text});

  final double at;
  final String text;
}

/// Parses `tutorial_cues.json`: `{ "<id>": [{"at": 0.3, "text": "..."}] }`.
/// Cues come back sorted by time; malformed entries are skipped.
Map<String, List<TutorialCue>> parseTutorialCues(String json) {
  final raw = jsonDecode(json);
  if (raw is! Map) return const {};
  return {
    for (final MapEntry(:key, :value) in raw.entries)
      if (value is List)
        '$key': [
          for (final c in value.whereType<Map>())
            if (c['at'] is num && c['text'] is String)
              TutorialCue(at: (c['at'] as num).toDouble(), text: c['text']),
        ]..sort((a, b) => a.at.compareTo(b.at)),
  };
}

/// The cue to show [elapsed] after the animation started, given a loop of
/// [loopSeconds]: the last cue that has started in the current loop. Before
/// the first cue of a loop, the previous loop's last cue stays up.
TutorialCue? cueAt(
  List<TutorialCue> cues,
  Duration elapsed, {
  required double loopSeconds,
}) {
  if (cues.isEmpty) return null;
  final s = (elapsed.inMilliseconds / 1000) % loopSeconds;
  TutorialCue? current;
  for (final c in cues) {
    if (c.at <= s) current = c;
  }
  return current ?? (elapsed.inMilliseconds / 1000 >= loopSeconds ? cues.last : null);
}

final tutorialCuesProvider =
    FutureProvider<Map<String, List<TutorialCue>>>((ref) async {
  try {
    return parseTutorialCues(
      await rootBundle.loadString('assets/tutorials/tutorial_cues.json'),
    );
  } catch (_) {
    return const {};
  }
});
