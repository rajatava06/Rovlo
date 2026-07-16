import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rovlo/app.dart';
import 'package:rovlo/core/theme/theme_provider.dart';
import 'package:rovlo/core/widgets/rovlo_logo.dart';
import 'package:rovlo/providers/auth_provider.dart';

void main() {
  setUp(() {
    // In-memory prefs so the app can start without a platform channel.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Welcome screen shows the Rovlo wordmark and CTAs',
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

    // Let async providers + intro animations settle.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RovloLogo), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
