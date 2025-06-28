import 'package:json_annotation/json_annotation.dart';

part 'gift_model.g.dart';

enum GiftRarity {
  @JsonValue('common')
  common,
  @JsonValue('rare')
  rare,
  @JsonValue('epic')
  epic,
  @JsonValue('legendary')
  legendary,
}

@JsonSerializable()
class GiftModel {
  final String id;
  final String name;
  final String icon;
  final String animationPath;
  final int price; // Prix en crédits
  final GiftRarity rarity;
  final bool isPremiumOnly;

  const GiftModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.animationPath,
    required this.price,
    required this.rarity,
    this.isPremiumOnly = false,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) => _$GiftModelFromJson(json);
  Map<String, dynamic> toJson() => _$GiftModelToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'animationPath': animationPath,
      'price': price,
      'rarity': rarity.toString().split('.').last,
      'isPremiumOnly': isPremiumOnly,
    };
  }

  factory GiftModel.fromMap(Map<String, dynamic> map) {
    return GiftModel(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      animationPath: map['animationPath'],
      price: map['price'],
      rarity: GiftRarity.values.firstWhere(
        (e) => e.toString().split('.').last == map['rarity'],
        orElse: () => GiftRarity.common,
      ),
      isPremiumOnly: map['isPremiumOnly'] ?? false,
    );
  }
}

@JsonSerializable()
class GiftTransaction {
  final String id;
  final String giftId;
  final String senderId;
  final String receiverId;
  final String chatRoomId;
  final int quantity;
  final DateTime timestamp;

  const GiftTransaction({
    required this.id,
    required this.giftId,
    required this.senderId,
    required this.receiverId,
    required this.chatRoomId,
    this.quantity = 1,
    required this.timestamp,
  });

  factory GiftTransaction.fromJson(Map<String, dynamic> json) => _$GiftTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$GiftTransactionToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'giftId': giftId,
      'senderId': senderId,
      'receiverId': receiverId,
      'chatRoomId': chatRoomId,
      'quantity': quantity,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory GiftTransaction.fromMap(Map<String, dynamic> map) {
    return GiftTransaction(
      id: map['id'],
      giftId: map['giftId'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      chatRoomId: map['chatRoomId'],
      quantity: map['quantity'] ?? 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

@JsonSerializable()
class GiftAnimation {
  final String id;
  final String giftId;
  final String giftIcon;
  final String animationPath;
  final GiftRarity rarity;
  final int quantity;
  final String senderId;
  final DateTime timestamp;

  const GiftAnimation({
    required this.id,
    required this.giftId,
    required this.giftIcon,
    required this.animationPath,
    required this.rarity,
    this.quantity = 1,
    required this.senderId,
    required this.timestamp,
  });

  factory GiftAnimation.fromJson(Map<String, dynamic> json) => _$GiftAnimationFromJson(json);
  Map<String, dynamic> toJson() => _$GiftAnimationToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'giftId': giftId,
      'giftIcon': giftIcon,
      'animationPath': animationPath,
      'rarity': rarity.toString().split('.').last,
      'quantity': quantity,
      'senderId': senderId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory GiftAnimation.fromMap(Map<String, dynamic> map) {
    return GiftAnimation(
      id: map['id'],
      giftId: map['giftId'],
      giftIcon: map['giftIcon'],
      animationPath: map['animationPath'],
      rarity: GiftRarity.values.firstWhere(
        (e) => e.toString().split('.').last == map['rarity'],
        orElse: () => GiftRarity.common,
      ),
      quantity: map['quantity'] ?? 1,
      senderId: map['senderId'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

// Données des cadeaux par défaut
class DefaultGifts {
  static final List<GiftModel> gifts = [
    GiftModel(
      id: 'rose',
      name: 'Rose',
      icon: '🌹',
      animationPath: 'assets/animations/rose.json',
      price: 10,
      rarity: GiftRarity.common,
    ),
    GiftModel(
      id: 'heart',
      name: 'Cœur',
      icon: '❤️',
      animationPath: 'assets/animations/heart.json',
      price: 5,
      rarity: GiftRarity.common,
    ),
    GiftModel(
      id: 'diamond',
      name: 'Diamant',
      icon: '💎',
      animationPath: 'assets/animations/diamond.json',
      price: 100,
      rarity: GiftRarity.epic,
      isPremiumOnly: true,
    ),
    GiftModel(
      id: 'crown',
      name: 'Couronne',
      icon: '👑',
      animationPath: 'assets/animations/crown.json',
      price: 500,
      rarity: GiftRarity.legendary,
      isPremiumOnly: true,
    ),
  ];
}
