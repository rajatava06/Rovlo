import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rovlo/app.dart';
import 'package:rovlo/core/theme/theme_provider.dart';
import 'package:rovlo/core/widgets/rovlo_loader.dart';
import 'package:rovlo/core/widgets/rovlo_logo.dart';
import 'package:rovlo/providers/auth_provider.dart';

void main() {
  setUp(() {
    // In-memory prefs so the app can start without a platform channel.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash shows the branded loader, then Welcome CTAs appear',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const RovloApp(),
      ),
    );

    // Branded loading screen is up first.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RovloLoadingScreen), findsOneWidget);

    // After the minimum splash time + fade, Welcome takes over.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(RovloLogo), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
