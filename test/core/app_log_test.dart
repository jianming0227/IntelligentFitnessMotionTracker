import 'package:fitnessapp/core/utils/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> lines;
  late void Function(String) originalSink;

  setUp(() {
    lines = [];
    originalSink = AppLog.sink;
    AppLog.sink = lines.add;
  });

  tearDown(() {
    AppLog.sink = originalSink;
    AppLog.useColor = false;
  });

  test('colour mode wraps level and layer in ANSI codes', () {
    AppLog.useColor = true;
    AppLog.error('Supabase', 'down');
    expect(
      lines.single,
      '\x1B[31mERR  \x1B[0m\x1B[36mBE\x1B[0m \x1B[31m[Supabase] down\x1B[0m',
    );
  });

  test('colour is off by default', () {
    expect(AppLog.useColor, isFalse);
  });

  test('each level writes a tagged line with its layer', () {
    AppLog.info('Gemini', 'start');
    AppLog.ok('Supabase', 'saved');
    AppLog.warn('Camera', 'slow');
    expect(lines, [
      'INFO BE [Gemini] start',
      'OK   BE [Supabase] saved',
      'WARN FE [Camera] slow',
    ]);
  });

  test('remote-service tags are BE, everything else FE', () {
    for (final tag in ['Auth', 'Supabase', 'Gemini', 'Plan', 'Profile']) {
      expect(AppLog.layerOf(tag), 'BE', reason: tag);
    }
    for (final tag in ['App', 'Nav', 'Camera', 'Gesture', 'Side', 'UI']) {
      expect(AppLog.layerOf(tag), 'FE', reason: tag);
    }
  });

  test('error appends the exception after the message', () {
    AppLog.error('Auth', 'Sign-in failed', Exception('bad creds'));
    expect(lines.single, 'ERR  BE [Auth] Sign-in failed: Exception: bad creds');
  });

  test('error without exception prints message only', () {
    AppLog.error('Auth', 'No user');
    expect(lines.single, 'ERR  BE [Auth] No user');
  });

  test('stack trace goes on its own line', () {
    AppLog.error('UI', 'boom', 'e', StackTrace.fromString('#0 main'));
    expect(lines, ['ERR  FE [UI] boom: e', '#0 main']);
  });
}
