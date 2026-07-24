import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'providers/auth_provider.dart';

/// Root widget: wires up the theme (reacting to [ThemeProvider]) and routing.
///
/// If the user is already signed in (Firebase persisted session), the app
/// skips the WelcomeScreen and lands directly on HomeScreen.
class RovloApp extends StatelessWidget {
  const RovloApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Determine initial route based on auth status
    final String initialRoute;
    switch (authProvider.status) {
      case AuthStatus.signedIn:
        initialRoute = Routes.home;
        break;
      case AuthStatus.signedOut:
        initialRoute = Routes.welcome;
        break;
      case AuthStatus.unknown:
        // Still loading — show welcome for now (will redirect once resolved)
        initialRoute = Routes.welcome;
        break;
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      initialRoute: initialRoute,
      onGenerateRoute: Routes.onGenerateRoute,
    );
  }
}
