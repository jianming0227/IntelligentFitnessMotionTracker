/// Workout numbers shown on a share card and stored on a post (`stats`).
class PostStats {
  const PostStats({
    required this.reps,
    required this.sets,
    required this.durationMs,
    this.avgFormPct,
    this.kcal,
  });

  final int reps;
  final int sets;
  final int durationMs;

  /// 0-100, null when no set was measured.
  final int? avgFormPct;
  final int? kcal;

  Map<String, dynamic> toJson() => {
    'reps': reps,
    'sets': sets,
    'durationMs': durationMs,
    'avgFormPct': ?avgFormPct,
    'kcal': ?kcal,
  };

  static PostStats fromJson(Object? raw) {
    final m = raw is Map ? raw : const {};
    int? n(String k) => (m[k] as num?)?.round();
    return PostStats(
      reps: n('reps') ?? 0,
      sets: n('sets') ?? 0,
      durationMs: n('durationMs') ?? 0,
      avgFormPct: n('avgFormPct'),
      kcal: n('kcal'),
    );
  }
}

/// One community post (a row of `posts`).
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.exerciseName,
    required this.stats,
    required this.createdAt,
    this.caption,
    this.imageUrl,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String userId;
  final String authorName;
  final String exerciseName;
  final PostStats stats;
  final DateTime createdAt;
  final String? caption;
  final String? imageUrl;
  final int likeCount;
  final bool likedByMe;

  /// A `posts` row selected with `post_likes(count)`. Null when a field the
  /// card needs is missing, so one bad row can't break the feed.
  static Post? fromJson(Map<String, dynamic> row, {bool likedByMe = false}) {
    final id = row['id'], userId = row['user_id'];
    final created = DateTime.tryParse('${row['created_at']}');
    if (id is! String || userId is! String || created == null) return null;
    final likes = row['post_likes'];
    final count = likes is List && likes.isNotEmpty && likes.first is Map
        ? ((likes.first as Map)['count'] as num?)?.toInt() ?? 0
        : 0;
    final caption = (row['caption'] as String?)?.trim();
    return Post(
      id: id,
      userId: userId,
      authorName: (row['author_name'] as String?)?.trim().isNotEmpty == true
          ? (row['author_name'] as String).trim()
          : 'FitForm user',
      exerciseName: row['exercise_name'] as String? ?? 'Workout',
      stats: PostStats.fromJson(row['stats']),
      createdAt: created.toLocal(),
      caption: caption == null || caption.isEmpty ? null : caption,
      imageUrl: row['image_url'] as String?,
      likeCount: count,
      likedByMe: likedByMe,
    );
  }

  Post withLike(bool liked) => liked == likedByMe
      ? this
      : Post(
          id: id,
          userId: userId,
          authorName: authorName,
          exerciseName: exerciseName,
          stats: stats,
          createdAt: createdAt,
          caption: caption,
          imageUrl: imageUrl,
          likeCount: (likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30),
          likedByMe: liked,
        );
}
