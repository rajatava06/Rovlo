import 'package:flutter/material.dart';

/// Keyboard handling for the whole app.
///
/// The problem with Flutter's default: when the on-screen keyboard opens, every
/// `Scaffold` shrinks by the keyboard height, so columns, headers and
/// backgrounds get squeezed / pushed up and the field you tap can end up with
/// no room for its placeholder.
///
/// Rovlo's approach:
///  1. [KeyboardInsetScope] (installed once, in `MaterialApp.builder`) hides the
///     keyboard from `MediaQuery.viewInsets`, so **no screen re-lays itself out**.
///     The keyboard simply slides over the UI.
///  2. The real keyboard height stays available through [KeyboardInset.of].
///  3. Only the places that must stay usable while typing opt in:
///     [KeyboardAvoiding] shrinks *just a scrollable region* so the focused
///     field scrolls into view above the keyboard; chat input bars and bottom
///     sheets add [KeyboardInset.of] as bottom padding.
///  4. Tapping anywhere outside a text field dismisses the keyboard.
class KeyboardInsetScope extends StatelessWidget {
  const KeyboardInsetScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return _KeyboardInsetData(
      inset: mq.viewInsets.bottom,
      child: MediaQuery(
        data: mq.copyWith(
          viewInsets: mq.viewInsets.copyWith(bottom: 0),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
      ),
    );
  }
}

class _KeyboardInsetData extends InheritedWidget {
  const _KeyboardInsetData({required this.inset, required super.child});

  final double inset;

  @override
  bool updateShouldNotify(_KeyboardInsetData old) => old.inset != inset;
}

class KeyboardInset {
  KeyboardInset._();

  /// Current on-screen keyboard height in logical pixels (0 when hidden).
  static double of(BuildContext context) {
    final data = context.dependOnInheritedWidgetOfExactType<_KeyboardInsetData>();
    return data?.inset ?? MediaQuery.viewInsetsOf(context).bottom;
  }
}

extension KeyboardInsetX on BuildContext {
  double get keyboardInset => KeyboardInset.of(this);
}

/// Shrinks its child from the bottom by the keyboard height. Wrap a scrollable
/// region with it so the focused field scrolls into the visible area, while the
/// rest of the screen (app bar, headers, nav bar) stays exactly where it is.
///
/// [reserved] is the height of anything that sits *below* this widget on
/// screen (e.g. a bottom button) — that part is already "under" the keyboard.
class KeyboardAvoiding extends StatelessWidget {
  const KeyboardAvoiding({super.key, required this.child, this.reserved = 0});

  final Widget child;
  final double reserved;

  @override
  Widget build(BuildContext context) {
    final inset = (context.keyboardInset - reserved).clamp(0.0, double.infinity);
    return Padding(padding: EdgeInsets.only(bottom: inset), child: child);
  }
}
