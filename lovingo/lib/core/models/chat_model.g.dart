// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatRoom _$ChatRoomFromJson(Map<String, dynamic> json) => ChatRoom(
      id: json['id'] as String,
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: _dateTimeFromJson(json['lastMessageTime']),
      unreadCount: (json['unreadCount'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _dateTimeFromJsonRequired(json['createdAt']),
      type: $enumDecodeNullable(_$ChatRoomTypeEnumMap, json['type']) ??
          ChatRoomType.private,
    );

Map<String, dynamic> _$ChatRoomToJson(ChatRoom instance) => <String, dynamic>{
      'id': instance.id,
      'participants': instance.participants,
      'lastMessage': instance.lastMessage,
      'lastMessageTime': _dateTimeToJson(instance.lastMessageTime),
      'unreadCount': instance.unreadCount,
      'isActive': instance.isActive,
      'createdAt': _dateTimeToJson(instance.createdAt),
      'type': _$ChatRoomTypeEnumMap[instance.type]!,
    };

const _$ChatRoomTypeEnumMap = {
  ChatRoomType.private: 'private',
  ChatRoomType.group: 'group',
  ChatRoomType.support: 'support',
};

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: json['id'] as String,
      chatRoomId: json['chatRoomId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      type: $enumDecode(_$MessageTypeEnumMap, json['type']),
      timestamp: _dateTimeFromJsonRequired(json['timestamp']),
      isRead: json['isRead'] as bool? ?? false,
      mediaUrl: json['mediaUrl'] as String?,
      gift: json['gift'] == null
          ? null
          : GiftData.fromJson(json['gift'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'id': instance.id,
      'chatRoomId': instance.chatRoomId,
      'senderId': instance.senderId,
      'content': instance.content,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'timestamp': _dateTimeToJson(instance.timestamp),
      'isRead': instance.isRead,
      'mediaUrl': instance.mediaUrl,
      'gift': instance.gift,
      'metadata': instance.metadata,
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.video: 'video',
  MessageType.audio: 'audio',
  MessageType.gift: 'gift',
  MessageType.system: 'system',
};

GiftData _$GiftDataFromJson(Map<String, dynamic> json) => GiftData(
      giftId: json['giftId'] as String,
      giftName: json['giftName'] as String,
      giftIcon: json['giftIcon'] as String,
      quantity: (json['quantity'] as num).toInt(),
      totalValue: (json['totalValue'] as num).toInt(),
      animationPath: json['animationPath'] as String,
    );

Map<String, dynamic> _$GiftDataToJson(GiftData instance) => <String, dynamic>{
      'giftId': instance.giftId,
      'giftName': instance.giftName,
      'giftIcon': instance.giftIcon,
      'quantity': instance.quantity,
      'totalValue': instance.totalValue,
      'animationPath': instance.animationPath,
    };
