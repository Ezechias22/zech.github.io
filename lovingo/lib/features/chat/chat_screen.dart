// lib/features/chat/chat_screen.dart - VERSION SANS ERREURS
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ IMPORTS CORRIGÉS
import '../../core/models/user_model.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/call_model.dart';
import '../../core/models/gift_model.dart';
import '../../core/services/auth_service.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/widgets/message_bubble.dart';
import '../../shared/widgets/typing_indicator.dart';
import '../../shared/widgets/gift_selection_sheet.dart';

// WebRTC imports
import '../../features/calls/webrtc_audio_call_screen.dart';
import '../../features/calls/webrtc_video_call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final UserModel otherUser;
  final String chatRoomId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.chatRoomId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _menuAnimationController;
  
  bool _isMenuVisible = false;
  String? _lastTypingTime;

  @override
  void initState() {
    super.initState();
    
    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _messageController.addListener(_onTyping);
  }

  void _onTyping() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final now = DateTime.now().toIso8601String();
    if (_lastTypingTime == null || 
        DateTime.now().difference(DateTime.parse(_lastTypingTime!)).inSeconds > 2) {
      
      FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .update({
        'typingUsers.${currentUser.id}': now,
      });
      
      _lastTypingTime = now;
      
      Future.delayed(const Duration(seconds: 3), () {
        FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.chatRoomId)
            .update({
          'typingUsers.${currentUser.id}': FieldValue.delete(),
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(currentUser),
          ),
          TypingIndicator(
            chatRoomId: widget.chatRoomId,
            currentUserId: currentUser.id,
          ),
          _buildInputArea(currentUser),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 1,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: widget.otherUser.photos.isNotEmpty
                ? NetworkImage(widget.otherUser.photos.first)
                : null,
            child: widget.otherUser.photos.isEmpty
                ? Text(widget.otherUser.name.substring(0, 1).toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'En ligne',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: _makeAudioCall,
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: _makeVideoCall,
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _toggleMenu,
        ),
      ],
    );
  }

  Widget _buildMessagesList(UserModel currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final messages = snapshot.data!.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList();

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isCurrentUser = message.senderId == currentUser.id;
            
            return MessageBubble(
              message: message,
              isCurrentUser: isCurrentUser,
              otherUser: widget.otherUser,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: widget.otherUser.photos.isNotEmpty
                ? NetworkImage(widget.otherUser.photos.first)
                : null,
            child: widget.otherUser.photos.isEmpty
                ? Text(
                    widget.otherUser.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 32),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Commencez votre conversation avec ${widget.otherUser.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Dites bonjour ou envoyez un cadeau virtuel !',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _makeVideoCall,
                icon: const Icon(Icons.videocam),
                label: const Text('Appel vidéo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _showGiftSelection,
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Cadeau'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(UserModel currentUser) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _showGiftSelection,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Tapez votre message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(currentUser),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _sendMessage(currentUser),
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMenu() {
    setState(() {
      _isMenuVisible = !_isMenuVisible;
    });
    
    if (_isMenuVisible) {
      _menuAnimationController.forward();
    } else {
      _menuAnimationController.reverse();
    }
  }

  // ✅ APPEL AUDIO CORRIGÉ
  Future<void> _makeAudioCall() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      final callId = '${currentUser.id}_${widget.otherUser.id}_${DateTime.now().millisecondsSinceEpoch}';
      final channelName = 'channel_$callId';
      
      // ✅ CONSTRUCTEUR CALL CORRIGÉ avec les vrais paramètres
      final call = Call(
        id: callId,
        callerId: currentUser.id,
        receiverId: widget.otherUser.id,
        channelName: channelName,
        type: CallType.audio,
        status: CallStatus.calling,
        createdAt: DateTime.now(),
        hasVideo: false,
      );

      await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .set(call.toMap());

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebRTCAudioCallScreen(
            otherUser: widget.otherUser,
            channelName: channelName,
            isIncoming: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'appel: $e')),
      );
    }
  }

  // ✅ APPEL VIDÉO CORRIGÉ
  Future<void> _makeVideoCall() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      final callId = '${currentUser.id}_${widget.otherUser.id}_${DateTime.now().millisecondsSinceEpoch}';
      final channelName = 'channel_$callId';
      
      // ✅ CONSTRUCTEUR CALL CORRIGÉ avec les vrais paramètres
      final call = Call(
        id: callId,
        callerId: currentUser.id,
        receiverId: widget.otherUser.id,
        channelName: channelName,
        type: CallType.video,
        status: CallStatus.calling,
        createdAt: DateTime.now(),
        hasVideo: true,
      );

      await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .set(call.toMap());

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebRTCVideoCallScreen(
            otherUser: widget.otherUser,
            channelName: channelName,
            isIncoming: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'appel: $e')),
      );
    }
  }

  Future<void> _showGiftSelection() async {
    final result = await showModalBottomSheet<GiftModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GiftSelectionSheet(),
    );

    if (result != null && mounted) {
      await _sendGiftMessage(result);
    }
  }

  // ✅ ENVOI DE CADEAU CORRIGÉ
  Future<void> _sendGiftMessage(GiftModel gift) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      // ✅ CRÉER GIFTDATA CORRECT
      final giftData = GiftData(
        giftId: gift.id,
        giftName: gift.name,
        giftIcon: gift.icon,
        quantity: 1,
        totalValue: gift.price,
        animationPath: gift.animationPath,
      );

      // ✅ CONSTRUCTEUR MESSAGE CORRIGÉ
      final message = Message(
        id: '',
        chatRoomId: widget.chatRoomId,
        senderId: currentUser.id,
        content: 'Vous a envoyé ${gift.name}',
        type: MessageType.gift,
        timestamp: DateTime.now(),
        isRead: false,
        gift: giftData,
      );

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add(message.toMap());

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .update({
        'lastMessage': 'Cadeau: ${gift.name}',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUser.id}': FieldValue.increment(1),
      });

      if (!mounted) return;

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${gift.name} envoyé avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi: $e')),
      );
    }
  }

  // ✅ ENVOI DE MESSAGE CORRIGÉ
  Future<void> _sendMessage(UserModel currentUser) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // ✅ CONSTRUCTEUR MESSAGE CORRIGÉ
      final message = Message(
        id: '',
        chatRoomId: widget.chatRoomId,
        senderId: currentUser.id,
        content: text,
        type: MessageType.text,
        timestamp: DateTime.now(),
        isRead: false,
      );

      _messageController.clear();

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add(message.toMap());

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUser.id}': FieldValue.increment(1),
      });

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .update({
        'typingUsers.${currentUser.id}': FieldValue.delete(),
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _menuAnimationController.dispose();
    super.dispose();
  }
}