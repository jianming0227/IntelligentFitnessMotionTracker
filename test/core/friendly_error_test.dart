import 'package:fitnessapp/core/utils/friendly_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const offline = 'No internet connection. Check your network and try again.';

  test('DNS failure from Supabase auth reads as offline', () {
    final e = AuthRetryableFetchException(
      message: "ClientException with SocketException: Failed host lookup: "
          "'x.supabase.co' (OS Error: No address associated with hostname)",
    );
    expect(friendlyError(e), offline);
  });

  test('raw socket error text reads as offline', () {
    expect(friendlyError(Exception('SocketException: refused')), offline);
  });

  test('short Supabase API message is shown as is', () {
    expect(
      friendlyError(AuthApiException('Invalid login credentials')),
      'Invalid login credentials',
    );
  });

  test('anything else gets a generic line', () {
    expect(
      friendlyError(StateError('null check deep in a parser')),
      'Something went wrong. Please try again.',
    );
  });
}
