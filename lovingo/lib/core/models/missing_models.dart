// lib/core/models/missing_models.dart - VERSION ULTRA-OPTIMISÉE
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================
// 💰 WALLET SERVICE (Service principal)
// ============================================
class WalletService {
  static final _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();
  
  // ✅ Obtenir l'utilisateur actuel
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  
  /// Récupérer le solde d'un utilisateur
  Future<int> getUserBalance(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final wallet = data['wallet'] as Map<String, dynamic>?;
        return (wallet?['balance'] ?? wallet?['coins'] ?? 0).toInt();
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Erreur getUserBalance: $e');
      return 0;
    }
  }
  
  /// Déduire du solde avec transaction sécurisée
  Future<bool> deductBalance(String userId, int amount) async {
    if (amount <= 0) return false;
    
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      
      return await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        
        if (!snapshot.exists) return false;
        
        final data = snapshot.data() as Map<String, dynamic>;
        final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
        final currentBalance = (wallet['balance'] ?? wallet['coins'] ?? 0).toInt();
        
        if (currentBalance < amount) return false;
        
        // Mise à jour du solde et ajout d'une transaction
        transaction.update(userRef, {
          'wallet.balance': currentBalance - amount,
          'wallet.totalSpent': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Enregistrer la transaction
        final transactionRef = FirebaseFirestore.instance
            .collection('transactions')
            .doc();
            
        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'userId': userId,
          'type': 'deduction',
          'amount': -amount,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Déduction de solde',
        });
        
        return true;
      });
    } catch (e) {
      debugPrint('❌ Erreur deductBalance: $e');
      return false;
    }
  }
  
  /// Ajouter au solde
  Future<void> addBalance(String userId, int amount) async {
    if (amount <= 0) return;
    
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
          
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(userRef, {
          'wallet.balance': FieldValue.increment(amount),
          'wallet.totalEarnings': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Enregistrer la transaction
        final transactionRef = FirebaseFirestore.instance
            .collection('transactions')
            .doc();
            
        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'userId': userId,
          'type': 'addition',
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Ajout de solde',
        });
      });
    } catch (e) {
      debugPrint('❌ Erreur addBalance: $e');
    }
  }

  /// Vérifier si l'utilisateur actuel a assez de solde
  Future<bool> hasBalance(int amount) async {
    if (_currentUserId == null) return false;
    final balance = await getUserBalance(_currentUserId!);
    return balance >= amount;
  }

  /// Déduire des coins pour l'utilisateur actuel
  Future<bool> deductCoins(int amount) async {
    if (_currentUserId == null) return false;
    return await deductBalance(_currentUserId!, amount);
  }

  /// Ajouter des coins pour l'utilisateur actuel
  Future<void> addCoins(int amount) async {
    if (_currentUserId == null) return;
    await addBalance(_currentUserId!, amount);
  }
  
  /// Obtenir l'historique des transactions
  Future<List<TransactionHistory>> getTransactionHistory(String userId, {int limit = 20}) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
          
      return query.docs.map((doc) => TransactionHistory.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('❌ Erreur getTransactionHistory: $e');
      return [];
    }
  }
}

// ============================================
// 📱 PROVIDER WALLET
// ============================================
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

// Provider pour le solde de l'utilisateur actuel
final currentUserBalanceProvider = StreamProvider<int>((ref) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return Stream.value(0);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserId)
      .snapshots()
      .map((doc) {
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
      return (wallet['balance'] ?? wallet['coins'] ?? 0).toInt();
    }
    return 0;
  });
});

