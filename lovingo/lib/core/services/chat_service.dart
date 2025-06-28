import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// ✅ CORRIGÉ : Provider pour les messages avec tri par timestamp serveur
final chatMessagesProvider = StreamProvider.family<List<Message>, String>((ref, chatRoomId) {
  return FirebaseFirestore.instance
      .collection('chat_rooms')
      .doc(chatRoomId)
      .collection('messages')
      .orderBy('timestamp', descending: true) // ✅ Tri par timestamp serveur
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
          .toList());
});

// ✅ CORRIGÉ : Provider pour la liste des conversations avec gestion des Timestamp
final chatRoomsProvider = StreamProvider<List<ChatRoom>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('chat_rooms')
      .where('participants', arrayContains: currentUser.id)
      .orderBy('lastMessageTime', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ChatRoom.fromJson({...doc.data(), 'id': doc.id}))
          .toList());
});

// ✅ CORRIGÉ : Provider pour les détails utilisateur dans les chats
final chatUserProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  
  if (doc.exists) {
    return UserModel.fromMap(doc.data()!, doc.id);
  }
  return null;
});

// Provider pour les animations de cadeaux
final giftAnimationsProvider = StreamProvider.family<List<GiftAnimation>, String>((ref, chatRoomId) {
  return Stream.value(<GiftAnimation>[]);
});

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ CORRIGÉ : Envoi de message avec Timestamp serveur
  Future<void> sendMessage(Message message) async {
    try {
      // Créer ou mettre à jour la chat room
      await _ensureChatRoomExists(message.chatRoomId, message.senderId);
      
      // ✅ UTILISER LE TIMESTAMP SERVEUR POUR L'ORDRE CORRECT
      final serverTimestamp = FieldValue.serverTimestamp();
      
      // Sauvegarder le message avec timestamp serveur
      await _firestore
          .collection('chat_rooms')
          .doc(message.chatRoomId)
          .collection('messages')
          .add({
        ...message.toJson(),
        'timestamp': serverTimestamp, // ✅ TIMESTAMP SERVEUR
      });
      
      // Mettre à jour le dernier message dans la chat room
      await _firestore
          .collection('chat_rooms')
          .doc(message.chatRoomId)
          .update({
        'lastMessage': message.content,
        'lastMessageTime': serverTimestamp, // ✅ TIMESTAMP SERVEUR
        'lastMessageSenderId': message.senderId,
      });
      
      print('✅ Message envoyé: ${message.content}');
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      throw Exception('Erreur lors de l\'envoi du message');
    }
  }

  // ✅ CORRIGÉ : Création automatique de chat room avec Timestamp
  Future<void> _ensureChatRoomExists(String chatRoomId, String senderId) async {
    final chatRoomDoc = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .get();
    
    if (!chatRoomDoc.exists) {
      // Extraire les participants du chatRoomId
      // Format attendu: "user1_user2" ou similaire
      final participants = chatRoomId.split('_');
      
      final chatRoom = ChatRoom(
        id: chatRoomId,
        participants: participants,
        lastMessage: null,
        lastMessageTime: null,
        unreadCount: {},
        isActive: true,
        createdAt: DateTime.now(),
        type: ChatRoomType.private,
      );
      
      // Sauvegarder avec timestamp serveur
      final chatRoomData = chatRoom.toJson();
      chatRoomData['createdAt'] = FieldValue.serverTimestamp(); // ✅ TIMESTAMP SERVEUR
      
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .set(chatRoomData);
      
      print('✅ Chat room créée: $chatRoomId');
    }
  }

  // ✅ CORRIGÉ : Statut de frappe avec Timestamp
  Future<void> updateTypingStatus(String chatRoomId, String userId, bool isTyping) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .update({
        'typingUsers.$userId': isTyping 
            ? FieldValue.serverTimestamp() // ✅ TIMESTAMP SERVEUR
            : FieldValue.delete(),
      });
    } catch (e) {
      print('❌ Erreur statut frappe: $e');
    }
  }

  // ✅ NOUVEAU : Marquer les messages comme lus
  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      final messagesQuery = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      // Réinitialiser le compteur de messages non lus
      batch.update(
        _firestore.collection('chat_rooms').doc(chatRoomId),
        {'unreadCount.$userId': 0},
      );
      
      await batch.commit();
      print('✅ Messages marqués comme lus dans $chatRoomId');
    } catch (e) {
      print('❌ Erreur marquage lecture: $e');
    }
  }

  // ✅ CORRIGÉ : Créer une nouvelle conversation avec Timestamp
  Future<String> createChatRoom(String otherUserId, String currentUserId) async {
    try {
      // Créer un ID unique et cohérent pour la chat room
      final participants = [currentUserId, otherUserId]..sort();
      final chatRoomId = participants.join('_');
      
      // Vérifier si la conversation existe déjà
      final existingRoom = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .get();
      
      if (!existingRoom.exists) {
        final chatRoom = ChatRoom(
          id: chatRoomId,
          participants: participants,
          lastMessage: null,
          lastMessageTime: null,
          unreadCount: {currentUserId: 0, otherUserId: 0},
          isActive: true,
          createdAt: DateTime.now(),
          type: ChatRoomType.private,
        );
        
        // Sauvegarder avec timestamp serveur
        final chatRoomData = chatRoom.toJson();
        chatRoomData['createdAt'] = FieldValue.serverTimestamp(); // ✅ TIMESTAMP SERVEUR
        
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .set(chatRoomData);
        
        print('✅ Nouvelle conversation créée: $chatRoomId');
      }
      
      return chatRoomId;
    } catch (e) {
      print('❌ Erreur création conversation: $e');
      throw Exception('Erreur lors de la création de la conversation');
    }
  }

  // ✅ NOUVEAU : Supprimer une conversation
  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      // Supprimer tous les messages
      final messagesQuery = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Supprimer la chat room
      batch.delete(_firestore.collection('chat_rooms').doc(chatRoomId));
      
      await batch.commit();
      print('✅ Conversation supprimée: $chatRoomId');
    } catch (e) {
      print('❌ Erreur suppression conversation: $e');
      throw Exception('Erreur lors de la suppression de la conversation');
    }
  }

  // ✅ NOUVEAU : Obtenir le nombre de messages non lus
  Stream<int> getUnreadMessagesCount(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<String, dynamic>? ?? {};
        totalUnread += (unreadCount[userId] as int?) ?? 0;
      }
      return totalUnread;
    });
  }

  // ✅ NOUVEAU : Méthode pour récupérer un utilisateur
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération utilisateur: $e');
      return null;
    }
  }

  // ✅ NOUVEAU : Méthode pour récupérer les messages
  Stream<List<Message>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
}

// ✅ NOUVEAU : Classes pour animations (si nécessaire)
class GiftAnimation {
  final String id;
  final String giftId;
  final String animationType;
  final DateTime timestamp;
  
  const GiftAnimation({
    required this.id,
    required this.giftId,
    required this.animationType,
    required this.timestamp,
  });
}