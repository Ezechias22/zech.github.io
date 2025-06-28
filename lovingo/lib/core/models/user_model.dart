import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lovingo/features/home/home_screen.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String email;
  final String phone;
  final String name;
  final int age;
  final String gender;
  final List<String> genderPreference;
  final String bio;
  final List<String> photos;
  final List<String> videos;
  final List<String> interests;
  final UserLocation? location;
  final bool isPremium;
  final bool isActive;
  final bool isOnline;
  final DateTime lastActive;
  final DateTime createdAt;
  final int minAge;
  final int maxAge;
  final double maxDistance;
  final UserStats stats;
  final WalletInfo wallet;
  final Map<String, dynamic> preferences;

  const UserModel({
    required this.id,
    required this.email,
    required this.phone,
    required this.name,
    required this.age,
    required this.gender,
    required this.genderPreference,
    required this.bio,
    required this.photos,
    required this.videos,
    required this.interests,
    this.location,
    this.isPremium = false,
    this.isActive = true,
    this.isOnline = false,
    required this.lastActive,
    required this.createdAt,
    this.minAge = 18,
    this.maxAge = 50,
    this.maxDistance = 50.0,
    required this.stats,
    required this.wallet,
    this.preferences = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
  
  // ✅ FACTORY PRINCIPALE POUR FIRESTORE (compatible avec les deux syntaxes)
  factory UserModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final userId = id ?? map['id'] ?? '';
    return UserModel(
      id: userId,
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      name: map['name'] ?? 'Utilisateur',
      age: map['age'] ?? 25,
      gender: map['gender'] ?? 'other',
      genderPreference: List<String>.from(map['genderPreference'] ?? ['all']),
      bio: map['bio'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      videos: List<String>.from(map['videos'] ?? []),
      interests: List<String>.from(map['interests'] ?? []),
      location: map['location'] != null ? UserLocation.fromJson(map['location']) : null,
      isPremium: map['isPremium'] ?? false,
      isActive: map['isActive'] ?? true,
      isOnline: map['isOnline'] ?? false,
      // ✅ CORRIGÉ : Gérer les deux formats de date (String et Timestamp)
      lastActive: _parseDate(map['lastActive']),
      createdAt: _parseDate(map['createdAt']),
      minAge: map['minAge'] ?? 18,
      maxAge: map['maxAge'] ?? 50,
      maxDistance: (map['maxDistance'] ?? 50.0).toDouble(),
      stats: map['stats'] != null ? UserStats.fromJson(map['stats']) : const UserStats(),
      wallet: map['wallet'] != null ? WalletInfo.fromJson(map['wallet']) : const WalletInfo(),
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
    );
  }

  // ✅ MÉTHODE HELPER POUR PARSER LES DATES (String OU Timestamp)
  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    } else if (dateValue is Timestamp) {
      // Format Firestore Timestamp
      return dateValue.toDate();
    } else if (dateValue is String) {
      // Format ISO8601 String
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('⚠️ Erreur parsing date: $dateValue, utilisation date actuelle');
        return DateTime.now();
      }
    } else {
      print('⚠️ Type de date non reconnu: ${dateValue.runtimeType}, utilisation date actuelle');
      return DateTime.now();
    }
  }

  // ✅ FACTORY SIMPLIFIÉE POUR LES APPELS (données minimales)
  factory UserModel.forCall({
    required String id,
    required String name,
    String? email,
    List<String>? photos,
  }) {
    return UserModel(
      id: id,
      email: email ?? '',
      phone: '',
      name: name,
      age: 25,
      gender: 'other',
      genderPreference: ['all'],
      bio: '',
      photos: photos ?? [],
      videos: [],
      interests: [],
      location: null,
      isPremium: false,
      isActive: true,
      isOnline: true,
      lastActive: DateTime.now(),
      createdAt: DateTime.now(),
      minAge: 18,
      maxAge: 50,
      maxDistance: 50.0,
      stats: const UserStats(),
      wallet: const WalletInfo(),
      preferences: {},
    );
  }
  
  Map<String, dynamic> toMap() => toJson();

  // ✅ MÉTHODE POUR OBTENIR LES DONNÉES ESSENTIELLES D'APPEL
  Map<String, dynamic> toCallData() => {
    'id': id,
    'name': name,
    'email': email,
    'photos': photos,
    'isOnline': isOnline,
    'isActive': isActive,
  };

  // ✅ FACTORY DEPUIS LES DONNÉES D'APPEL
  factory UserModel.fromCallData(Map<String, dynamic> data) {
    return UserModel.forCall(
      id: data['id'] ?? '',
      name: data['name'] ?? 'Utilisateur',
      email: data['email'],
      photos: data['photos'] != null ? List<String>.from(data['photos']) : null,
    );
  }

  // ✅ COPYWITH POUR MISES À JOUR IMMUTABLES
  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? name,
    int? age,
    String? gender,
    List<String>? genderPreference,
    String? bio,
    List<String>? photos,
    List<String>? videos,
    List<String>? interests,
    UserLocation? location,
    bool? isPremium,
    bool? isActive,
    bool? isOnline,
    DateTime? lastActive,
    DateTime? createdAt,
    int? minAge,
    int? maxAge,
    double? maxDistance,
    UserStats? stats,
    WalletInfo? wallet,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      genderPreference: genderPreference ?? this.genderPreference,
      bio: bio ?? this.bio,
      photos: photos ?? this.photos,
      videos: videos ?? this.videos,
      interests: interests ?? this.interests,
      location: location ?? this.location,
      isPremium: isPremium ?? this.isPremium,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
      createdAt: createdAt ?? this.createdAt,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistance: maxDistance ?? this.maxDistance,
      stats: stats ?? this.stats,
      wallet: wallet ?? this.wallet,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class UserLocation {
  final double latitude;
  final double longitude;
  final String? city;
  final String? country;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.city,
    this.country,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) => _$UserLocationFromJson(json);

  get isNotEmpty => latitude != 0.0 && longitude != 0.0;
  Map<String, dynamic> toJson() => _$UserLocationToJson(this);

  @override
  String toString() {
    return 'UserLocation(lat: $latitude, lng: $longitude, city: $city, country: $country)';
  }
}

@JsonSerializable()
class UserStats {
  final int totalLikes;
  final int totalMatches;
  final int totalGiftsReceived;
  final int totalGiftsSent;
  final double totalEarnings;
  final int profileViews;

  const UserStats({
    this.totalLikes = 0,
    this.totalMatches = 0,
    this.totalGiftsReceived = 0,
    this.totalGiftsSent = 0,
    this.totalEarnings = 0.0,
    this.profileViews = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => _$UserStatsFromJson(json);
  Map<String, dynamic> toJson() => _$UserStatsToJson(this);

  @override
  String toString() {
    return 'UserStats(likes: $totalLikes, matches: $totalMatches, earnings: $totalEarnings)';
  }

  static fromLocalStats(LocalUserStats localUserStats) {}
}

class LocalUserStats {
}

@JsonSerializable()
class WalletInfo {
  final double balance;
  final double totalEarnings;
  final double pendingWithdrawal;
  final String? paymentMethod;

  const WalletInfo({
    this.balance = 0.0,
    this.totalEarnings = 0.0,
    this.pendingWithdrawal = 0.0,
    this.paymentMethod,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) => _$WalletInfoFromJson(json);
  Map<String, dynamic> toJson() => _$WalletInfoToJson(this);

  @override
  String toString() {
    return 'WalletInfo(balance: $balance, totalEarnings: $totalEarnings, pending: $pendingWithdrawal)';
  }
}