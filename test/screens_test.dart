import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rovlo/core/theme/app_theme.dart';
import 'package:rovlo/core/theme/theme_provider.dart';
import 'package:rovlo/features/profile/rovlo_plus_screen.dart';
import 'package:rovlo/features/profile/verify_screen.dart';
import 'package:rovlo/features/settings/settings_screen.dart';
import 'package:rovlo/providers/auth_provider.dart';

Widget _app(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Rovlo Plus: Free active, Plus + Advanced blurred "coming soon"',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const RovloPlusScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.textContaining('₹0', findRichText: true), findsOneWidget);
    expect(find.textContaining('₹199', findRichText: true), findsOneWidget);
    expect(find.textContaining('₹499', findRichText: true), findsOneWidget);
    expect(find.text('COMING SOON'), findsNWidgets(2));
    expect(find.text('Current Plan'), findsOneWidget); // Free
  });

  testWidgets('Verify starts on step 1 (selfie) and Next is locked until a photo',
      (tester) async {
    await tester.pumpWidget(_app(const VerifyScreen()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    expect(find.text('Take a straight selfie'), findsOneWidget);
    expect(find.text('Pose'), findsOneWidget); // step label
    expect(find.textContaining('Aadhaar'), findsNothing); // no ID needed
    final next = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next: pose photo'));
    expect(next.onPressed, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Cookie policy title no longer overflows', (tester) async {
    tester.view.physicalSize = const Size(720, 1500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const SettingsScreen()));
    await tester.tap(find.text('Cookie Policy'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cookie & Local Storage Policy'), findsOneWidget);
    expect(tester.takeException(), isNull); // "RIGHT OVERFLOWED" would land here
  });
}
