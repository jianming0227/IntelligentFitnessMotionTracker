import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/utils/app_log.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // FE failures that no try/catch sees: a widget throwing while building or
  // laying out (the red error screen), and async errors nobody awaited.
  FlutterError.onError = (details) {
    final where = details.context?.toDescription() ?? 'Flutter framework';
    AppLog.error('UI', 'Error $where', details.exception, details.stack);
  };
  widgetsBinding.platformDispatcher.onError = (error, stack) {
    AppLog.error('UI', 'Uncaught async error', error, stack);
    return true;
  };

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final user = Supabase.instance.client.auth.currentUser;
  AppLog.ok('App', 'Started (${user != null ? 'signed in' : 'signed out'})');

  FlutterNativeSplash.remove();
  runApp(const ProviderScope(child: FitnessApp()));
}

