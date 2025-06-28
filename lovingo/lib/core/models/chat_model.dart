import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'chat_model.g.dart';

@JsonSerializable()
class ChatRoom {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final bool isActive;
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJson)
  final DateTime createdAt;
  final ChatRoomType type;

  const ChatRoom({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = const {},
    this.isActive = true,
    required this.createdAt,
    this.type = ChatRoomType.private,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) => _$ChatRoomFromJson(json);
  Map<String, dynamic> toJson() => _$ChatRoomToJson(this);

  // ✅ NOUVEAU : Méthode pour créer depuis Firestore
  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom.fromJson({
      'id': doc.id,
      ...data,
    });
  }
}

@JsonSerializable()
class Message {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String content;
  final MessageType type;
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJson)
  final DateTime timestamp;
  final bool isRead;
  final String? mediaUrl;
  final GiftData? gift;
  final Map<String, dynamic>? metadata;

  const Message({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.mediaUrl,
    this.gift,
    this.metadata,
  });

  // ✅ MÉTHODES EXISTANTES
  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  // ✅ NOUVELLES MÉTHODES FIRESTORE AJOUTÉES
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message.fromJson({
      'id': doc.id,
      ...data,
    });
  }

  Map<String, dynamic> toMap() => toJson();

  // ✅ MÉTHODE COPYWITH POUR FACILITER LES MODIFICATIONS
  Message copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    String? mediaUrl,
    GiftData? gift,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      gift: gift ?? this.gift,
      metadata: metadata ?? this.metadata,
    );
  }
}

@JsonSerializable()
class GiftData {
  final String giftId;
  final String giftName;
  final String giftIcon;
  final int quantity;
  final int totalValue;
  final String animationPath;

  const GiftData({
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.quantity,
    required this.totalValue,
    required this.animationPath,
  });

  factory GiftData.fromJson(Map<String, dynamic> json) => _$GiftDataFromJson(json);
  Map<String, dynamic> toJson() => _$GiftDataToJson(this);
}

enum MessageType { text, image, video, audio, gift, system }
enum ChatRoomType { private, group, support }

// ✅ FONCTIONS UTILITAIRES POUR GÉRER LES TIMESTAMPS FIRESTORE
DateTime? _dateTimeFromJson(dynamic value) {
  if (value == null) return null;
  
  // Si c'est déjà un DateTime
  if (value is DateTime) return value;
  
  // Si c'est un Timestamp Firestore
  if (value is Timestamp) return value.toDate();
  
  // ✅ NOUVEAU : Gérer les FieldValue.serverTimestamp() qui arrivent comme null
  // pendant la synchronisation Firestore
  if (value == null) return DateTime.now();
  
  // Si c'est une String ISO
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      print('❌ Erreur parsing date: $value - $e');
      return DateTime.now(); // ✅ Fallback vers maintenant
    }
  }
  
  // Si c'est un entier (milliseconds depuis epoch)
  if (value is int) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (e) {
      print('❌ Erreur parsing timestamp: $value - $e');
      return DateTime.now(); // ✅ Fallback vers maintenant
    }
  }
  
  print('❌ Type de date non supporté: ${value.runtimeType} - $value');
  return DateTime.now(); // ✅ Fallback vers maintenant
}

// ✅ NOUVELLE : Fonction pour les DateTime requis (non-nullable)
DateTime _dateTimeFromJsonRequired(dynamic value) {
  if (value == null) return DateTime.now(); // Valeur par défaut
  
  // Si c'est déjà un DateTime
  if (value is DateTime) return value;
  
  // Si c'est un Timestamp Firestore
  if (value is Timestamp) return value.toDate();
  
  // ✅ NOUVEAU : Gérer les FieldValue.serverTimestamp() pendant la sync
  if (value == null) return DateTime.now();
  
  // Si c'est une String ISO
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      print('❌ Erreur parsing date: $value - $e');
      return DateTime.now(); // Valeur par défaut en cas d'erreur
    }
  }
  
  // Si c'est un entier (milliseconds depuis epoch)
  if (value is int) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (e) {
      print('❌ Erreur parsing timestamp: $value - $e');
      return DateTime.now(); // Valeur par défaut en cas d'erreur
    }
  }
  
  print('❌ Type de date non supporté: ${value.runtimeType} - $value');
  return DateTime.now(); // Valeur par défaut
}

dynamic _dateTimeToJson(DateTime? dateTime) {
  if (dateTime == null) return null;
  // ✅ POUR FIRESTORE : Toujours utiliser Timestamp pour la cohérence
  return Timestamp.fromDate(dateTime);
}