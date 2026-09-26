import 'package:flutter/foundation.dart';

/// A place shared in a chat, shown on the in-app map.
class MapFocusTarget {
  const MapFocusTarget({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;

  /// e.g. "Asha's shared location".
  final String label;
}

/// Lets code outside the widget tree (push-notification taps, the chat's
/// "shared location" bubble) ask the home screen to switch tabs.
class AppNavigation {
  AppNavigation._();

  /// Set when a chat notification was tapped; Home opens the Chats tab and
  /// resets it. Stays set until Home exists (cold start from a notification).
  static final ValueNotifier<bool> openChatsRequested = ValueNotifier<bool>(false);

  static void openChats() => openChatsRequested.value = true;

  /// A location to show on the Maps tab. Home switches to Maps; the map centres
  /// on it, drops a pin and keeps it until the user closes it (sets it to null).
  static final ValueNotifier<MapFocusTarget?> mapFocus = ValueNotifier<MapFocusTarget?>(null);

  static void showOnMap(MapFocusTarget target) => mapFocus.value = target;
}
