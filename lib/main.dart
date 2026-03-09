import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'package:tracely/app.dart';
import 'package:tracely/core/theme/app_theme.dart';
import 'package:tracely/core/providers/app_providers.dart';
import 'package:tracely/core/providers/theme_mode_provider.dart';
import 'package:tracely/screens/splash/splash_screen.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Hold the native splash (Tracely logo) until Flutter UI is ready.
  // This eliminates the blank screen before the splash appears.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Load env in the background – don't block runApp().
  // dotenv will be ready by the time any API call is actually made.
  _loadEnv();

  runApp(const TracelyApp());
}

/// Fire-and-forget env loading so the first frame renders instantly.
Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: 'assets/env.default');
  } catch (e) {
    debugPrint('⚠️ Could not load env.default: $e  (using defaults)');
  }
}

class TracelyApp extends StatefulWidget {
  const TracelyApp({super.key});

  @override
  State<TracelyApp> createState() => _TracelyAppState();
}

class _TracelyAppState extends State<TracelyApp> {
  bool _showSplash = true;

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: Consumer<ThemeModeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Tracely',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: _showSplash
                ? SplashScreen(onComplete: _onSplashComplete)
                : const AuthGate(),
          );
        },
      ),
    );
  }
}
