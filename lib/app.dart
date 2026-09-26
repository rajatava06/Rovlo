import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/keyboard_inset.dart';
import 'core/widgets/rovlo_logo.dart';
import 'providers/auth_provider.dart';

/// Root widget: theme, routing, full-screen system bars and keyboard handling.
///
/// While the saved session is being restored the app shows a cream splash;
/// once it is known the app opens on Home (signed in) or Welcome (signed out).
class RovloApp extends StatelessWidget {
  const RovloApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final status = context.select<AuthProvider, AuthStatus>((a) => a.status);

    final bool resolving = status == AuthStatus.unknown;
    final String initialRoute =
        status == AuthStatus.signedIn ? Routes.home : Routes.welcome;

    return MaterialApp(
      // New key once the session is known so `initialRoute` is applied.
      key: ValueKey<bool>(resolving),
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      home: resolving ? const _Splash() : null,
      initialRoute: resolving ? null : initialRoute,
      onGenerateRoute: resolving ? null : Routes.onGenerateRoute,
      // By default Flutter expands "/home" into ["/", "/home"], which puts the
      // Welcome / sign-in screen *underneath* Home — pressing Back on Home then
      // landed on the sign-in page. Start with exactly one route instead.
      onGenerateInitialRoutes: resolving
          ? null
          : (String name) => [Routes.onGenerateRoute(RouteSettings(name: name))],
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: KeyboardInsetScope(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: const Center(child: RovloLogo(fontSize: 44)),
    );
  }
}
