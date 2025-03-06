import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart' as app_message;
import '../services/chat_service.dart';
import '../services/auth_service.dart';

class GroupChatWidget extends StatefulWidget {
  final String groupId;
  final String groupName;
  final Function() onClose;

  const GroupChatWidget({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.onClose,
  }) : super(key: key);

  @override
  State<GroupChatWidget> createState() => _GroupChatWidgetState();
}

class _GroupChatWidgetState extends State<GroupChatWidget> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  final List<types.Message> _messages = [];
  late final types.User _currentUser;

  @override
  void initState() {
    super.initState();
    _setupCurrentUser();
  }

  void _setupCurrentUser() {
    final user = _authService.currentUser;
    if (user != null) {
      final displayName = user.displayName ?? '';
      final nameParts = displayName.split(' ');

      _currentUser = types.User(
        id: user.uid,
        firstName: nameParts.isNotEmpty ? nameParts.first : 'User',
        lastName: nameParts.length > 1 ? nameParts.last : null,
        imageUrl: user.photoURL,
      );
    } else {
      // Fallback to anonymous user
      _currentUser = const types.User(
        id: 'anonymous',
        firstName: 'Anonymous',
      );
    }
  }

  // Convert app Message to chat_types Message
  types.Message _convertMessage(app_message.Message message) {
    final author = types.User(
      id: message.senderId,
      // Store the full sender name in firstName to display it properly
      firstName: message.senderName,
    );

    return types.TextMessage(
      author: author,
      createdAt: message.timestamp.millisecondsSinceEpoch,
      id: message.id,
      text: message.content,
      // Add metadata to track message grouping
      metadata: {
        'showName': true, // Default to always show name
      },
    );
  }

  void _handleSendPressed(types.PartialText message) {
    _chatService.sendMessage(
      widget.groupId,
      _authService.currentUser?.uid ?? 'unknown',
      _authService.currentUser?.displayName ?? 'Anonymous',
      message.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Custom header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.groupName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Chat UI
            Expanded(
              child: StreamBuilder<List<app_message.Message>>(
                stream: _chatService.getMessages(widget.groupId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading messages',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!;
                  final chatMessages = messages.map(_convertMessage).toList();

                  if (messages.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return Chat(
                    messages: chatMessages,
                    onSendPressed: _handleSendPressed,
                    user: _currentUser,
                    showUserNames: true, // Enable showing user names
                    showUserAvatars: true, // Show avatars for better visual distinction
                    theme: DefaultChatTheme(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      primaryColor: Theme.of(context).colorScheme.primary,
                      secondaryColor: Theme.of(context).colorScheme.surfaceVariant,
                      inputBackgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                      sentMessageBodyTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                      ),
                      receivedMessageBodyTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                      userNameTextStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    customMessageBuilder: (message, {required messageWidth}) {
                      if (message is types.TextMessage) {
                        final isCurrentUser = message.author.id == _currentUser.id;

                        return Column(
                          crossAxisAlignment: isCurrentUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isCurrentUser)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 2),
                                child: Text(
                                  message.author.firstName ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              child: BubbleMessage(
                                message: message as types.TextMessage,  // Add explicit cast here
                                isUser: isCurrentUser,
                                bubbleColor: isCurrentUser
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surfaceVariant,
                                textColor: isCurrentUser
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                                messageWidth: messageWidth.toDouble(),
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class BubbleMessage extends StatelessWidget {
  final types.TextMessage message;
  final bool isUser;
  final Color bubbleColor;
  final Color textColor;
  final double messageWidth;

  const BubbleMessage({
    super.key,
    required this.message,
    required this.isUser,
    required this.bubbleColor,
    required this.textColor,
    required this.messageWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 16 : 4),
          topRight: Radius.circular(isUser ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
      ),
      constraints: BoxConstraints(maxWidth: messageWidth * 0.7),
      child: Text(
        message.text,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
        ),
      ),
    );
  }
}
