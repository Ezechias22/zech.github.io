// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      gender: json['gender'] as String,
      genderPreference: (json['genderPreference'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      bio: json['bio'] as String,
      photos:
          (json['photos'] as List<dynamic>).map((e) => e as String).toList(),
      videos:
          (json['videos'] as List<dynamic>).map((e) => e as String).toList(),
      interests:
          (json['interests'] as List<dynamic>).map((e) => e as String).toList(),
      location: json['location'] == null
          ? null
          : UserLocation.fromJson(json['location'] as Map<String, dynamic>),
      isPremium: json['isPremium'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      isOnline: json['isOnline'] as bool? ?? false,
      lastActive: DateTime.parse(json['lastActive'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      minAge: (json['minAge'] as num?)?.toInt() ?? 18,
      maxAge: (json['maxAge'] as num?)?.toInt() ?? 50,
      maxDistance: (json['maxDistance'] as num?)?.toDouble() ?? 50.0,
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>),
      wallet: WalletInfo.fromJson(json['wallet'] as Map<String, dynamic>),
      preferences: json['preferences'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'phone': instance.phone,
      'name': instance.name,
      'age': instance.age,
      'gender': instance.gender,
      'genderPreference': instance.genderPreference,
      'bio': instance.bio,
      'photos': instance.photos,
      'videos': instance.videos,
      'interests': instance.interests,
      'location': instance.location,
      'isPremium': instance.isPremium,
      'isActive': instance.isActive,
      'isOnline': instance.isOnline,
      'lastActive': instance.lastActive.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'minAge': instance.minAge,
      'maxAge': instance.maxAge,
      'maxDistance': instance.maxDistance,
      'stats': instance.stats,
      'wallet': instance.wallet,
      'preferences': instance.preferences,
    };

UserLocation _$UserLocationFromJson(Map<String, dynamic> json) => UserLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      city: json['city'] as String?,
      country: json['country'] as String?,
    );

Map<String, dynamic> _$UserLocationToJson(UserLocation instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'city': instance.city,
      'country': instance.country,
    };

UserStats _$UserStatsFromJson(Map<String, dynamic> json) => UserStats(
      totalLikes: (json['totalLikes'] as num?)?.toInt() ?? 0,
      totalMatches: (json['totalMatches'] as num?)?.toInt() ?? 0,
      totalGiftsReceived: (json['totalGiftsReceived'] as num?)?.toInt() ?? 0,
      totalGiftsSent: (json['totalGiftsSent'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      profileViews: (json['profileViews'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$UserStatsToJson(UserStats instance) => <String, dynamic>{
      'totalLikes': instance.totalLikes,
      'totalMatches': instance.totalMatches,
      'totalGiftsReceived': instance.totalGiftsReceived,
      'totalGiftsSent': instance.totalGiftsSent,
      'totalEarnings': instance.totalEarnings,
      'profileViews': instance.profileViews,
    };

WalletInfo _$WalletInfoFromJson(Map<String, dynamic> json) => WalletInfo(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      pendingWithdrawal: (json['pendingWithdrawal'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String?,
    );

Map<String, dynamic> _$WalletInfoToJson(WalletInfo instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'totalEarnings': instance.totalEarnings,
      'pendingWithdrawal': instance.pendingWithdrawal,
      'paymentMethod': instance.paymentMethod,
    };
