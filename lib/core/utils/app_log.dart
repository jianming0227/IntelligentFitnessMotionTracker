import 'package:flutter/foundation.dart';

/// Tagged console logging. Read it in the `flutter run` terminal (or via
/// `.\run.ps1`, which hides Android system noise and colours these lines).
///
/// Every line carries a layer so a failure is easy to place:
///   BE = backend call (Supabase, Gemini) — network / server side
///   FE = on-device (screens, camera, gestures, uncaught UI errors)
///
/// Line format:  `ERR  BE [Supabase] Session save failed: ...`
/// Never log passwords, tokens or API keys.
class AppLog {
  AppLog._();

  /// Tags whose work happens on a remote service. Any other tag is FE.
  static const backendTags = {'Auth', 'Supabase', 'Gemini', 'Plan', 'Profile'};

  /// Where lines go. Swapped out in tests to capture output.
  @visibleForTesting
  static void Function(String line) sink = _defaultSink;

  /// ANSI colours for the VS Code Debug Console. Off by default so plain
  /// terminals and run.ps1 (which colours lines itself) get clean text.
  /// Turned on by `--dart-define=LOG_COLOR=true` in .vscode/launch.json.
  static bool useColor = const bool.fromEnvironment('LOG_COLOR');

  static const _reset = '\x1B[0m';
  static const _levelColor = {
    'ERR ': '\x1B[31m', // red
    'WARN': '\x1B[33m', // yellow
    'OK  ': '\x1B[32m', // green
    'INFO': '\x1B[90m', // grey
  };
  static const _layerColor = {
    'BE': '\x1B[36m', // cyan
    'FE': '\x1B[35m', // magenta
  };

  static void _defaultSink(String line) => debugPrint(line);

  static void info(String tag, String msg) => _write('INFO', tag, msg);
  static void ok(String tag, String msg) => _write('OK  ', tag, msg);
  static void warn(String tag, String msg) => _write('WARN', tag, msg);

  static void error(String tag, String msg, [Object? e, StackTrace? st]) {
    _write('ERR ', tag, e == null ? msg : '$msg: $e');
    if (st != null) sink(st.toString());
  }

  static String layerOf(String tag) => backendTags.contains(tag) ? 'BE' : 'FE';

  static void _write(String level, String tag, String msg) {
    final layer = layerOf(tag);
    if (!useColor) {
      sink('$level $layer [$tag] $msg');
      return;
    }
    // Level colours the whole line; the layer gets its own colour so BE and
    // FE stand apart even inside a run of same-level lines.
    final c = _levelColor[level]!;
    sink('$c$level $_reset${_layerColor[layer]}$layer$_reset $c[$tag] $msg$_reset');
  }
}
