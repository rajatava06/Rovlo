import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/rovlo_loader.dart';
import 'features/home/home_screen.dart';
import 'features/welcome/welcome_screen.dart';
import 'providers/auth_provider.dart';

/// Root widget: wires up the theme (reacting to [ThemeProvider]) and routing.
class RovloApp extends StatelessWidget {
  const RovloApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      home: const _SplashGate(),
      onGenerateRoute: Routes.onGenerateRoute,
    );
  }
}

/// Shows the branded [RovloLoadingScreen] while the saved session restores,
/// then fades into Home (signed in) or Welcome (signed out). A short minimum
/// display time keeps the splash from flashing on fast devices.
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800)).then((_) {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    final ready = _minTimeElapsed && status != AuthStatus.unknown;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !ready
          ? const RovloLoadingScreen()
          : status == AuthStatus.signedIn
              ? const HomeScreen()
              : const WelcomeScreen(),
    );
  }
}
