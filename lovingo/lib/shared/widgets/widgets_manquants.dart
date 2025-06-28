import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/models/chat_model.dart';

// Widgets temporaires pour compilation
class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: const Center(
        child: Text('Filtres (À implémenter)'),
      ),
    );
  }
}

class GiftSelectionSheet extends StatelessWidget {
  const GiftSelectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: const Center(
        child: Text('Sélection Cadeaux (À implémenter)'),
      ),
    );
  }
}

class UserDetailsSheet extends StatelessWidget {
  final UserModel user;
  
  const UserDetailsSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text('Détails de ${user.name} (À implémenter)'),
      ),
    );
  }
}

class FloatingGiftButton extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onPressed;
  
  const FloatingGiftButton({
    super.key,
    required this.animationController,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      child: const Icon(Icons.card_giftcard),
    );
  }
}

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
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: const Text('En train d\'écrire...'),
    );
  }
}