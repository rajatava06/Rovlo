import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../services/chat_repository.dart';
import 'chat_room_screen.dart';

/// Opens the chat screen for a person (creating the conversation if needed).
void openChatWith(
  BuildContext context, {
  required String peerId,
  required String name,
  required String imageUrl,
  required bool isVerified,
}) {
  final chat = context.read<ChatProvider>();
  chat.ensureConversation(
    peerId: peerId,
    name: name,
    imageUrl: imageUrl,
    isVerified: isVerified,
  );
  chat.markAsRead(peerId);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatRoomScreen(
        args: ChatRoomArgs(
          peerId: peerId,
          name: name,
          imageUrl: imageUrl,
          isVerified: isVerified,
        ),
      ),
    ),
  );
}

/// Accepts or declines a chat request that somebody sent me, with feedback.
/// Returns true when it worked.
Future<bool> answerChatRequest(
  BuildContext context,
  ChatRequest request, {
  required bool accept,
  bool openChat = false,
}) async {
  final chat = context.read<ChatProvider>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await chat.respondToChatRequest(request, accept: accept);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(accept
          ? 'You can now chat with ${request.name}. 🎉'
          : "Declined ${request.name}'s request."),
    ));
    if (accept && openChat && context.mounted) {
      openChatWith(
        context,
        peerId: request.peerId,
        name: request.name,
        imageUrl: request.photoUrl,
        isVerified: request.isVerified,
      );
    }
    return true;
  } on ChatRequestException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not do that. Check your connection.')),
    );
  }
  return false;
}
