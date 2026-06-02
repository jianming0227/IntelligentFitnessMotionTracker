/// Per-exercise hero photo paths, shared by every screen that needs the
/// exercise's image (home carousel, courses list, exercise detail).
///
/// Per-view framing (alignment, zoom) is intentionally NOT stored here —
/// each surface tunes its own crop because the same photo needs to be
/// composed differently in a large hero vs. a small list thumbnail.
const Map<String, String> exerciseImagePaths = {
  'squat': 'assets/images/squat.png',
  'bicep_curl': 'assets/images/bicep.png',
};

String? exerciseImageFor(String exerciseId) => exerciseImagePaths[exerciseId];
