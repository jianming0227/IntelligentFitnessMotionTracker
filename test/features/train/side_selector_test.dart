import 'package:fitnessapp/features/train/models/side_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SideSelector', () {
    test('defaults to left before any sample', () {
      final s = SideSelector();
      expect(s.side, BodySide.left);
      expect(s.isLocked, isFalse);
    });

    test('right-arm curl locks RIGHT while the left arm rests', () {
      final s = SideSelector(lockRangeDeg: 40);
      // Left arm hangs at ~170°, right elbow curls from 170° down to 60°.
      for (var a = 170.0; a >= 60; a -= 10) {
        s.feed(170 + (a % 3), a);
      }
      expect(s.isLocked, isTrue);
      expect(s.side, BodySide.right);
    });

    test('left-arm curl locks LEFT', () {
      final s = SideSelector(lockRangeDeg: 40);
      for (var a = 170.0; a >= 60; a -= 10) {
        s.feed(a, 168);
      }
      expect(s.side, BodySide.left);
      expect(s.isLocked, isTrue);
    });

    test('squat facing the camera locks once both knees bend', () {
      final s = SideSelector(lockRangeDeg: 40);
      for (var a = 175.0; a >= 90; a -= 5) {
        s.feed(a, a + 2);
      }
      expect(s.isLocked, isTrue);
    });

    test('standing still with jitter does not lock', () {
      final s = SideSelector(lockRangeDeg: 40);
      for (var i = 0; i < 100; i++) {
        s.feed(170 + (i % 5), 168 + (i % 7));
      }
      expect(s.isLocked, isFalse);
    });

    test('before locking, follows the side that has moved more', () {
      final s = SideSelector(lockRangeDeg: 40);
      s.feed(170, 170);
      expect(s.feed(169, 150), BodySide.right);
      expect(s.isLocked, isFalse);
    });

    test('low-confidence frames (null) are skipped for that side', () {
      final s = SideSelector(lockRangeDeg: 40);
      s.feed(170, null);
      s.feed(null, 170);
      s.feed(null, 120);
      expect(s.leftRange, 0);
      expect(s.rightRange, 50);
      expect(s.side, BodySide.right);
    });

    test('locked side ignores later movement on the other side', () {
      final s = SideSelector(lockRangeDeg: 40);
      s.feed(170, 170);
      s.feed(120, 170);
      expect(s.side, BodySide.left);
      for (var i = 0; i < 20; i++) {
        expect(s.feed(170, 60.0 + i), BodySide.left);
      }
    });

    test('reset unlocks so the next set can pick again', () {
      final s = SideSelector(lockRangeDeg: 40);
      s.feed(170, 170);
      s.feed(120, 170);
      expect(s.side, BodySide.left);

      s.reset();
      expect(s.isLocked, isFalse);
      expect(s.leftRange, 0);
      s.feed(170, 170);
      s.feed(170, 120);
      expect(s.side, BodySide.right);
    });
  });
}
