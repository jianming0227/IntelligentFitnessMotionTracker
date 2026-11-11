import 'package:flutter/material.dart';

import '../models/exercise.dart';

/// The exercise's photo (`image_url` column): an asset path or a public URL.
/// Null when the exercise has no photo.
///
/// Per-view framing (alignment, zoom) is chosen by each screen, except the
/// Home card crop which comes from the row's `image_framing`.
String? exerciseImageFor(String exerciseId) =>
    Exercise.byId(exerciseId)?.imageUrl;

bool isRemoteImage(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// Shows [path] from the app bundle or the network, whichever it is.
Widget exerciseImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  required WidgetBuilder fallback,
}) {
  Widget onError(BuildContext context, Object _, StackTrace? _) =>
      fallback(context);
  return isRemoteImage(path)
      ? Image.network(
          path,
          fit: fit,
          alignment: alignment,
          errorBuilder: onError,
        )
      : Image.asset(
          path,
          fit: fit,
          alignment: alignment,
          errorBuilder: onError,
        );
}
