import 'package:supabase_flutter/supabase_flutter.dart';

/// Short, user-facing text for an error. The full exception and stack trace
/// belong in the log (AppLog), never on screen.
String friendlyError(Object error) {
  if (isNetworkError(error)) {
    return 'No internet connection. Check your network and try again.';
  }
  // Supabase API errors carry short, readable messages such as
  // "Invalid login credentials" or "User already registered".
  if (error is AuthException && error.message.length <= 80) {
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

bool isNetworkError(Object error) {
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('TimeoutException');
}
