/// Muscle groups shown on the Progress body map. Groups with no exercise in
/// [Exercise.all] yet (chest, back, triceps) render as "not tracked".
enum Muscle {
  quads,
  glutes,
  hamstrings,
  calves,
  hipFlexors,
  core,
  biceps,
  forearms,
  shoulders,
  chest,
  back,
  triceps;

  String get label => switch (this) {
    Muscle.quads => 'Quads',
    Muscle.glutes => 'Glutes',
    Muscle.hamstrings => 'Hamstrings',
    Muscle.calves => 'Calves',
    Muscle.hipFlexors => 'Hip flexors',
    Muscle.core => 'Core',
    Muscle.biceps => 'Biceps',
    Muscle.forearms => 'Forearms',
    Muscle.shoulders => 'Shoulders',
    Muscle.chest => 'Chest',
    Muscle.back => 'Back',
    Muscle.triceps => 'Triceps',
  };
}
