import 'package:fitnessapp/features/train/models/exercise.dart';
import 'package:fitnessapp/features/train/models/rep_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bicepCurl = Exercise.all.firstWhere((e) => e.id == 'bicep_curl');
  final squat = Exercise.all.firstWhere((e) => e.id == 'squat');

  // Bicep curl thresholds: bottom > 162° (extended), top < 40° (curled),
  // minRepDurationMs 600.
  group('RepStateMachine — bicep curl', () {
    test('counts one complete rep', () {
      final machine = RepStateMachine(exercise: bicepCurl);
      final t0 = DateTime(2026, 1, 1);

      // First confident frame anchors the phase clock — no transition yet.
      expect(machine.feed(165, t0), false);
      // 700ms later, still extended → bottom phase locks.
      expect(machine.feed(165, t0.add(const Duration(milliseconds: 700))),
          false);
      // Curl arrives but phase is only 0ms old → guarded.
      expect(
          machine.feed(35, t0.add(const Duration(milliseconds: 700))), false);
      // 700ms into the down phase, curled past 40° → rep completes.
      expect(
          machine.feed(35, t0.add(const Duration(milliseconds: 1400))), true);

      expect(machine.repCount, 1);
    });

    test('rejects rep when arm only extends to 150° (threshold 162°)', () {
      final machine = RepStateMachine(exercise: bicepCurl);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(150, t0);
      machine.feed(150, t0.add(const Duration(milliseconds: 700)));
      machine.feed(35, t0.add(const Duration(milliseconds: 1400)));

      expect(machine.repCount, 0); // bottom never locked
    });

    test('rejects rep when curl stops at 50° (threshold 40°)', () {
      final machine = RepStateMachine(exercise: bicepCurl);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(165, t0);
      machine.feed(165, t0.add(const Duration(milliseconds: 700)));
      machine.feed(50, t0.add(const Duration(milliseconds: 1400)));

      expect(machine.repCount, 0); // top never reached
    });

    test('rejects sub-600ms jitter crossing', () {
      final machine = RepStateMachine(exercise: bicepCurl);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(165, t0);
      machine.feed(165, t0.add(const Duration(milliseconds: 700)));
      // Top crossing only 200ms after entering the down phase → guarded.
      machine.feed(35, t0.add(const Duration(milliseconds: 900)));

      expect(machine.repCount, 0);
    });

    test('counts 3 consecutive reps', () {
      final machine = RepStateMachine(exercise: bicepCurl);
      var t = DateTime(2026, 1, 1);

      for (var i = 0; i < 3; i++) {
        machine.feed(165, t);
        t = t.add(const Duration(milliseconds: 700));
        machine.feed(165, t);
        t = t.add(const Duration(milliseconds: 700));
        machine.feed(35, t);
      }

      expect(machine.repCount, 3);
    });

    test('records rep duration from bottom lock to top crossing', () {
      final machine = RepStateMachine(exercise: bicepCurl);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(165, t0);
      machine.feed(165, t0.add(const Duration(milliseconds: 700)));
      machine.feed(35, t0.add(const Duration(milliseconds: 1400)));

      expect(machine.repDurationsMs, [700]);
    });

    test('resetRepCount zeroes the counter, keeps durations until cleared',
        () {
      final machine = RepStateMachine(exercise: bicepCurl);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(165, t0);
      machine.feed(165, t0.add(const Duration(milliseconds: 700)));
      machine.feed(35, t0.add(const Duration(milliseconds: 1400)));
      expect(machine.repCount, 1);

      machine.resetRepCount();
      expect(machine.repCount, 0);
      expect(machine.repDurationsMs.length, 1);

      machine.clearDurations();
      expect(machine.repDurationsMs, isEmpty);
    });
  });

  // Squat thresholds are inverted: bottom < 95° (deep), top > 168° (standing),
  // minRepDurationMs 800.
  group('RepStateMachine — squat', () {
    test('counts one complete rep', () {
      final machine = RepStateMachine(exercise: squat);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(90, t0); // anchor
      machine.feed(90, t0.add(const Duration(milliseconds: 900))); // bottom
      final completed =
          machine.feed(175, t0.add(const Duration(milliseconds: 1800)));

      expect(completed, true);
      expect(machine.repCount, 1);
    });

    test('rejects shallow squat stopping at 110° (threshold 95°)', () {
      final machine = RepStateMachine(exercise: squat);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(110, t0);
      machine.feed(110, t0.add(const Duration(milliseconds: 900)));
      machine.feed(175, t0.add(const Duration(milliseconds: 1800)));

      expect(machine.repCount, 0);
    });

    test('rejects incomplete stand-up at 160° (threshold 168°)', () {
      final machine = RepStateMachine(exercise: squat);
      final t0 = DateTime(2026, 1, 1);

      machine.feed(90, t0);
      machine.feed(90, t0.add(const Duration(milliseconds: 900)));
      machine.feed(160, t0.add(const Duration(milliseconds: 1800)));

      expect(machine.repCount, 0);
    });
  });
}
