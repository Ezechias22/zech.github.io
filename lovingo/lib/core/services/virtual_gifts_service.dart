// lib/core/services/virtual_gifts_service.dart - SERVICE CADEAUX VIRTUELS COMPLET
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/webrtc_config.dart';

final virtualGiftsServiceProvider = Provider<VirtualGiftsService>((ref) {
  return VirtualGiftsService();
});

class VirtualGiftsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache des cadeaux
  List<GiftItem>? _cachedGifts;
  Map<String, GiftCategory>? _cachedCategories;
  
  // Streams controllers
  final StreamController<List<GiftAnimation>> _animationsController = StreamController.broadcast();
  final StreamController<GiftCombo> _comboController = StreamController.broadcast();
  final StreamController<List<GiftRanking>> _rankingController = StreamController.broadcast();
  
  // Getters publics
  Stream<List<GiftAnimation>> get animationsStream => _animationsController.stream;
  Stream<GiftCombo> get comboStream => _comboController.stream;
  Stream<List<GiftRanking>> get rankingStream => _rankingController.stream;

  // ✅ OBTENIR TOUS LES CADEAUX DISPONIBLES
  Future<List<GiftItem>> getAvailableGifts() async {
    try {
      if (_cachedGifts != null) {
        return _cachedGifts!;
      }
      
      final snapshot = await _firestore
          .collection('gift_items')
          .where('isActive', isEqualTo: true)
          .orderBy('categoryId')
          .orderBy('price')
          .get();
      
      _cachedGifts = snapshot.docs
          .map((doc) => GiftItem.fromFirestore(doc))
          .toList();
      
      WebRTCConfig.logInfo('✅ ${_cachedGifts!.length} cadeaux chargés');
      return _cachedGifts!;
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement cadeaux', e);
      return [];
    }
  }

  // ✅ OBTENIR LES CATÉGORIES DE CADEAUX
  Future<List<GiftCategory>> getGiftCategories() async {
    try {
      if (_cachedCategories != null) {
        return _cachedCategories!.values.toList();
      }
      
      final snapshot = await _firestore
          .collection('gift_categories')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      
      _cachedCategories = {};
      for (final doc in snapshot.docs) {
        final category = GiftCategory.fromFirestore(doc);
        _cachedCategories![category.id] = category;
      }
      
      return _cachedCategories!.values.toList();
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement catégories', e);
      return [];
    }
  }

  // ✅ ENVOYER UN CADEAU VIRTUEL
  Future<bool> sendGift({
    required String giftId,
    required int quantity,
    required String senderId,
    required String receiverId,
    String? liveId,
    String? message,
  }) async {
    try {
      // Vérifier le cadeau
      final gift = await _getGiftById(giftId);
      if (gift == null) {
        WebRTCConfig.logError('Cadeau introuvable: $giftId');
        return false;
      }
      
      // Vérifier le solde utilisateur
      final hasBalance = await _checkUserBalance(senderId, gift.price * quantity);
      if (!hasBalance) {
        WebRTCConfig.logError('Solde insuffisant');
        return false;
      }
      
      // Vérifier les limites
      final canSend = await _checkSendingLimits(senderId, giftId, quantity);
      if (!canSend) {
        WebRTCConfig.logError('Limite d\'envoi dépassée');
        return false;
      }
      
      // Créer la transaction
      final transaction = GiftTransaction(
        id: _generateTransactionId(),
        giftId: giftId,
        quantity: quantity,
        senderId: senderId,
        receiverId: receiverId,
        liveId: liveId,
        message: message,
        totalCost: gift.price * quantity,
        timestamp: DateTime.now(),
        status: GiftTransactionStatus.processing,
      );
      
      // Enregistrer la transaction
      await _firestore.collection('gift_transactions').doc(transaction.id).set(transaction.toMap());
      
      // Déduire du solde expéditeur
      await _updateUserBalance(senderId, -transaction.totalCost);
      
      // Ajouter au solde destinataire (avec commission)
      final receiverAmount = _calculateReceiverAmount(transaction.totalCost);
      await _updateUserBalance(receiverId, receiverAmount);
      
      // Créer l'animation
      final animation = GiftAnimation(
        id: _generateAnimationId(),
        giftId: giftId,
        quantity: quantity,
        senderId: senderId,
        receiverId: receiverId,
        liveId: liveId,
        animationType: gift.animationType,
        duration: gift.animationDuration,
        timestamp: DateTime.now(),
      );
      
      // Envoyer l'animation
      _animationsController.add([animation]);
      
      // Vérifier les combos
      await _checkForCombos(senderId, giftId, quantity, liveId);
      
      // Mettre à jour les statistiques
      await _updateGiftStats(giftId, senderId, receiverId, quantity, liveId);
      
      // Marquer la transaction comme complète
      await _firestore.collection('gift_transactions').doc(transaction.id).update({
        'status': GiftTransactionStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      WebRTCConfig.logInfo('🎁 Cadeau envoyé: ${gift.name} x$quantity ($senderId → $receiverId)');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur envoi cadeau', e);
      return false;
    }
  }

  // ✅ OBTENIR L'HISTORIQUE DES CADEAUX D'UN UTILISATEUR
  Future<List<GiftTransaction>> getUserGiftHistory({
    required String userId,
    bool sent = true,
    bool received = true,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('gift_transactions');
      
      if (sent && received) {
        // Les deux - utiliser un whereIn ou deux requêtes
        query = query.where('senderId', isEqualTo: userId);
      } else if (sent) {
        query = query.where('senderId', isEqualTo: userId);
      } else if (received) {
        query = query.where('receiverId', isEqualTo: userId);
      }
      
      final snapshot = await query
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      final transactions = snapshot.docs
          .map((doc) => GiftTransaction.fromFirestore(doc))
          .toList();
      
      return transactions;
    } catch (e) {
      WebRTCConfig.logError('Erreur historique cadeaux', e);
      return [];
    }
  }

  // ✅ OBTENIR LE CLASSEMENT DES ENVOYEURS DE CADEAUX
  Future<List<GiftRanking>> getGiftRanking({
    String? liveId,
    GiftRankingPeriod period = GiftRankingPeriod.daily,
    int limit = 10,
  }) async {
    try {
      final startDate = _getRankingStartDate(period);
      
      Query query = _firestore.collection('gift_stats');
      
      if (liveId != null) {
        query = query.where('liveId', isEqualTo: liveId);
      }
      
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('totalValue', descending: true)
          .limit(limit);
      
      final snapshot = await query.get();
      
      final rankings = <GiftRanking>[];
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data() as Map<String, dynamic>;
        
        rankings.add(GiftRanking(
          rank: i + 1,
          userId: data['userId'] ?? '',
          totalValue: data['totalValue'] ?? 0,
          totalGifts: data['totalGifts'] ?? 0,
          period: period,
          liveId: liveId,
        ));
      }
      
      _rankingController.add(rankings);
      return rankings;
    } catch (e) {
      WebRTCConfig.logError('Erreur classement cadeaux', e);
      return [];
    }
  }

  // ✅ OBTENIR LES STATISTIQUES DE CADEAUX D'UN LIVE
  Future<LiveGiftStats> getLiveGiftStats(String liveId) async {
    try {
      final snapshot = await _firestore
          .collection('gift_transactions')
          .where('liveId', isEqualTo: liveId)
          .where('status', isEqualTo: GiftTransactionStatus.completed.name)
          .get();
      
      int totalGifts = 0;
      int totalValue = 0;
      final Map<String, int> giftCounts = {};
      final Set<String> uniqueSenders = {};
      
      for (final doc in snapshot.docs) {
        final transaction = GiftTransaction.fromFirestore(doc);
        totalGifts += transaction.quantity;
        totalValue += transaction.totalCost;
        giftCounts[transaction.giftId] = (giftCounts[transaction.giftId] ?? 0) + transaction.quantity;
        uniqueSenders.add(transaction.senderId);
      }
      
      return LiveGiftStats(
        liveId: liveId,
        totalGifts: totalGifts,
        totalValue: totalValue,
        uniqueSenders: uniqueSenders.length,
        topGifts: giftCounts.entries
            .map((e) => TopGiftStat(giftId: e.key, count: e.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count)),
      );
    } catch (e) {
      WebRTCConfig.logError('Erreur stats live cadeaux', e);
      return LiveGiftStats(
        liveId: liveId,
        totalGifts: 0,
        totalValue: 0,
        uniqueSenders: 0,
        topGifts: [],
      );
    }
  }

  // ✅ CRÉER UN COMBO DE CADEAUX
  Future<void> _checkForCombos(String senderId, String giftId, int quantity, String? liveId) async {
    try {
      // Vérifier les envois récents du même cadeau
      final recentTime = DateTime.now().subtract(const Duration(seconds: 10));
      
      final snapshot = await _firestore
          .collection('gift_transactions')
          .where('senderId', isEqualTo: senderId)
          .where('giftId', isEqualTo: giftId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(recentTime))
          .where('status', isEqualTo: GiftTransactionStatus.completed.name)
          .get();
      
      if (snapshot.docs.length >= 5) {
        // Créer un combo
        final totalQuantity = snapshot.docs
            .map((doc) => GiftTransaction.fromFirestore(doc).quantity)
            .reduce((a, b) => a + b);
        
        final combo = GiftCombo(
          id: _generateComboId(),
          senderId: senderId,
          giftId: giftId,
          quantity: totalQuantity,
          comboLevel: _calculateComboLevel(totalQuantity),
          liveId: liveId,
          timestamp: DateTime.now(),
        );
        
        // Enregistrer le combo
        await _firestore.collection('gift_combos').doc(combo.id).set(combo.toMap());
        
        // Notifier
        _comboController.add(combo);
        
        WebRTCConfig.logInfo('🔥 COMBO! ${combo.comboLevel} x${combo.quantity}');
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur vérification combo', e);
    }
  }

  // ✅ MÉTHODES PRIVÉES
  
  Future<GiftItem?> _getGiftById(String giftId) async {
    if (_cachedGifts != null) {
      return _cachedGifts!.firstWhere(
        (gift) => gift.id == giftId,
        orElse: () => null as GiftItem,
      );
    }
    
    final doc = await _firestore.collection('gift_items').doc(giftId).get();
    return doc.exists ? GiftItem.fromFirestore(doc) : null;
  }

  Future<bool> _checkUserBalance(String userId, int requiredAmount) async {
    final doc = await _firestore.collection('user_balances').doc(userId).get();
    final balance = doc.exists ? (doc.data()?['balance'] ?? 0) : 0;
    return balance >= requiredAmount;
  }

  Future<bool> _checkSendingLimits(String userId, String giftId, int quantity) async {
    // Vérifier limite par minute
    final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
    
    final snapshot = await _firestore
        .collection('gift_transactions')
        .where('senderId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(oneMinuteAgo))
        .get();
    
    final recentGifts = snapshot.docs.length;
    return recentGifts < WebRTCConfig.virtualGiftsConfig['maxGiftsPerMinute'];
  }

  Future<void> _updateUserBalance(String userId, int amount) async {
    await _firestore.collection('user_balances').doc(userId).set({
      'balance': FieldValue.increment(amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  int _calculateReceiverAmount(int totalCost) {
    // Prendre 30% de commission, donner 70% au destinataire
    return (totalCost * 0.7).round();
  }

  Future<void> _updateGiftStats(String giftId, String senderId, String receiverId, int quantity, String? liveId) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    // Stats expéditeur
    await _firestore.collection('gift_stats').doc('${senderId}_$dateKey').set({
      'userId': senderId,
      'date': Timestamp.fromDate(today),
      'totalGifts': FieldValue.increment(quantity),
      'totalValue': FieldValue.increment(await _getGiftPrice(giftId) * quantity),
      'liveId': liveId,
    }, SetOptions(merge: true));
    
    // Stats destinataire
    await _firestore.collection('gift_stats').doc('${receiverId}_${dateKey}_received').set({
      'userId': receiverId,
      'date': Timestamp.fromDate(today),
      'totalReceived': FieldValue.increment(quantity),
      'totalReceivedValue': FieldValue.increment(await _getGiftPrice(giftId) * quantity),
      'liveId': liveId,
    }, SetOptions(merge: true));
  }

  Future<int> _getGiftPrice(String giftId) async {
    final gift = await _getGiftById(giftId);
    return gift?.price ?? 0;
  }

  DateTime _getRankingStartDate(GiftRankingPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case GiftRankingPeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case GiftRankingPeriod.weekly:
        return now.subtract(Duration(days: now.weekday - 1));
      case GiftRankingPeriod.monthly:
        return DateTime(now.year, now.month, 1);
      case GiftRankingPeriod.allTime:
        return DateTime(2020, 1, 1);
    }
  }

  int _calculateComboLevel(int quantity) {
    if (quantity >= 100) return 5;
    if (quantity >= 50) return 4;
    if (quantity >= 20) return 3;
    if (quantity >= 10) return 2;
    return 1;
  }

  String _generateTransactionId() => 'txn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  String _generateAnimationId() => 'anim_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  String _generateComboId() => 'combo_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

  // ✅ INITIALISER LES CADEAUX PAR DÉFAUT (POUR TESTS)
  Future<void> initializeDefaultGifts() async {
    try {
      // Vérifier si déjà initialisé
      final existingGifts = await _firestore.collection('gift_items').limit(1).get();
      if (existingGifts.docs.isNotEmpty) {
        WebRTCConfig.logInfo('Cadeaux déjà initialisés');
        return;
      }
      
      // Créer catégories
      final categories = [
        GiftCategory(id: 'basic', name: '🎈 Basique', order: 1, isActive: true),
        GiftCategory(id: 'premium', name: '💎 Premium', order: 2, isActive: true),
        GiftCategory(id: 'luxury', name: '👑 Luxe', order: 3, isActive: true),
        GiftCategory(id: 'special', name: '🌟 Spécial', order: 4, isActive: true),
      ];
      
      for (final category in categories) {
        await _firestore.collection('gift_categories').doc(category.id).set(category.toMap());
      }
      
      // Créer cadeaux
      final gifts = [
        // Basique
        GiftItem(id: 'heart', name: '❤️ Cœur', price: 1, categoryId: 'basic', animationType: GiftAnimationType.bounce, animationDuration: 2000, isActive: true),
        GiftItem(id: 'flower', name: '🌹 Rose', price: 5, categoryId: 'basic', animationType: GiftAnimationType.float, animationDuration: 3000, isActive: true),
        GiftItem(id: 'candy', name: '🍭 Bonbon', price: 10, categoryId: 'basic', animationType: GiftAnimationType.spin, animationDuration: 2500, isActive: true),
        
        // Premium
        GiftItem(id: 'cake', name: '🎂 Gâteau', price: 50, categoryId: 'premium', animationType: GiftAnimationType.explode, animationDuration: 4000, isActive: true),
        GiftItem(id: 'wine', name: '🍾 Champagne', price: 100, categoryId: 'premium', animationType: GiftAnimationType.shower, animationDuration: 5000, isActive: true),
        GiftItem(id: 'diamond', name: '💎 Diamant', price: 200, categoryId: 'premium', animationType: GiftAnimationType.sparkle, animationDuration: 3500, isActive: true),
        
        // Luxe
        GiftItem(id: 'crown', name: '👑 Couronne', price: 500, categoryId: 'luxury', animationType: GiftAnimationType.royal, animationDuration: 6000, isActive: true),
        GiftItem(id: 'yacht', name: '🛥️ Yacht', price: 1000, categoryId: 'luxury', animationType: GiftAnimationType.luxury, animationDuration: 8000, isActive: true),
        GiftItem(id: 'rocket', name: '🚀 Fusée', price: 2000, categoryId: 'luxury', animationType: GiftAnimationType.blast, animationDuration: 10000, isActive: true),
        
        // Spécial
        GiftItem(id: 'unicorn', name: '🦄 Licorne', price: 888, categoryId: 'special', animationType: GiftAnimationType.magical, animationDuration: 7000, isActive: true),
        GiftItem(id: 'rainbow', name: '🌈 Arc-en-ciel', price: 1888, categoryId: 'special', animationType: GiftAnimationType.rainbow, animationDuration: 12000, isActive: true),
      ];
      
      for (final gift in gifts) {
        await _firestore.collection('gift_items').doc(gift.id).set(gift.toMap());
      }
      
      WebRTCConfig.logInfo('✅ ${gifts.length} cadeaux par défaut créés');
    } catch (e) {
      WebRTCConfig.logError('Erreur initialisation cadeaux', e);
    }
  }

  // ✅ NETTOYAGE
  void dispose() {
    _animationsController.close();
    _comboController.close();
    _rankingController.close();
  }
}

// ✅ MODÈLES DE DONNÉES CADEAUX

class GiftItem {
  final String id;
  final String name;
  final int price;
  final String categoryId;
  final GiftAnimationType animationType;
  final int animationDuration;
  final bool isActive;
  final String? imageUrl;
  final String? description;

  GiftItem({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.animationType,
    required this.animationDuration,
    required this.isActive,
    this.imageUrl,
    this.description,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'categoryId': categoryId,
    'animationType': animationType.name,
    'animationDuration': animationDuration,
    'isActive': isActive,
    'imageUrl': imageUrl,
    'description': description,
  };

  factory GiftItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GiftItem(
      id: doc.id,
      name: data['name'] ?? '',
      price: data['price'] ?? 0,
      categoryId: data['categoryId'] ?? '',
      animationType: GiftAnimationType.values.firstWhere(
        (e) => e.name == data['animationType'],
        orElse: () => GiftAnimationType.bounce,
      ),
      animationDuration: data['animationDuration'] ?? 2000,
      isActive: data['isActive'] ?? true,
      imageUrl: data['imageUrl'],
      description: data['description'],
    );
  }
}

class GiftCategory {
  final String id;
  final String name;
  final int order;
  final bool isActive;
  final String? iconUrl;

  GiftCategory({
    required this.id,
    required this.name,
    required this.order,
    required this.isActive,
    this.iconUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'order': order,
    'isActive': isActive,
    'iconUrl': iconUrl,
  };

  factory GiftCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GiftCategory(
      id: doc.id,
      name: data['name'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
      iconUrl: data['iconUrl'],
    );
  }
}

class GiftTransaction {
  final String id;
  final String giftId;
  final int quantity;
  final String senderId;
  final String receiverId;
  final String? liveId;
  final String? message;
  final int totalCost;
  final DateTime timestamp;
  final GiftTransactionStatus status;

  GiftTransaction({
    required this.id,
    required this.giftId,
    required this.quantity,
    required this.senderId,
    required this.receiverId,
    this.liveId,
    this.message,
    required this.totalCost,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'giftId': giftId,
    'quantity': quantity,
    'senderId': senderId,
    'receiverId': receiverId,
    'liveId': liveId,
    'message': message,
    'totalCost': totalCost,
    'timestamp': Timestamp.fromDate(timestamp),
    'status': status.name,
  };

  factory GiftTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GiftTransaction(
      id: doc.id,
      giftId: data['giftId'] ?? '',
      quantity: data['quantity'] ?? 1,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      liveId: data['liveId'],
      message: data['message'],
      totalCost: data['totalCost'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: GiftTransactionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => GiftTransactionStatus.pending,
      ),
    );
  }
}

class GiftAnimation {
  final String id;
  final String giftId;
  final int quantity;
  final String senderId;
  final String receiverId;
  final String? liveId;
  final GiftAnimationType animationType;
  final int duration;
  final DateTime timestamp;

  GiftAnimation({
    required this.id,
    required this.giftId,
    required this.quantity,
    required this.senderId,
    required this.receiverId,
    this.liveId,
    required this.animationType,
    required this.duration,
    required this.timestamp,
  });
}

class GiftCombo {
  final String id;
  final String senderId;
  final String giftId;
  final int quantity;
  final int comboLevel;
  final String? liveId;
  final DateTime timestamp;

  GiftCombo({
    required this.id,
    required this.senderId,
    required this.giftId,
    required this.quantity,
    required this.comboLevel,
    this.liveId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderId': senderId,
    'giftId': giftId,
    'quantity': quantity,
    'comboLevel': comboLevel,
    'liveId': liveId,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}

class GiftRanking {
  final int rank;
  final String userId;
  final int totalValue;
  final int totalGifts;
  final GiftRankingPeriod period;
  final String? liveId;

  GiftRanking({
    required this.rank,
    required this.userId,
    required this.totalValue,
    required this.totalGifts,
    required this.period,
    this.liveId,
  });
}

class LiveGiftStats {
  final String liveId;
  final int totalGifts;
  final int totalValue;
  final int uniqueSenders;
  final List<TopGiftStat> topGifts;

  LiveGiftStats({
    required this.liveId,
    required this.totalGifts,
    required this.totalValue,
    required this.uniqueSenders,
    required this.topGifts,
  });
}

class TopGiftStat {
  final String giftId;
  final int count;

  TopGiftStat({
    required this.giftId,
    required this.count,
  });
}

// ✅ ENUMS

enum GiftAnimationType {
  bounce,
  float,
  spin,
  explode,
  shower,
  sparkle,
  royal,
  luxury,
  blast,
  magical,
  rainbow,
}

enum GiftTransactionStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

enum GiftRankingPeriod {
  daily,
  weekly,
  monthly,
  allTime,
}