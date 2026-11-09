import 'package:fitnessapp/features/progress/logic/muscle_status.dart';
import 'package:fitnessapp/features/progress/models/session_record.dart';
import 'package:fitnessapp/features/train/models/muscle.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRecord _session(String name, DateTime date, double form) =>
    SessionRecord(
      date: date,
      exerciseName: name,
      sets: [SetRecord(reps: 10, formScore: form)],
    );

void main() {
  final now = DateTime(2026, 11, 9, 20);
  DateTime daysAgo(int d) => DateTime(2026, 11, 9 - d, 8);

  test('no sessions: trackable muscles need work, others untracked', () {
    final s = muscleStatuses(const [], now);
    expect(s[Muscle.quads]!.status, MuscleStatus.needsWork);
    expect(s[Muscle.biceps]!.status, MuscleStatus.needsWork);
    expect(s[Muscle.chest]!.status, MuscleStatus.untracked);
    expect(s[Muscle.chest]!.trainedBy, isEmpty);
  });

  test('recent squat with good form turns its muscles green', () {
    final s = muscleStatuses([_session('Squat', daysAgo(1), 0.85)], now);
    expect(s[Muscle.quads]!.status, MuscleStatus.good);
    expect(s[Muscle.glutes]!.status, MuscleStatus.good);
    expect(s[Muscle.core]!.status, MuscleStatus.good, reason: 'secondary');
    expect(s[Muscle.biceps]!.status, MuscleStatus.needsWork);
    expect(s[Muscle.quads]!.sessionsInWindow, 1);
    expect(s[Muscle.quads]!.lastTrained, daysAgo(1));
  });

  test('low form this week is needsForm, however recent', () {
    final s = muscleStatuses([_session('Bicep Curl', daysAgo(0), 0.6)], now);
    expect(s[Muscle.biceps]!.status, MuscleStatus.needsForm);
    expect(s[Muscle.forearms]!.status, MuscleStatus.needsForm);
  });

  test('good form but 5+ days ago is due again (needsWork)', () {
    final s = muscleStatuses([_session('Squat', daysAgo(5), 0.9)], now);
    expect(s[Muscle.quads]!.status, MuscleStatus.needsWork);
    expect(s[Muscle.quads]!.sessionsInWindow, 1);
  });

  test('4 days ago still counts as good', () {
    final s = muscleStatuses([_session('Squat', daysAgo(4), 0.9)], now);
    expect(s[Muscle.quads]!.status, MuscleStatus.good);
  });

  test('sessions older than the window are ignored but remembered', () {
    final s = muscleStatuses([_session('Squat', daysAgo(8), 0.9)], now);
    expect(s[Muscle.quads]!.status, MuscleStatus.needsWork);
    expect(s[Muscle.quads]!.sessionsInWindow, 0);
    expect(s[Muscle.quads]!.lastTrained, daysAgo(8));
  });

  test('form is averaged across sessions in the window', () {
    final s = muscleStatuses([
      _session('Squat', daysAgo(1), 0.9),
      _session('Squat', daysAgo(2), 0.4),
    ], now);
    expect(s[Muscle.quads]!.avgForm, closeTo(0.65, 1e-9));
    expect(s[Muscle.quads]!.status, MuscleStatus.needsForm);
  });

  test('unknown exercises and empty sessions are skipped', () {
    final s = muscleStatuses([
      _session('Yoga', daysAgo(1), 0.9),
      SessionRecord(date: daysAgo(1), exerciseName: 'Squat', sets: const []),
    ], now);
    expect(s[Muscle.quads]!.status, MuscleStatus.needsWork);
  });
}
