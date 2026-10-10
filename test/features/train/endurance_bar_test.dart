import 'package:fitnessapp/features/train/widgets/endurance_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Smoke coverage for the FR-2.4 Endurance Bar: the composite percent, the
// band label, and the two input readouts the user needs to know what to fix.
Widget _host({required double romScore, required double tutRatio}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: EnduranceBar(
            romScore: romScore,
            tutRatio: tutRatio,
            visible: true,
            onTap: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the composite percent and band label', (tester) async {
    // sqrt(0.64 x 0.25) = 0.4 → Fair
    await tester.pumpWidget(_host(romScore: 0.64, tutRatio: 0.25));
    expect(find.text('40%  Fair'), findsOneWidget);
  });

  testWidgets('shows both inputs so the user knows which to fix', (
    tester,
  ) async {
    await tester.pumpWidget(_host(romScore: 0.64, tutRatio: 0.25));
    expect(find.text('ROM 64%   ·   TUT 25%'), findsOneWidget);
  });

  testWidgets('reads 0% Low before the first rep closes', (tester) async {
    await tester.pumpWidget(_host(romScore: 0.0, tutRatio: 0.0));
    expect(find.text('0%  Low'), findsOneWidget);
  });

  testWidgets('reads Strong once both inputs are high', (tester) async {
    // sqrt(0.9 x 0.8) = 0.848
    await tester.pumpWidget(_host(romScore: 0.9, tutRatio: 0.8));
    expect(find.text('85%  Strong'), findsOneWidget);
  });

  testWidgets('fill width tracks the score', (tester) async {
    await tester.pumpWidget(_host(romScore: 1.0, tutRatio: 0.25));
    await tester.pumpAndSettle();

    final box = tester.widget<AnimatedFractionallySizedBox>(
      find.byType(AnimatedFractionallySizedBox),
    );
    expect(box.widthFactor, closeTo(0.5, 1e-9)); // sqrt(1.0 x 0.25)
    expect(box.alignment, Alignment.centerLeft);
  });
}
