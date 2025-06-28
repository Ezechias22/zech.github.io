// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gift_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GiftModel _$GiftModelFromJson(Map<String, dynamic> json) => GiftModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      animationPath: json['animationPath'] as String,
      price: (json['price'] as num).toInt(),
      rarity: $enumDecode(_$GiftRarityEnumMap, json['rarity']),
      isPremiumOnly: json['isPremiumOnly'] as bool? ?? false,
    );

Map<String, dynamic> _$GiftModelToJson(GiftModel instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'animationPath': instance.animationPath,
      'price': instance.price,
      'rarity': _$GiftRarityEnumMap[instance.rarity]!,
      'isPremiumOnly': instance.isPremiumOnly,
    };

const _$GiftRarityEnumMap = {
  GiftRarity.common: 'common',
  GiftRarity.rare: 'rare',
  GiftRarity.epic: 'epic',
  GiftRarity.legendary: 'legendary',
};

GiftTransaction _$GiftTransactionFromJson(Map<String, dynamic> json) =>
    GiftTransaction(
      id: json['id'] as String,
      giftId: json['giftId'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      chatRoomId: json['chatRoomId'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$GiftTransactionToJson(GiftTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'giftId': instance.giftId,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'chatRoomId': instance.chatRoomId,
      'quantity': instance.quantity,
      'timestamp': instance.timestamp.toIso8601String(),
    };

GiftAnimation _$GiftAnimationFromJson(Map<String, dynamic> json) =>
    GiftAnimation(
      id: json['id'] as String,
      giftId: json['giftId'] as String,
      giftIcon: json['giftIcon'] as String,
      animationPath: json['animationPath'] as String,
      rarity: $enumDecode(_$GiftRarityEnumMap, json['rarity']),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      senderId: json['senderId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$GiftAnimationToJson(GiftAnimation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'giftId': instance.giftId,
      'giftIcon': instance.giftIcon,
      'animationPath': instance.animationPath,
      'rarity': _$GiftRarityEnumMap[instance.rarity]!,
      'quantity': instance.quantity,
      'senderId': instance.senderId,
      'timestamp': instance.timestamp.toIso8601String(),
    };
