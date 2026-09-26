import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rovlo/core/theme/app_theme.dart';
import 'package:rovlo/core/widgets/keyboard_inset.dart';
import 'package:rovlo/features/home/chat_room_screen.dart';
import 'package:rovlo/features/settings/help_support_screen.dart';
import 'package:rovlo/providers/auth_provider.dart';
import 'package:rovlo/providers/chat_provider.dart';

Widget _app(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => KeyboardInsetScope(child: child!),
        home: home,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Help & support screen shows its options', (tester) async {
    await tester.pumpWidget(_app(const HelpSupportScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Chat with Rovlo Support'), findsOneWidget);
    expect(find.text('Email us'), findsOneWidget);
  });

  testWidgets('Support chat opens and shows the greeting', (tester) async {
    await tester.pumpWidget(_app(const ChatRoomScreen(
      args: ChatRoomArgs(
        peerId: kSupportId,
        name: 'Rovlo Support',
        imageUrl: '',
        isVerified: true,
      ),
    )));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('How can we help'), findsOneWidget);
    expect(find.text('Support team'), findsOneWidget);
  });

  testWidgets('Help & support does not overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(640, 1400); // 320 dp wide
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const HelpSupportScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull); // "RIGHT OVERFLOWED BY 2.2 PIXELS" lands here
    expect(find.text('Copy address'), findsOneWidget);
  });

  testWidgets('chat message bar stays a single line on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(720, 1400); // 360 dp
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const ChatRoomScreen(
      args: ChatRoomArgs(peerId: 'x', name: 'Asha', imageUrl: '', isVerified: false),
    )));
    await tester.pump(const Duration(milliseconds: 500));

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    // One line = ~41 px (text + padding); the wrapped two-line box was ~60.
    final h = tester.getSize(field).height;
    expect(h, lessThan(50), reason: 'field height was $h (two lines would be ~60)');
  });
}
