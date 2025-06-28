import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../shared/themes/app_theme.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  Widget build(BuildContext context) {
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final unreadCountAsync = currentUser != null
                  ? ref.watch(StreamProvider((ref) => 
                      ref.read(chatServiceProvider).getUnreadMessagesCount(currentUser.id)))
                  : const AsyncValue.data(0);

              return unreadCountAsync.when(
                data: (count) => count > 0
                    ? Container(
                        margin: const EdgeInsets.only(right: 16, top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const SizedBox(),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              );
            },
          ),
        ],
      ),
      body: chatRoomsAsync.when(
        data: (chatRooms) {
          if (chatRooms.isEmpty) {
            return _buildEmptyState();
          }

          // Tri des conversations par date de dernier message
          chatRooms.sort((a, b) => 
              (b.lastMessageTime ?? DateTime(1970)).compareTo(a.lastMessageTime ?? DateTime(1970)));

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(chatRoomsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chatRooms.length,
              itemBuilder: (context, index) {
                final chatRoom = chatRooms[index];
                return _buildChatTile(context, chatRoom, currentUser);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatRoom chatRoom, UserModel? currentUser) {
    if (currentUser == null) return const SizedBox();

    // Trouver l'autre participant
    final otherUserId = chatRoom.participants
        .firstWhere((id) => id != currentUser.id, orElse: () => '');

    if (otherUserId.isEmpty) return const SizedBox();

    return FutureBuilder<UserModel?>(
      future: ref.read(chatServiceProvider).getUser(otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildLoadingTile();
        }

        final otherUser = snapshot.data!;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _buildAvatar(otherUser),
            title: Text(
              otherUser.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildSubtitle(chatRoom),
            trailing: _buildTrailing(chatRoom, currentUser.id),
            onTap: () => _openChat(context, chatRoom.id, otherUser),
            onLongPress: () => _showChatOptions(context, chatRoom),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(UserModel user) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[200],
          backgroundImage: user.photos.isNotEmpty
              ? NetworkImage(user.photos.first)
              : null,
          child: user.photos.isEmpty
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
        if (user.isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubtitle(ChatRoom chatRoom) {
    if (chatRoom.lastMessage == null || chatRoom.lastMessage!.isEmpty) {
      return const Text(
        'Commencez la conversation...',
        style: TextStyle(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text(
      chatRoom.lastMessage!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
      ),
    );
  }

  Widget _buildTrailing(ChatRoom chatRoom, String currentUserId) {
    final unreadCount = chatRoom.unreadCount[currentUserId] ?? 0;
    final lastMessageTime = chatRoom.lastMessageTime;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (lastMessageTime != null)
          Text(
            _formatTimestamp(lastMessageTime),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 4),
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          const SizedBox(height: 18),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == yesterday) {
      return 'Hier';
    } else if (now.difference(timestamp).inDays < 7) {
      return DateFormat('EEEE', 'fr').format(timestamp);
    } else {
      return DateFormat('dd/MM/yy').format(timestamp);
    }
  }

  Widget _buildLoadingTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const ListTile(
        leading: CircleAvatar(backgroundColor: Colors.grey),
        title: Text('Chargement...'),
        subtitle: Text(''),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez à matcher pour débuter des conversations !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(chatRoomsProvider),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, String chatRoomId, UserModel otherUser) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref.read(chatServiceProvider).markMessagesAsRead(chatRoomId, currentUser.id);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatRoomId: chatRoomId,
          otherUser: otherUser,
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context, ChatRoom chatRoom) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer la conversation'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteChat(context, chatRoom);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Bloquer l\'utilisateur'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Blocage à implémenter')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context, ChatRoom chatRoom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la conversation'),
        content: const Text('Cette action est irréversible. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatServiceProvider).deleteChatRoom(chatRoom.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation supprimée')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}