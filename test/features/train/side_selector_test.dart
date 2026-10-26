import 'package:fitnessapp/features/train/models/side_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SideSelector', () {
    test('defaults to left before any sample', () {
      final s = SideSelector();
      expect(s.side, BodySide.left);
      expect(s.isLocked, isFalse);
    });

    test('picks the more confident side before locking', () {
      final s = SideSelector();
      expect(s.feed(0.3, 0.9), BodySide.right);
      expect(s.isLocked, isFalse);
    });

    test('locks after lockAfterSamples frames', () {
      final s = SideSelector(lockAfterSamples: 10);
      for (var i = 0; i < 9; i++) {
        s.feed(0.4, 0.9);
      }
      expect(s.isLocked, isFalse);
      s.feed(0.4, 0.9);
      expect(s.isLocked, isTrue);
      expect(s.side, BodySide.right);
    });

    test('locked side ignores later frames favouring the other side', () {
      final s = SideSelector(lockAfterSamples: 3);
      for (var i = 0; i < 3; i++) {
        s.feed(0.9, 0.2);
      }
      for (var i = 0; i < 20; i++) {
        expect(s.feed(0.1, 0.99), BodySide.left);
      }
    });

    test('decides on the total, so one noisy frame does not flip it', () {
      final s = SideSelector(lockAfterSamples: 4);
      s.feed(0.8, 0.5);
      s.feed(0.8, 0.5);
      s.feed(0.1, 0.99); // single occlusion spike on the left
      s.feed(0.8, 0.5);
      expect(s.side, BodySide.left);
    });

    test('tie keeps left, matching the old hardcoded behaviour', () {
      final s = SideSelector(lockAfterSamples: 2);
      s.feed(0.7, 0.7);
      s.feed(0.7, 0.7);
      expect(s.side, BodySide.left);
    });

    test('reset unlocks so the next set can pick again', () {
      final s = SideSelector(lockAfterSamples: 2);
      s.feed(0.9, 0.1);
      s.feed(0.9, 0.1);
      expect(s.side, BodySide.left);

      s.reset();
      expect(s.isLocked, isFalse);
      s.feed(0.1, 0.9);
      s.feed(0.1, 0.9);
      expect(s.side, BodySide.right);
    });
  });
}
