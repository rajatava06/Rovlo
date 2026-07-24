import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isMe,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get timeFormatted {
    final hr = timestamp.hour;
    final min = timestamp.minute.toString().padLeft(2, '0');
    final period = hr >= 12 ? 'PM' : 'AM';
    final displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr);
    return '$displayHr:$min $period';
  }
}

class ChatConversation {
  final String contactName;
  final String contactImageUrl;
  final bool isVerified;
  final List<ChatMessage> messages;
  bool hasUnread;
  final bool isBot;

  ChatConversation({
    required this.contactName,
    required this.contactImageUrl,
    required this.isVerified,
    required this.messages,
    this.hasUnread = false,
    this.isBot = false,
  });

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

class ChatProvider extends ChangeNotifier {
  final List<ChatConversation> _conversations = [];
  final StreamController<String> _notificationStreamController = StreamController<String>.broadcast();

  List<ChatConversation> get conversations => _conversations;
  Stream<String> get notificationStream => _notificationStreamController.stream;

  bool get hasUnreadMessages {
    return _conversations.any((c) => c.hasUnread);
  }

  ChatProvider() {
    _seedChats();
  }

  @override
  void dispose() {
    _notificationStreamController.close();
    super.dispose();
  }

  void _seedChats() {
    // Seed Bot (Rovlo)
    _conversations.add(
      ChatConversation(
        contactName: 'Rovlo',
        contactImageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
        isBot: true,
        hasUnread: true,
        messages: [
          ChatMessage(
            text: 'Hello! I am Rovlo, your intelligent travel assistant bot. 🌍 I am here to help you get the most out of your journeys! How can I assist you today?',
            isMe: false,
          ),
        ],
      ),
    );

    // Seed regular travelers
    _conversations.add(
      ChatConversation(
        contactName: 'Elena Rossi',
        contactImageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
        messages: [
          ChatMessage(
            text: 'Hey! I saw you\'re also going to be in Shinjuku for Halloween. Want to grab ramen?',
            isMe: false,
          ),
        ],
      ),
    );

    _conversations.add(
      ChatConversation(
        contactName: 'Marcus Chen',
        contactImageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=150&q=80',
        isVerified: false,
        messages: [
          ChatMessage(
            text: 'That café in Omotesando looks fantastic. Let\'s check it out tomorrow!',
            isMe: false,
          ),
        ],
      ),
    );
  }

  ChatConversation? getConversation(String name) {
    try {
      return _conversations.firstWhere((c) => c.contactName == name);
    } catch (_) {
      return null;
    }
  }

  void markAsRead(String name) {
    final conv = getConversation(name);
    if (conv != null && conv.hasUnread) {
      conv.hasUnread = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String contactName, String text, AppUser? currentUser) async {
    final conv = getConversation(contactName);
    if (conv == null) return;

    // Add user message
    conv.messages.add(ChatMessage(text: text, isMe: true));
    notifyListeners();

    if (conv.isBot) {
      // Bot response logic
      await _handleBotReply(conv, text, currentUser);
    } else {
      // Normal traveler reply simulation
      await _handleTravelerReply(conv, text);
    }
  }

  Future<void> _handleBotReply(ChatConversation conv, String userText, AppUser? currentUser) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final query = userText.toLowerCase();

    String reply = '';
    if (query.contains('hi') || query.contains('hello') || query.contains('hey')) {
      final nameStr = currentUser?.displayName ?? 'Traveler';
      reply = 'Greetings, $nameStr! 👋 I\'m your assistant. How can I guide you? You can ask me to "check profile", "setup notification", "explain maps", or "check plus plans".';
    } else if (query.contains('profile') || query.contains('complete')) {
      final percent = currentUser != null ? (currentUser.profileCompletionPercent * 100).round() : 0;
      reply = '📋 Profile Completion: Your profile is currently $percent% complete.\n\n';
      if (percent < 100) {
        reply += 'To reach 100%, please ensure you:\n';
        if (currentUser?.dob == null) reply += '- Add your Date of Birth (DOB)\n';
        if (currentUser?.homeBase == null) reply += '- Add your Home Base\n';
        if (currentUser?.bio == null) reply += '- Write a bio\n';
        if (currentUser?.effectivePhotos.isEmpty ?? true) reply += '- Upload a profile photo\n';
        if (currentUser?.isVerified == false) reply += '- Get verified (Blue Tick)\n';
        if (currentUser?.emergencyContacts.isEmpty ?? true) reply += '- Add Emergency Contacts\n';
      } else {
        reply += 'Outstanding! Your profile is fully complete and ready to roll!';
      }
    } else if (query.contains('notif') || query.contains('allow')) {
      reply = '🔔 Notifications: To receive instant updates when a traveler likes or chats with you, please ensure Notifications are allowed on your device.\n\nType "enable notifications" to trigger a simulated permission request!';
    } else if (query.contains('enable notifications') || query.contains('setup notification')) {
      reply = '🔔 Notification simulation triggered! You will now receive instant push updates for new chats and matches.';
      // Trigger a direct test notification
      _triggerNotification('Rovlo', 'System: Push Notifications enabled successfully! 🎉');
    } else if (query.contains('map') || query.contains('ghost') || query.contains('location') || query.contains('coordinate')) {
      reply = '🗺️ Maps & Location Mode:\n'
          '- GPS Sharing: Allows you to find nearby travelers and helps them find you in real-time using Geolocator.\n'
          '- Ghost Mode: Hides your location entirely from the maps feed. You can still browse others while remaining completely hidden!';
    } else if (query.contains('plan') || query.contains('plus') || query.contains('premium') || query.contains('pricing')) {
      reply = '⭐ Rovlo Plus Subscription plans:\n'
          '1. Free Tier: ₹0/month (Limited swipe capacity, basic map browsing).\n'
          '2. Plus Tier: ₹199/month (Unlimited likes, passport control, hide ads).\n'
          '3. Premium Tier: ₹499/month (Priority matches, premium filters, 5 free Super Likes per week).\n\nGo to Profile -> Rovlo Plus to subscribe now!';
    } else {
      reply = 'Rovlo Bot here! 🤖 I\'m not sure about that. Try asking about "profile completion", "notifications", "maps location", "ghost mode", or "plus plans".';
    }

    conv.messages.add(ChatMessage(text: reply, isMe: false));
    conv.hasUnread = true;
    notifyListeners();

    _triggerNotification('Rovlo', reply);
  }

  Future<void> _handleTravelerReply(ChatConversation conv, String userText) async {
    await Future.delayed(const Duration(milliseconds: 2500));
    final replies = [
      'That sounds awesome! Let\'s synchronize our plans soon. 😊',
      'I\'ll check the location and let you know! Talk to you in a bit.',
      'Perfect! Let\'s catch up once we both arrive.',
      'Hahaha yes! I totally agree.',
    ];
    final reply = replies[DateTime.now().millisecond % replies.length];

    conv.messages.add(ChatMessage(text: reply, isMe: false));
    conv.hasUnread = true;
    notifyListeners();

    _triggerNotification(conv.contactName, reply);
  }

  void _triggerNotification(String sender, String snippet) {
    final alertText = '$sender: ${snippet.length > 50 ? "${snippet.substring(0, 50)}..." : snippet}';
    _notificationStreamController.add(alertText);
  }
}
