import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';

class ChatMessage {
  final String text;
  final String? imageUrl;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    this.imageUrl,
    required this.isMe,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

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
  final StreamController<String> _notificationStreamController =
      StreamController<String>.broadcast();

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
        contactImageUrl:
            'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
        isBot: true,
        hasUnread: true,
        messages: [
          ChatMessage(
            text:
                'Hello! I am Rovlo, your intelligent travel companion. 🌍 Ask me anything about travel trips, destinations, safety, or profile setup!',
            isMe: false,
          ),
        ],
      ),
    );

    // Seed regular travelers
    _conversations.add(
      ChatConversation(
        contactName: 'Elena Rossi',
        contactImageUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
        messages: [
          ChatMessage(
            text:
                'Hey! I saw you\'re also going to be in Shinjuku for Halloween. Want to grab ramen?',
            isMe: false,
          ),
        ],
      ),
    );

    _conversations.add(
      ChatConversation(
        contactName: 'Marcus Chen',
        contactImageUrl:
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=150&q=80',
        isVerified: false,
        messages: [
          ChatMessage(
            text:
                'Did you check out the hiking trails near Mt. Fuji? Absolutely spectacular view!',
            isMe: false,
          ),
        ],
      ),
    );

    _conversations.add(
      ChatConversation(
        contactName: 'Sora Takahashi',
        contactImageUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
        isVerified: true,
        messages: [
          ChatMessage(
            text:
                'Welcome to Tokyo! If you need any tips on local hidden cafes, let me know!',
            isMe: false,
          ),
        ],
      ),
    );
  }

  ChatConversation? getConversation(String contactName) {
    try {
      return _conversations.firstWhere((c) => c.contactName == contactName);
    } catch (_) {
      return null;
    }
  }

  void markAsRead(String contactName) {
    final conv = getConversation(contactName);
    if (conv != null && conv.hasUnread) {
      conv.hasUnread = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(
    String contactName,
    String text,
    AppUser? currentUser, {
    String? imageUrl,
  }) async {
    final conv = getConversation(contactName);
    if (conv == null) return;

    // Add user message
    conv.messages.add(
      ChatMessage(
        text: text,
        imageUrl: imageUrl,
        isMe: true,
      ),
    );
    notifyListeners();

    if (conv.isBot) {
      await _handleBotReply(conv, text, currentUser);
    } else {
      await _handleTravelerReply(conv, text);
    }
  }

  Future<void> _handleBotReply(
    ChatConversation conv,
    String userText,
    AppUser? currentUser,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final query = userText.toLowerCase();

    String reply = '';
    if (query.contains('photo') || query.contains('picture') || query.contains('image')) {
      reply = 'That looks amazing! 📸 Photos tell the best travel stories. Keep capturing those memories!';
    } else if (query.contains('hi') || query.contains('hello') || query.contains('hey')) {
      final nameStr = currentUser?.displayName ?? 'Traveler';
      reply =
          'Greetings, $nameStr! 👋 How can I assist with your journey today? Ask me about destinations, profile completion, or safety tips!';
    } else if (query.contains('profile') || query.contains('complete')) {
      final percent = currentUser != null
          ? (currentUser.profileCompletionPercent * 100).round()
          : 0;
      reply =
          '📋 Profile Completion: Your profile is currently $percent% complete.\n\nMake sure to add your DOB, travel interests, and photos for the best matches!';
    } else {
      reply =
          'Rovlo Bot here! 🤖 I\'m here to help you wander more and worry less. Need tips for packing, itinerary planning, or finding nearby travelers?';
    }

    conv.messages.add(ChatMessage(text: reply, isMe: false));
    conv.hasUnread = true;
    notifyListeners();

    _triggerNotification('Rovlo', reply);
  }

  Future<void> _handleTravelerReply(
    ChatConversation conv,
    String userText,
  ) async {
    await Future.delayed(const Duration(milliseconds: 2000));
    final replies = [
      'Awesome photo/message! Let\'s coordinate our travel itinerary soon. 😊',
      'Looks incredible! I\'m adding that spot to my checklist. Talk soon!',
      'Love it! Let\'s definitely catch up when we arrive.',
    ];
    final reply = replies[DateTime.now().second % replies.length];

    conv.messages.add(ChatMessage(text: reply, isMe: false));
    conv.hasUnread = true;
    notifyListeners();

    _triggerNotification(conv.contactName, reply);
  }

  void _triggerNotification(String sender, String message) {
    _notificationStreamController.add('$sender: $message');
  }
}
