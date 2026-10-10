import 'package:fitnessapp/features/train/models/set_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

// FR-2.4: the Endurance Bar reads its fill from SetMetrics.endurance, and the
// live HUD calls the same static. These tests pin the maths so the live bar and
// the stored set metrics can never disagree.
SetMetrics _metrics({
  double romScore = 0,
  int tutMs = 0,
  int setDurationMs = 0,
}) {
  return SetMetrics(
    setNumber: 1,
    repsCompleted: 10,
    formScore: 0.8,
    fatigueIndex: 0.1,
    repDurationsMs: const [900, 950],
    completedAt: DateTime(2026, 1, 1),
    tutMs: tutMs,
    romScore: romScore,
    setDurationMs: setDurationMs,
  );
}

void main() {
  group('SetMetrics.tutRatio', () {
    test('is 0 when the set duration is unknown', () {
      expect(_metrics(tutMs: 4000, setDurationMs: 0).tutRatio, 0.0);
    });

    test('is the fraction of set time spent inside the target zone', () {
      expect(
        _metrics(tutMs: 6000, setDurationMs: 20000).tutRatio,
        closeTo(0.3, 1e-9), 
      );
    });

    test('clamps to 1.0 when TUT overruns the measured set duration', () {
      // Frame timestamps accumulate independently of the 1-second set ticker,
      // so rounding can push TUT a little past elapsed time.
      expect(_metrics(tutMs: 21000, setDurationMs: 20000).tutRatio, 1.0);
    });
  });

  group('SetMetrics.endurance', () {
    test('is the geometric mean of ROM and TUT ratio', () {
      // Geometric mean, not the product: two 0.7 inputs stay readable at 0.7
      // instead of collapsing to 0.49.
      expect(SetMetrics.endurance(0.7, 0.7), closeTo(0.7, 1e-9));
      expect(SetMetrics.endurance(1.0, 0.25), closeTo(0.5, 1e-9));
    });

    test('is 0 when either input is 0', () {
      expect(SetMetrics.endurance(0.0, 0.9), 0.0);
      expect(SetMetrics.endurance(0.9, 0.0), 0.0);
    });

    test('clamps out-of-range inputs rather than returning NaN', () {
      expect(SetMetrics.endurance(1.5, 1.5), 1.0);
      expect(SetMetrics.endurance(-0.2, 0.5), 0.0);
    });

    test('enduranceScore combines the instance ROM and TUT ratio', () {
      final m = _metrics(romScore: 0.64, tutMs: 10000, setDurationMs: 40000);
      // sqrt(0.64 x 0.25) = 0.4
      expect(m.enduranceScore, closeTo(0.4, 1e-9));
      expect(m.endurancePercent, '40%');
    });
  });

  group('SetMetrics.enduranceLabel', () {
    test('Low under 0.4', () {
      final m = _metrics(romScore: 0.1, tutMs: 1000, setDurationMs: 40000);
      expect(m.enduranceLabel, 'Low');
    });

    test('Fair from 0.4 to under 0.7', () {
      final m = _metrics(romScore: 0.5, tutMs: 10000, setDurationMs: 20000);
      expect(m.enduranceScore, closeTo(0.5, 1e-9));
      expect(m.enduranceLabel, 'Fair');
    });

    test('Strong at 0.7 and above', () {
      final m = _metrics(romScore: 0.9, tutMs: 16000, setDurationMs: 20000);
      expect(m.enduranceLabel, 'Strong');
    });
  });

  test('romPercent rounds to a whole percent', () {
    expect(_metrics(romScore: 0.826).romPercent, '83%');
  });

  test('toHistorySummary carries ROM so Gemini can see rep depth', () {
    final m = _metrics(romScore: 0.82, tutMs: 8000, setDurationMs: 20000);
    expect(m.toHistorySummary(), contains('ROM 82%'));
  });
}
