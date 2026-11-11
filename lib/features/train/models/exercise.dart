import '../data/exercise_catalog.dart';
import '../data/exercise_tutorials.dart';
import 'muscle.dart';

enum ExerciseCategory { legs, upper, core }

/// Joint angle at the bottom of a rep. Squat: knee bends, angle gets
/// [small]. Bicep curl: the rep starts with the arm straight, angle [large].
enum AngleAtBottom { small, large }

/// Body points an exercise can measure; each has a left and right ML Kit
/// landmark (`leftKnee`, `rightKnee` ...).
const trackableJoints = {
  'shoulder',
  'elbow',
  'wrist',
  'hip',
  'knee',
  'ankle',
  'heel',
  'footIndex',
};

/// Home card crop of the exercise photo: which part stays visible
/// ([alignX], [alignY], -1..1) and a zoom around ([zoomX], [zoomY]).
class ImageFraming {
  const ImageFraming({
    this.alignX = 0,
    this.alignY = 0,
    this.zoom = 1,
    this.zoomX = 0,
    this.zoomY = 0,
  });

  final double alignX, alignY, zoom, zoomX, zoomY;

  static ImageFraming fromJson(Object? raw) {
    if (raw is! Map) return const ImageFraming();
    double n(String k, double d) => (raw[k] as num?)?.toDouble() ?? d;
    return ImageFraming(
      alignX: n('alignX', 0),
      alignY: n('alignY', 0),
      zoom: n('zoom', 1),
      zoomX: n('zoomX', 0),
      zoomY: n('zoomY', 0),
    );
  }
}

/// One exercise of the catalog: a row of the Supabase `exercises` table
/// (see supabase/README_exercises.md). Nothing about a specific exercise is
/// hardcoded in the app: tracking, coaching, plan and body map all read these
/// fields.
///
/// Tunables for accuracy:
///   • [targetAngleMin] / [targetAngleMax] — green zone for the form gauge.
///   • [repBottomAngleStrict] / [repTopAngleStrict] — angles the joint must
///     cross to register a rep, in the direction set by [angleAtBottom].
///   • [romFullSpanDeg] — joint travel of a textbook rep; per-rep ROM is
///     scored against it.
///   • [minRepDurationMs] — discards crossings faster than this (jitter).
///   • [minLandmarkConfidence] — drop frames below this ML Kit likelihood.
///   • [restBetweenSetsSec] — countdown between sets.
///
/// Analytics: [met] for calories (kcal = MET × kg × hours), muscles for the
/// body map (secondary counts half).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.joints,
    required this.angleAtBottom,
    required this.targetAngleMin,
    required this.targetAngleMax,
    required this.repBottomAngleStrict,
    required this.repTopAngleStrict,
    required this.romFullSpanDeg,
    required this.met,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    this.formCues = const [],
    this.minRepDurationMs = 700,
    this.minLandmarkConfidence = 0.55,
    this.restBetweenSetsSec = 30,
    this.sortOrder = 100,
    this.imageUrl,
    this.imageFraming = const ImageFraming(),
    this.tutorial,
  });

  final String id;
  final String name;
  final ExerciseCategory category;
  final String description;

  /// Three body points; the angle is measured at the middle one.
  final List<String> joints;
  final AngleAtBottom angleAtBottom;

  // FR-2.2: form-gauge green zone (degrees).
  final double targetAngleMin;
  final double targetAngleMax;

  // FR-2.4: stricter angles the rep state machine must cross.
  final double repBottomAngleStrict;
  final double repTopAngleStrict;

  // FR-2.4: degrees of joint travel in an ideal full-range rep.
  final double romFullSpanDeg;

  final int minRepDurationMs;
  final double minLandmarkConfidence;
  final int restBetweenSetsSec;

  /// Spoken when form drops.
  final List<String> formCues;

  final double met;
  final List<Muscle> primaryMuscles;
  final List<Muscle> secondaryMuscles;

  final int sortOrder;

  /// Asset path (`assets/...`) or public URL; null = icon placeholder.
  final String? imageUrl;
  final ImageFraming imageFraming;

  /// 3D demo, null when the exercise has none.
  final ExerciseTutorial? tutorial;

  /// The catalog loaded at startup (Supabase → cache → bundled copy).
  static List<Exercise> get all => ExerciseCatalog.current;

  static Exercise? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Looks up a catalog entry by display name (what Supabase stores in
  /// `workout_sessions.exercise_type`). Null for unknown or renamed exercises.
  static Exercise? byName(String name) {
    for (final e in all) {
      if (e.name.toLowerCase() == name.toLowerCase()) return e;
    }
    return null;
  }

  String get categoryLabel => switch (category) {
    ExerciseCategory.legs => 'Legs',
    ExerciseCategory.upper => 'Upper',
    ExerciseCategory.core => 'Core',
  };

  /// One `exercises` row. Throws [FormatException] when a field the camera
  /// needs is missing or invalid; the catalog skips such rows.
  factory Exercise.fromJson(Map<String, dynamic> row) {
    T req<T>(String k) {
      final v = row[k];
      if (v is T) return v;
      throw FormatException('exercise "${row['id']}": bad or missing "$k"');
    }

    double num_(String k) => req<num>(k).toDouble();
    List<String> strings(String k) =>
        (row[k] as List?)?.whereType<String>().toList() ?? const [];
    // Unknown muscle names are skipped (the body map can't draw them).
    List<Muscle> muscles(String k) => [
      for (final m in strings(k)) ?Muscle.values.asNameMap()[m],
    ];

    final joints = strings('joints');
    if (joints.length != 3 || !joints.every(trackableJoints.contains)) {
      throw FormatException(
        'exercise "${row['id']}": joints must be 3 of $trackableJoints',
      );
    }
    final category = ExerciseCategory.values.asNameMap()[row['category']];
    final bottom = AngleAtBottom.values.asNameMap()[row['angle_at_bottom']];
    if (category == null || bottom == null) {
      throw FormatException(
        'exercise "${row['id']}": bad category or angle_at_bottom',
      );
    }

    return Exercise(
      id: req<String>('id'),
      name: req<String>('name'),
      category: category,
      description: row['description'] as String? ?? '',
      joints: joints,
      angleAtBottom: bottom,
      targetAngleMin: num_('target_angle_min'),
      targetAngleMax: num_('target_angle_max'),
      repBottomAngleStrict: num_('rep_bottom_angle'),
      repTopAngleStrict: num_('rep_top_angle'),
      romFullSpanDeg: num_('rom_full_span_deg'),
      minRepDurationMs: (row['min_rep_ms'] as num?)?.toInt() ?? 700,
      minLandmarkConfidence:
          (row['min_landmark_confidence'] as num?)?.toDouble() ?? 0.55,
      restBetweenSetsSec: (row['rest_seconds'] as num?)?.toInt() ?? 30,
      formCues: strings('form_cues'),
      met: (row['met'] as num?)?.toDouble() ?? 3.5,
      primaryMuscles: muscles('primary_muscles'),
      secondaryMuscles: muscles('secondary_muscles'),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      imageUrl: row['image_url'] as String?,
      imageFraming: ImageFraming.fromJson(row['image_framing']),
      tutorial: ExerciseTutorial.fromJson(row['tutorial']),
    );
  }
}
