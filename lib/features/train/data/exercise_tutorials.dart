import '../models/exercise.dart';

/// A rotatable 3D demo for one exercise: an animated glTF model (made in
/// Blender with a free MakeHuman/MPFB character, see design_source/) plus a
/// still poster shown while the 3D view loads. Comes from the `tutorial`
/// column of the `exercises` table.
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
    this.cues = const [],
  });

  /// `.glb` file: asset path or public URL.
  final String model;

  /// Still image: asset path or public URL.
  final String poster;

  /// Animation clip inside the .glb.
  final String animation;

  /// Length of one loop of [animation]; the cue captions repeat with it.
  final double loopSeconds;

  /// `<model-viewer>` camera for the detail-page hero (`theta phi radius`)
  /// and the point it looks at (`x y z`, metres).
  final String heroOrbit;
  final String heroTarget;
  final String heroFieldOfView;

  /// Starting camera in the fullscreen viewer (the user can rotate/zoom).
  final String fullOrbit;
  final String fullTarget;

  /// Timed captions shown over the fullscreen demo, sorted by time.
  final List<TutorialCue> cues;

  /// Null when [raw] is missing or lacks the model, poster or animation.
  static ExerciseTutorial? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final model = raw['model'], poster = raw['poster'];
    final animation = raw['animation'], loop = raw['loopSeconds'];
    if (model is! String || poster is! String || animation is! String) {
      return null;
    }
    String s(String k, String d) => raw[k] is String ? raw[k] as String : d;
    return ExerciseTutorial(
      model: model,
      poster: poster,
      animation: animation,
      loopSeconds: loop is num ? loop.toDouble() : 5,
      heroOrbit: s('heroOrbit', '0deg 80deg auto'),
      heroTarget: s('heroTarget', 'auto auto auto'),
      heroFieldOfView: s('heroFieldOfView', '28deg'),
      fullOrbit: s('fullOrbit', '0deg 80deg auto'),
      fullTarget: s('fullTarget', 'auto auto auto'),
      cues: parseCues(raw['cues']),
    );
  }
}

/// The 3D demo of an exercise, null when it has none.
ExerciseTutorial? tutorialFor(String exerciseId) =>
    Exercise.byId(exerciseId)?.tutorial;

/// One form cue shown from [at] seconds into each loop.
class TutorialCue {
  const TutorialCue({required this.at, required this.text});

  final double at;
  final String text;
}

/// Parses `[{"at": 0.3, "text": "..."}]`, sorted by time; malformed entries
/// are skipped.
List<TutorialCue> parseCues(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final c in raw.whereType<Map>())
      if (c['at'] is num && c['text'] is String)
        TutorialCue(at: (c['at'] as num).toDouble(), text: c['text'] as String),
  ]..sort((a, b) => a.at.compareTo(b.at));
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
  return current ??
      (elapsed.inMilliseconds / 1000 >= loopSeconds ? cues.last : null);
}
