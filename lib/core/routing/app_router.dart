import 'package:flutter/material.dart';

import '../../features/admin/admin_panel_screen.dart';
import '../../features/auth/dob_screen.dart';
import '../../features/auth/gender_screen.dart';
import '../../features/auth/name_screen.dart';
import '../../features/auth/phone_number_screen.dart';
import '../../features/auth/social_auth_screen.dart';
import '../../features/auth/travel_preferences_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/welcome/welcome_screen.dart';

/// Named routes + a shared page transition used across the app.
class Routes {
  Routes._();

  static const String welcome = '/';
  static const String phone = '/create/phone';
  static const String socialAuth = '/auth/social';
  static const String name = '/create/name';
  static const String gender = '/create/gender';
  static const String dob = '/create/dob';
  static const String travel = '/create/travel';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String admin = '/admin';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = _builderFor(settings);
    return _FadeThroughRoute(builder: builder, settings: settings);
  }

  static WidgetBuilder _builderFor(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return (_) => const WelcomeScreen();
      case phone:
        return (_) => const PhoneNumberScreen();
      case socialAuth:
        final args = settings.arguments as SocialAuthArgs?;
        return (_) => SocialAuthScreen(
              args: args ?? const SocialAuthArgs(isSignIn: true),
            );
      case name:
        return (_) => const NameScreen();
      case gender:
        return (_) => const GenderScreen();
      case dob:
        return (_) => const DobScreen();
      case travel:
        return (_) => const TravelPreferencesScreen();
      case home:
        return (_) => const HomeScreen();
      case Routes.settings:
        return (_) => const SettingsScreen();
      case admin:
        return (_) => const AdminPanelScreen();
      default:
        return (_) => const WelcomeScreen();
    }
  }
}

/// A smooth fade-through + subtle scale transition for a cohesive feel.
class _FadeThroughRoute<T> extends PageRouteBuilder<T> {
  _FadeThroughRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
