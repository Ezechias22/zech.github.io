// lib/core/models/live_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveRoom {
  final String id;
  final String hostId;
  final String title;
  final String? description;
  final List<String> tags;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? endedAt;
  final Map<String, dynamic> settings;
  final int viewerCount;
  final int guestCount;
  final int heartCount;
  final int giftCount;

  const LiveRoom({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    required this.tags,
    required this.isActive,
    required this.createdAt,
    this.endedAt,
    required this.settings,
    required this.viewerCount,
    required this.guestCount,
    required this.heartCount,
    required this.giftCount,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'hostId': hostId,
    'title': title,
    'description': description,
    'tags': tags,
    'isActive': isActive,
    'createdAt': Timestamp.fromDate(createdAt),
    'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    'settings': settings,
    'viewerCount': viewerCount,
    'guestCount': guestCount,
    'heartCount': heartCount,
    'giftCount': giftCount,
  };

  factory LiveRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveRoom(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      tags: List<String>.from(data['tags'] ?? []),
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
      viewerCount: data['viewerCount'] ?? 0,
      guestCount: data['guestCount'] ?? 0,
      heartCount: data['heartCount'] ?? 0,
      giftCount: data['giftCount'] ?? 0,
    );
  }
}

class LiveGuest {
  final String userId;
  final DateTime joinedAt;
  final bool isMuted;
  final bool isVideoEnabled;

  LiveGuest({
    required this.userId,
    required this.joinedAt,
    required this.isMuted,
    required this.isVideoEnabled,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'joinedAt': Timestamp.fromDate(joinedAt),
    'isMuted': isMuted,
    'isVideoEnabled': isVideoEnabled,
  };
}

class LiveViewer {
  final String userId;
  final DateTime joinedAt;

  LiveViewer({
    required this.userId,
    required this.joinedAt,
  });
}

class LiveStats {
  final int viewerCount;
  final int guestCount;
  final int heartCount;
  final int giftCount;
  final Duration duration;

  LiveStats({
    required this.viewerCount,
    required this.guestCount,
    required this.heartCount,
    required this.giftCount,
    required this.duration,
  });
}

class LiveMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final LiveMessageType type;

  LiveMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'message': message,
    'timestamp': Timestamp.fromDate(timestamp),
    'type': type.name,
  };
}

enum LiveMessageType {
  chat,
  system,
  gift,
}

class VirtualGift {
  final String id;
  final String giftId;
  final int quantity;
  final String senderId;
  final String senderName;
  final String? targetUserId;
  final DateTime timestamp;
  final String liveId;

  VirtualGift({
    required this.id,
    required this.giftId,
    required this.quantity,
    required this.senderId,
    required this.senderName,
    this.targetUserId,
    required this.timestamp,
    required this.liveId, required int value,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'giftId': giftId,
    'quantity': quantity,
    'senderId': senderId,
    'senderName': senderName,
    'targetUserId': targetUserId,
    'timestamp': Timestamp.fromDate(timestamp),
    'liveId': liveId,
  };
}