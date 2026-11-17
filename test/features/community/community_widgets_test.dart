import 'dart:convert';
import 'dart:io';

import 'package:fitnessapp/core/constants/app_colors.dart';
import 'package:fitnessapp/features/community/models/post.dart';
import 'package:fitnessapp/features/community/widgets/post_card.dart';
import 'package:fitnessapp/features/community/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget tests fail on any RenderFlex overflow, so these check layouts at a
// small phone width with long text.

Widget _app(Widget child, {double width = 320}) => MaterialApp(
  theme: ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentLime,
      surface: AppColors.darkSurface,
    ),
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: child),
      ),
    ),
  ),
);

/// A valid 1×1 PNG.
const _pixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const _longName = 'Maximilian Alexander Featherstonehaugh-Smith';

void main() {
  const stats = PostStats(
    reps: 1234,
    sets: 12,
    durationMs: 3725000,
    avgFormPct: 100,
    kcal: 9999,
  );
  final data = ShareCardData(
    exerciseName: 'Single-Leg Romanian Deadlift With Pause',
    stats: stats,
    date: DateTime(2026, 11, 13),
    streakDays: 12,
  );

  testWidgets('stats card fits its 320 x 400 frame with long values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(ShareCard(data: data, template: ShareTemplate.stats)),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('12-day streak'), findsOneWidget);
    expect(tester.getSize(find.byType(ShareCard)), ShareCard.size);
  });

  testWidgets('photo card fits with a real image file', (tester) async {
    final file = File('${Directory.systemTemp.path}/fitform_test_photo.png')
      ..writeAsBytesSync(base64Decode(_pixelPng));
    await tester.pumpWidget(
      _app(ShareCard(data: data, template: ShareTemplate.photo, photo: file)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  Post post({String? caption, String? image, bool liked = false}) => Post(
    id: 'p1',
    userId: 'u1',
    authorName: _longName,
    exerciseName: 'Single-Leg Romanian Deadlift With Pause',
    stats: stats,
    createdAt: DateTime(2026, 11, 13, 9),
    caption: caption,
    imageUrl: image,
    likeCount: 1,
    likedByMe: liked,
  );

  for (final width in [280.0, 360.0]) {
    testWidgets('post card without image fits at ${width}px', (tester) async {
      await tester.pumpWidget(
        _app(
          PostCard(
            post: post(caption: 'Long caption ' * 20),
            isMine: true,
            onLike: () {},
            onDelete: () {},
            now: DateTime(2026, 11, 13, 12),
          ),
          width: width,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1 like'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });
  }

  testWidgets('someone else\'s post has no menu; like button calls back', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        PostCard(
          post: post(liked: true),
          isMine: false,
          onLike: () => taps++,
          onDelete: () {},
          now: DateTime(2026, 11, 13, 12),
        ),
      ),
    );
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    await tester.tap(find.byIcon(Icons.favorite_rounded));
    expect(taps, 1);
  });
}
