import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/chat_service.dart';

class TypingIndicator extends ConsumerWidget {
  final String chatRoomId;
  final String currentUserId;

  const TypingIndicator({
    super.key,
    required this.chatRoomId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final typingUsers = data?['typingUsers'] as Map<String, dynamic>? ?? {};
        
        // Filtrer pour exclure l'utilisateur actuel et vérifier la frappe récente
        final otherUsersTyping = typingUsers.entries
            .where((entry) => 
                entry.key != currentUserId && 
                _isRecentlyTyping(entry.value))
            .toList();
        
        if (otherUsersTyping.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return const _TypingAnimation();
      },
    );
  }
  
  bool _isRecentlyTyping(dynamic timestamp) {
    if (timestamp == null) return false;
    
    try {
      final typingTime = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      // Considérer comme "en train de taper" si moins de 3 secondes
      return now.difference(typingTime).inSeconds < 3;
    } catch (e) {
      return false;
    }
  }
}

class _TypingAnimation extends StatefulWidget {
  const _TypingAnimation();

  @override
  State<_TypingAnimation> createState() => _TypingAnimationState();
}

class _TypingAnimationState extends State<_TypingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(0),
                    const SizedBox(width: 4),
                    _buildDot(1),
                    const SizedBox(width: 4),
                    _buildDot(2),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'En train d\'écrire...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final value = (_controller.value - (index * 0.2)).clamp(0.0, 1.0);
    final opacity = (1.0 - (value * 2 - 1).abs()).clamp(0.3, 1.0);

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[600]!.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}