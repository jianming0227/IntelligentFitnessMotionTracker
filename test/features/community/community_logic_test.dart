import 'package:fitnessapp/features/community/logic/community_format.dart';
import 'package:fitnessapp/features/community/models/post.dart';
import 'package:fitnessapp/features/community/providers/community_providers.dart';
import 'package:fitnessapp/features/train/models/set_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

SetMetrics _set(int n, int reps, double form, int ms) => SetMetrics(
  setNumber: n,
  repsCompleted: reps,
  formScore: form,
  fatigueIndex: 0.1,
  repDurationsMs: const [],
  completedAt: DateTime(2026, 11, 13),
  tutMs: 0,
  romScore: 0.8,
  repRomSpans: const [],
  setDurationMs: ms,
);

void main() {
  group('statsFromSets', () {
    test('sums reps and time, averages form, kcal from MET', () {
      final s = statsFromSets(
        [_set(1, 10, 0.8, 60000), _set(2, 8, 0.7, 60000)],
        met: 3.5,
        weightKg: 60,
      );
      expect(s.reps, 18);
      expect(s.sets, 2);
      expect(s.durationMs, 120000);
      expect(s.avgFormPct, 75);
      // 3.5 × 60 kg × 2/60 h = 7 kcal
      expect(s.kcal, 7);
    });

    test('no sets: zeros and no form / kcal', () {
      final s = statsFromSets(const [], met: 3.5, weightKg: 70);
      expect(s.reps, 0);
      expect(s.avgFormPct, isNull);
      expect(s.kcal, isNull);
    });
  });

  test('formatDuration', () {
    expect(formatDuration(0), '–');
    expect(formatDuration(108000), '1:48');
    expect(formatDuration(3725000), '1:02:05');
  });

  test('timeAgo', () {
    final now = DateTime(2026, 11, 13, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'now');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), '5m');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now), '3h');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now), '2d');
    expect(timeAgo(DateTime(2026, 11, 1), now), 'Nov 1');
    expect(timeAgo(DateTime(2025, 12, 30), now), 'Dec 30, 2025');
  });

  test('display name and initial', () {
    expect(validDisplayName('  Alex   Tan '), 'Alex Tan');
    expect(validDisplayName('   '), isNull);
    expect(validDisplayName('x' * 41), isNull);
    expect(initialOf('alex'), 'A');
    expect(initialOf(' '), '?');
  });

  test('community needs a signed-in, non-demo user', () {
    expect(canUseCommunity(signedIn: true, demoMode: false), isTrue);
    expect(canUseCommunity(signedIn: false, demoMode: false), isFalse);
    expect(canUseCommunity(signedIn: true, demoMode: true), isFalse);
  });

  group('Post.fromJson', () {
    Map<String, dynamic> row({Map<String, dynamic> extra = const {}}) => {
      'id': 'p1',
      'user_id': 'u1',
      'author_name': '  Alex ',
      'exercise_name': 'Squat',
      'stats': {'reps': 30, 'sets': 3, 'durationMs': 90000, 'avgFormPct': 82},
      'caption': '  ',
      'image_url': null,
      'created_at': '2026-11-13T04:00:00Z',
      'post_likes': [
        {'count': 4},
      ],
      ...extra,
    };

    test('reads a row with its like count', () {
      final p = Post.fromJson(row(), likedByMe: true)!;
      expect(p.authorName, 'Alex');
      expect(p.stats.reps, 30);
      expect(p.stats.avgFormPct, 82);
      expect(p.stats.kcal, isNull);
      expect(p.caption, isNull, reason: 'blank caption');
      expect(p.likeCount, 4);
      expect(p.likedByMe, isTrue);
    });

    test('bad rows are skipped, odd fields fall back', () {
      expect(Post.fromJson(row(extra: {'id': null})), isNull);
      expect(Post.fromJson(row(extra: {'created_at': 'soon'})), isNull);
      final p = Post.fromJson(
        row(extra: {'author_name': '', 'stats': 'x', 'post_likes': null}),
      )!;
      expect(p.authorName, 'FitForm user');
      expect(p.stats.reps, 0);
      expect(p.likeCount, 0);
    });

    test('withLike updates count once per change', () {
      final p = Post.fromJson(row())!;
      final liked = p.withLike(true);
      expect(liked.likeCount, 5);
      expect(liked.withLike(true).likeCount, 5);
      expect(liked.withLike(false).likeCount, 4);
    });

    test('stats round-trip', () {
      const s = PostStats(reps: 9, sets: 1, durationMs: 1000, kcal: 2);
      final back = PostStats.fromJson(s.toJson());
      expect(back.reps, 9);
      expect(back.kcal, 2);
      expect(back.avgFormPct, isNull);
      expect(s.toJson().containsKey('avgFormPct'), isFalse);
    });
  });
}