// ============================================
// 📊 MODÈLES ADMIN
// ============================================
class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int totalRevenue;
  final int totalCalls;
  final List<AdminActivity> recentActivities;

  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalRevenue,
    required this.totalCalls,
    required this.recentActivities,
  });

  factory AdminStats.empty() {
    return const AdminStats(
      totalUsers: 0,
      activeUsers: 0,
      totalRevenue: 0,
      totalCalls: 0,
      recentActivities: [],
    );
  }
  
  factory AdminStats.fromMap(Map<String, dynamic> map) {
    return AdminStats(
      totalUsers: map['totalUsers'] ?? 0,
      activeUsers: map['activeUsers'] ?? 0,
      totalRevenue: map['totalRevenue'] ?? 0,
      totalCalls: map['totalCalls'] ?? 0,
      recentActivities: (map['recentActivities'] as List?)
          ?.map((e) => AdminActivity.fromMap(e))
          .toList() ?? [],
    );
  }
}

class AdminActivity {
  final String id;
  final ActivityType type;
  final String description;
  final DateTime timestamp;
  final String? userId;

  const AdminActivity({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.userId,
  });

  String get title {
    switch (type) {
      case ActivityType.userRegistration:
        return 'Nouvel utilisateur';
      case ActivityType.purchase:
        return 'Achat effectué';
      case ActivityType.match:
        return 'Nouveau match';
      case ActivityType.callMade:
        return 'Appel passé';
      case ActivityType.reportSubmitted:
        return 'Signalement reçu';
      case ActivityType.report:
        return 'Rapport généré';
      case ActivityType.gift:
        return 'Cadeau envoyé';
    }
  }
  
  IconData get icon {
    switch (type) {
      case ActivityType.userRegistration:
        return Icons.person_add;
      case ActivityType.purchase:
        return Icons.shopping_cart;
      case ActivityType.match:
        return Icons.favorite;
      case ActivityType.callMade:
        return Icons.call;
      case ActivityType.reportSubmitted:
        return Icons.report;
      case ActivityType.report:
        return Icons.analytics;
      case ActivityType.gift:
        return Icons.card_giftcard;
    }
  }
  
  Color get color {
    switch (type) {
      case ActivityType.userRegistration:
        return Colors.blue;
      case ActivityType.purchase:
        return Colors.green;
      case ActivityType.match:
        return Colors.pink;
      case ActivityType.callMade:
        return Colors.orange;
      case ActivityType.reportSubmitted:
        return Colors.red;
      case ActivityType.report:
        return Colors.purple;
      case ActivityType.gift:
        return Colors.amber;
    }
  }
  
  factory AdminActivity.fromMap(Map<String, dynamic> map) {
    return AdminActivity(
      id: map['id'] ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ActivityType.userRegistration,
      ),
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: map['userId'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
    };
  }
}

enum ActivityType {
  userRegistration,
  purchase,
  match,
  callMade,
  reportSubmitted,
  report,
  gift,
}

class ChartData {
  final String category;
  final double value;
  final Color? color;

  const ChartData({
    required this.category,
    required this.value,
    this.color,
  });
}

enum ChartType { line, bar, pie }

// ============================================
// 📞 MODÈLES D'APPELS ÉTENDUS
// ============================================
class CallHistoryItem {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final DateTime timestamp;
  final Duration duration;
  final bool isVideoCall;
  final bool isIncoming;
  final bool isMissed;
  final int? cost;

  const CallHistoryItem({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.timestamp,
    required this.duration,
    required this.isVideoCall,
    required this.isIncoming,
    required this.isMissed,
    this.cost,
  });
  
  String get callTypeText {
    if (isMissed) return 'Manqué';
    if (isIncoming) return 'Entrant';
    return 'Sortant';
  }
  
  IconData get callIcon {
    if (isMissed) return Icons.call_missed;
    if (isVideoCall) return Icons.videocam;
    return Icons.call;
  }
  
