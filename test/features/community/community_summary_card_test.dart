import 'package:fitnessapp/core/constants/app_colors.dart';
import 'package:fitnessapp/features/community/models/post.dart';
import 'package:fitnessapp/features/community/providers/community_providers.dart';
import 'package:fitnessapp/features/community/widgets/community_summary_card.dart';
import 'package:fitnessapp/features/progress/models/session_record.dart';
import 'package:fitnessapp/features/progress/providers/progress_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFeed extends FeedController {
  _FakeFeed(this.posts);
  final List<Post> posts;

  @override
  Future<FeedState> build() async => FeedState(posts: posts, hasMore: false);
}

Post _post(String id, String user, String name) => Post(
  id: id,
  userId: user,
  authorName: name,
  exerciseName: 'Single-Leg Romanian Deadlift With Pause',
  stats: const PostStats(reps: 32, sets: 3, durationMs: 108000),
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

Widget _app(List<Override> overrides, {double width = 320}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentLime,
        surface: AppColors.darkSurface,
      ),
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: const CommunitySummaryCard()),
      ),
    ),
  ),
);

void main() {
  final posts = [
    _post('1', 'a', 'Maximilian Alexander Featherstonehaugh-Smith'),
    _post('2', 'b', 'Mei'),
    _post('3', 'a', 'Maximilian Alexander Featherstonehaugh-Smith'),
    _post('4', 'c', 'Jun'),
    _post('5', 'd', 'Kai'),
  ];

  for (final width in [280.0, 360.0]) {
    testWidgets('online card fits at ${width}px', (tester) async {
      await tester.pumpWidget(
        _app([
          isOnlineUserProvider.overrideWithValue(true),
          feedProvider.overrideWith(() => _FakeFeed(posts)),
          sharedTodayProvider.overrideWith((_) async => 1234),
          sessionHistoryProvider.overrideWith(
            (_) async => [
              SessionRecord(
                date: DateTime.now(),
                exerciseName: 'Squat',
                sets: const [SetRecord(reps: 10, formScore: 0.8)],
              ),
            ],
          ),
        ], width: width),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1234 workouts'), findsOneWidget);
      expect(find.text('Share your last workout'), findsOneWidget);
      // Three distinct posters (Maximilian, Mei, Jun), not one per post:
      // Maximilian's second post adds no avatar, Kai is the 4th poster.
      expect(find.text('M'), findsNWidgets(2));
      expect(find.text('J'), findsOneWidget);
      expect(find.text('K'), findsNothing);
    });
  }

  testWidgets('no history: offers to start a workout; zero today', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        isOnlineUserProvider.overrideWithValue(true),
        feedProvider.overrideWith(() => _FakeFeed(const [])),
        sharedTodayProvider.overrideWith((_) async => 0),
        sessionHistoryProvider.overrideWith((_) async => const []),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('No workouts'), findsOneWidget);
    expect(find.text('shared today. Be the first.'), findsOneWidget);
    expect(find.text('Start a workout'), findsOneWidget);
  });

  testWidgets('offline: sign-in notice, no See all', (tester) async {
    await tester.pumpWidget(
      _app([
        isOnlineUserProvider.overrideWithValue(false),
        sessionHistoryProvider.overrideWith((_) async => const []),
      ], width: 280),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('See all'), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });
}
