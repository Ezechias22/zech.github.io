import 'package:flutter/material.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/user_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final UserModel otherUser;
  
  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isCurrentUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(otherUser.photos.isNotEmpty 
                  ? otherUser.photos.first 
                  : 'https://via.placeholder.com/100'),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isCurrentUser 
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      )
                    : null,
                color: isCurrentUser ? null : Colors.grey[300],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