  Color get callColor {
    if (isMissed) return Colors.red;
    if (isIncoming) return Colors.green;
    return Colors.blue;
  }
  
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  factory CallHistoryItem.fromMap(Map<String, dynamic> map) {
    return CallHistoryItem(
      id: map['id'] ?? '',
      otherUserId: map['otherUserId'] ?? '',
      otherUserName: map['otherUserName'] ?? '',
      otherUserPhoto: map['otherUserPhoto'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: Duration(seconds: map['duration'] ?? 0),
      isVideoCall: map['isVideoCall'] ?? false,
      isIncoming: map['isIncoming'] ?? false,
      isMissed: map['isMissed'] ?? false,
      cost: map['cost'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserPhoto': otherUserPhoto,
      'timestamp': Timestamp.fromDate(timestamp),
      'duration': duration.inSeconds,
      'isVideoCall': isVideoCall,
      'isIncoming': isIncoming,
      'isMissed': isMissed,
      'cost': cost,
    };
  }
}

class CallStatistics {
  final int totalCalls;
  final int totalDuration;
  final int avgCallDuration;
  final Map<String, int> callsByType;
  final int totalCost;

  const CallStatistics({
    required this.totalCalls,
    required this.totalDuration,
    required this.avgCallDuration,
    required this.callsByType,
    this.totalCost = 0,
  });
  
  String get formattedTotalDuration {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }
  
  factory CallStatistics.empty() {
    return const CallStatistics(
      totalCalls: 0,
      totalDuration: 0,
      avgCallDuration: 0,
      callsByType: {},
    );
  }
}

// ============================================
// 🎁 MODÈLES DE CADEAUX ÉTENDUS
// ============================================
class VirtualGift {
  final String id;
  final String giftId;
  final int quantity;
  final String senderId;
  final String senderName;
  final String? targetUserId;
  final DateTime timestamp;
  final String liveId;
  final int value;

  const VirtualGift({
    required this.id,
    required this.giftId,
    required this.quantity,
    required this.senderId,
    required this.senderName,
    this.targetUserId,
    required this.timestamp,
    required this.liveId,
    this.value = 0,
  });

  int get totalValue => value * quantity;

  Map<String, dynamic> toMap() => {
    'id': id,
    'giftId': giftId,
    'quantity': quantity,
    'senderId': senderId,
    'senderName': senderName,
    'targetUserId': targetUserId,
    'timestamp': Timestamp.fromDate(timestamp),
    'liveId': liveId,
    'value': value,
  };
  
  factory VirtualGift.fromMap(Map<String, dynamic> map) {
    return VirtualGift(
      id: map['id'] ?? '',
      giftId: map['giftId'] ?? '',
      quantity: map['quantity'] ?? 1,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      targetUserId: map['targetUserId'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      liveId: map['liveId'] ?? '',
      value: map['value'] ?? 0,
    );
  }
}

class GiftCategorySimple {
  final String id;
  final String name;
  final String? icon;

  const GiftCategorySimple({
    required this.id,
    required this.name,
    this.icon,
  });
  
  factory GiftCategorySimple.fromMap(Map<String, dynamic> map) {
    return GiftCategorySimple(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'],
    );
  }
}

// ============================================
// 💳 MODÈLES WALLET ÉTENDUS
// ============================================
class TransactionHistory {
  final String id;
  final String type;
  final int amount;
  final DateTime timestamp;
  final String? description;
  final String? relatedId;

  const TransactionHistory({
    required this.id,
    required this.type,
    required this.amount,
    required this.timestamp,
    this.description,
    this.relatedId,
  });
  
  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
  
  String get formattedAmount {
    final prefix = isCredit ? '+' : '';
    return '$prefix$amount coins';
  }
  
  IconData get icon {
    switch (type.toLowerCase()) {
      case 'addition':
      case 'purchase':
        return Icons.add_circle;
      case 'deduction':
      case 'gift':
        return Icons.remove_circle;
      case 'call':
        return Icons.call;
      case 'bonus':
        return Icons.star;
      default:
        return Icons.monetization_on;
    }
  }
  
  Color get color {
    return isCredit ? Colors.green : Colors.red;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'amount': amount,
    'timestamp': Timestamp.fromDate(timestamp),
    'description': description,
    'relatedId': relatedId,
  };

  factory TransactionHistory.fromMap(Map<String, dynamic> map) {
    return TransactionHistory(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      amount: map['amount'] as int? ?? 0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] as String?,
      relatedId: map['relatedId'] as String?,
    );
  }
}