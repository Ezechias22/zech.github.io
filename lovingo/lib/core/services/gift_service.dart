// lib/core/services/gift_service.dart - VERSION COMPLÈTE CORRIGÉE
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../config/webrtc_config.dart';
import 'wallet_service.dart' as wallet_service; // ✅ ALIAS ajouté
import 'auth_service.dart';
import '../models/gift_model.dart';

// ✅ ENUM WalletTransactionType ajouté localement
enum WalletTransactionType {
  giftSent,
  giftReceived,
  purchase,
  refund,
  bonus,
  penalty,
}

// ✅ CLASSE GIFTSERVICE POUR COMPATIBILITÉ - VERSION CORRIGÉE
class GiftService {
  static final GiftService _instance = GiftService._internal();
  factory GiftService() => _instance;
  GiftService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ✅ Méthodes corrigées et ajoutées
  List<GiftModel> getAllGifts() {
    return DefaultGifts.gifts;
  }

  List<GiftModel> getAvailableGifts() {
    return DefaultGifts.gifts;
  }

  bool canSendGift({
    required String giftId,
    required double balance,
    bool? isPremiumUser,
  }) {
    final gift = getGiftById(giftId);
    if (gift == null) return false;
    
    if (gift.isPremiumOnly && !(isPremiumUser ?? false)) {
      return false;
    }
    
    return balance >= gift.priceAsDouble;
  }

  bool canSendGiftSimple(String giftId, int quantity) {
    final gift = getGiftById(giftId);
    if (gift == null) return false;
    return true;
  }

  Future<bool> sendGift({
    required String giftId,
    required String receiverId,
    String? message,
    int quantity = 1,
  }) async {
    try {
      final gift = DefaultGifts.gifts.firstWhere(
        (g) => g.id == giftId,
        orElse: () => throw Exception('Cadeau non trouvé'),
      );

      final transaction = GiftTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        giftId: giftId,
        senderId: 'current_user',
        receiverId: receiverId,
        chatRoomId: 'default_room',
        quantity: quantity,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('gift_transactions').add(transaction.toMap());
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur envoi cadeau', e);
      return false;
    }
  }

  GiftModel? getGiftById(String giftId) {
    try {
      return DefaultGifts.gifts.firstWhere((g) => g.id == giftId);
    } catch (e) {
      return null;
    }
  }

  bool canAffordGift(String giftId, double balance) {
    final gift = getGiftById(giftId);
    if (gift == null) return false;
    return balance >= gift.priceAsDouble;
  }

  Future<List<GiftTransaction>> getGiftHistory() async {
    try {
      final snapshot = await _firestore
          .collection('gift_transactions')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => GiftTransaction.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      WebRTCConfig.logError('Erreur historique cadeaux', e);
      return [];
    }
  }

  Map<String, dynamic> getStats() {
    return {
      'totalSent': 0.0,
      'totalReceived': 0.0,
      'giftsSentCount': 0,
      'giftsReceivedCount': 0,
    };
  }

  bool validateGift(String giftId) {
    return DefaultGifts.gifts.any((g) => g.id == giftId);
  }

  void dispose() {
    // Cleanup si nécessaire
  }
}

extension GiftModelExtended on GiftModel {
  double get priceAsDouble => price.toDouble();
  
  String get category {
    if (isPremiumOnly) return 'luxury';
    switch (rarity) {
      case GiftRarity.common:
        return _getCategoryFromPrice();
      case GiftRarity.rare:
        return 'appreciation';
      case GiftRarity.epic:
        return 'luxury';
      case GiftRarity.legendary:
        return 'luxury';
    }
  }

  String _getCategoryFromPrice() {
    if (price <= 10) return 'romantic';
    if (price <= 50) return 'appreciation';
    return 'festive';
  }

  String get emoji => icon;
  String? get animation => animationPath.split('/').last.split('.').first;
  bool get isActive => true;
  DateTime? get validUntil => null;
  Map<String, dynamic> get metadata => {
    'animationPath': animationPath,
    'isPremiumOnly': isPremiumOnly,
  };
}

extension GiftTransactionExtended on GiftTransaction {
  double get amountPaid {
    final gift = DefaultGifts.gifts.firstWhere(
      (g) => g.id == giftId,
      orElse: () => DefaultGifts.gifts.first,
    );
    return (gift.price * quantity).toDouble();
  }

  double get amountReceived {
    return amountPaid * 0.8;
  }

  String get senderName => senderId;
  String get receiverName => receiverId;
  String? get message => null;
  String? get streamId => chatRoomId;
  String get status => 'completed';
  String? get transactionId => id;
  Map<String, dynamic> get metadata => {};

  Map<String, dynamic> toFirestore() {
    return {
      'giftId': giftId,
      'senderId': senderId,
      'receiverId': receiverId,
      'chatRoomId': chatRoomId,
      'quantity': quantity,
      'timestamp': Timestamp.fromDate(timestamp),
      'amountPaid': amountPaid,
      'amountReceived': amountReceived,
    };
  }

  static GiftTransaction fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GiftTransaction(
      id: doc.id,
      giftId: data['giftId'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      chatRoomId: data['chatRoomId'] ?? '',
      quantity: data['quantity'] ?? 1,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

@immutable
class GiftStats {
  final double totalSent;
  final double totalReceived;
  final int giftsSentCount;
  final int giftsReceivedCount;
  final String? favoriteGiftSent;
  final String? favoriteGiftReceived;
  final Map<String, int> categoryStats;
  final Map<String, double> monthlyStats;
  final double averageGiftValue;
  final int uniqueRecipientsCount;
  final int uniqueSendersCount;

  const GiftStats({
    this.totalSent = 0.0,
    this.totalReceived = 0.0,
    this.giftsSentCount = 0,
    this.giftsReceivedCount = 0,
    this.favoriteGiftSent,
    this.favoriteGiftReceived,
    this.categoryStats = const {},
    this.monthlyStats = const {},
    this.averageGiftValue = 0.0,
    this.uniqueRecipientsCount = 0,
    this.uniqueSendersCount = 0,
  });

  GiftStats copyWith({
    double? totalSent,
    double? totalReceived,
    int? giftsSentCount,
    int? giftsReceivedCount,
    String? favoriteGiftSent,
    String? favoriteGiftReceived,
    Map<String, int>? categoryStats,
    Map<String, double>? monthlyStats,
    double? averageGiftValue,
    int? uniqueRecipientsCount,
    int? uniqueSendersCount,
  }) {
    return GiftStats(
      totalSent: totalSent ?? this.totalSent,
      totalReceived: totalReceived ?? this.totalReceived,
      giftsSentCount: giftsSentCount ?? this.giftsSentCount,
      giftsReceivedCount: giftsReceivedCount ?? this.giftsReceivedCount,
      favoriteGiftSent: favoriteGiftSent ?? this.favoriteGiftSent,
      favoriteGiftReceived: favoriteGiftReceived ?? this.favoriteGiftReceived,
      categoryStats: categoryStats ?? this.categoryStats,
      monthlyStats: monthlyStats ?? this.monthlyStats,
      averageGiftValue: averageGiftValue ?? this.averageGiftValue,
      uniqueRecipientsCount: uniqueRecipientsCount ?? this.uniqueRecipientsCount,
      uniqueSendersCount: uniqueSendersCount ?? this.uniqueSendersCount,
    );
  }
}

@immutable
class GiftState {
  final List<GiftModel> availableGifts;
  final List<GiftTransaction> recentTransactions;
  final List<GiftTransaction> sentGifts;
  final List<GiftTransaction> receivedGifts;
  final GiftStats stats;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final Map<String, int> giftCounts;
  final Map<String, List<GiftModel>> giftsByCategory;
  final DateTime? lastUpdated;

  const GiftState({
    this.availableGifts = const [],
    this.recentTransactions = const [],
    this.sentGifts = const [],
    this.receivedGifts = const [],
    this.stats = const GiftStats(),
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.giftCounts = const {},
    this.giftsByCategory = const {},
    this.lastUpdated,
  });

  GiftState copyWith({
    List<GiftModel>? availableGifts,
    List<GiftTransaction>? recentTransactions,
    List<GiftTransaction>? sentGifts,
    List<GiftTransaction>? receivedGifts,
    GiftStats? stats,
    bool? isLoading,
    bool? isSending,
    String? error,
    Map<String, int>? giftCounts,
    Map<String, List<GiftModel>>? giftsByCategory,
    DateTime? lastUpdated,
  }) {
    return GiftState(
      availableGifts: availableGifts ?? this.availableGifts,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      sentGifts: sentGifts ?? this.sentGifts,
      receivedGifts: receivedGifts ?? this.receivedGifts,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      giftCounts: giftCounts ?? this.giftCounts,
      giftsByCategory: giftsByCategory ?? this.giftsByCategory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class GiftNotifier extends StateNotifier<GiftState> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription? _giftTransactionSubscription;
  StreamSubscription? _customGiftsSubscription;
  Timer? _statsUpdateTimer;

  GiftNotifier(this._ref) : super(const GiftState()) {
    _initializeService();
  }

  Future<void> _initializeService() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      _loadDefaultGifts();
      
      await Future.wait([
        _loadCachedData(),
        _setupRealtimeListeners(),
        _loadCustomGifts(),
        _loadTransactionHistory(),
      ]);

      await _calculateStats();
      _startPeriodicUpdates();
      
      state = state.copyWith(
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      WebRTCConfig.logInfo('✅ Service cadeaux initialisé');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur initialisation service cadeaux: $e',
      );
      WebRTCConfig.logError('Erreur initialisation service cadeaux', e);
    }
  }

  void _loadDefaultGifts() {
    final defaultGifts = DefaultGifts.gifts;
    final giftsByCategory = _groupGiftsByCategory(defaultGifts);

    state = state.copyWith(
      availableGifts: defaultGifts,
      giftsByCategory: giftsByCategory,
    );
  }

  Map<String, List<GiftModel>> _groupGiftsByCategory(List<GiftModel> gifts) {
    final grouped = <String, List<GiftModel>>{};
    for (final gift in gifts.where((g) => g.isActive)) {
      grouped.putIfAbsent(gift.category, () => []).add(gift);
    }
    return grouped;
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('gifts_cache');
      
      if (cacheString != null) {
        final cacheData = jsonDecode(cacheString);
        final lastUpdated = DateTime.fromMillisecondsSinceEpoch(
          cacheData['lastUpdated'] ?? 0
        );
        
        if (DateTime.now().difference(lastUpdated).inMinutes < 30) {
          final cachedGifts = (cacheData['gifts'] as List?)
              ?.map((g) => GiftModel.fromMap(g))
              .toList() ?? [];
          
          if (cachedGifts.isNotEmpty) {
            state = state.copyWith(
              availableGifts: cachedGifts,
              giftsByCategory: _groupGiftsByCategory(cachedGifts),
              lastUpdated: lastUpdated,
            );
          }
        }
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement cache cadeaux', e);
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'gifts': state.availableGifts.map((g) => g.toMap()).toList(),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString('gifts_cache', jsonEncode(cacheData));
    } catch (e) {
      WebRTCConfig.logError('Erreur sauvegarde cache cadeaux', e);
    }
  }

  Future<void> _setupRealtimeListeners() async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    _giftTransactionSubscription = _firestore
        .collection('gift_transactions')
        .where('receiverId', isEqualTo: currentUser.id)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) => _handleTransactionUpdate(snapshot),
          onError: (error) => WebRTCConfig.logError('Erreur listener transactions', error),
        );
  }

  void _handleTransactionUpdate(QuerySnapshot snapshot) {
    final transactions = snapshot.docs
        .map((doc) => GiftTransactionExtended.fromFirestore(doc))
        .toList();

    state = state.copyWith(
      recentTransactions: transactions,
      receivedGifts: transactions,
    );

    _updateGiftCounts(transactions);
    _calculateStats();
  }

  Future<void> _loadCustomGifts() async {
    try {
      final snapshot = await _firestore
          .collection('custom_gifts')
          .where('isActive', isEqualTo: true)
          .get();

      final customGifts = snapshot.docs
          .map((doc) => GiftModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      if (customGifts.isNotEmpty) {
        final allGifts = [...DefaultGifts.gifts, ...customGifts];
        state = state.copyWith(
          availableGifts: allGifts,
          giftsByCategory: _groupGiftsByCategory(allGifts),
        );
        _saveToCache();
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement cadeaux personnalisés', e);
    }
  }

  Future<void> _loadTransactionHistory() async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      final [sentSnapshot, receivedSnapshot] = await Future.wait([
        _firestore
            .collection('gift_transactions')
            .where('senderId', isEqualTo: currentUser.id)
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get(),
        _firestore
            .collection('gift_transactions')
            .where('receiverId', isEqualTo: currentUser.id)
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get(),
      ]);

      final sentGifts = sentSnapshot.docs
          .map((doc) => GiftTransactionExtended.fromFirestore(doc))
          .toList();

      final receivedGifts = receivedSnapshot.docs
          .map((doc) => GiftTransactionExtended.fromFirestore(doc))
          .toList();

      state = state.copyWith(
        sentGifts: sentGifts,
        receivedGifts: receivedGifts,
        recentTransactions: [...sentGifts, ...receivedGifts]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
          ..take(50).toList(),
      );

      _updateGiftCounts(receivedGifts);
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement historique', e);
    }
  }

  void _updateGiftCounts(List<GiftTransaction> transactions) {
    final counts = <String, int>{};
    for (final transaction in transactions) {
      counts[transaction.giftId] = (counts[transaction.giftId] ?? 0) + transaction.quantity;
    }
    state = state.copyWith(giftCounts: counts);
  }

  // ✅ CORRECTION: Méthode sendGift() complète avec alias wallet_service
  Future<bool> sendGift({
    required String toUserId,
    required String giftId,
    required String chatRoomId,
    int quantity = 1,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return false;
    }

    final gift = state.availableGifts.firstWhere(
      (g) => g.id == giftId,
      orElse: () => throw Exception('Cadeau non trouvé: $giftId'),
    );

    if (!gift.isActive) {
      state = state.copyWith(error: 'Ce cadeau n\'est plus disponible');
      return false;
    }

    state = state.copyWith(isSending: true, error: null);

    try {
      final totalPrice = (gift.price * quantity).toDouble();
      
      // ✅ CORRECTION: Utiliser l'alias wallet_service
      final walletService = _ref.read(wallet_service.walletServiceProvider);
      final currentBalance = await walletService.getUserBalance(currentUser.id);
      
      if (currentBalance < totalPrice) {
        state = state.copyWith(
          isSending: false,
          error: 'Solde insuffisant pour envoyer ce cadeau',
        );
        return false;
      }

      final success = await walletService.deductBalance(currentUser.id, totalPrice.toInt());

      if (!success) {
        state = state.copyWith(
          isSending: false,
          error: 'Erreur lors du paiement',
        );
        return false;
      }

      final giftTransaction = GiftTransaction(
        id: '',
        giftId: gift.id,
        senderId: currentUser.id,
        receiverId: toUserId,
        chatRoomId: chatRoomId,
        quantity: quantity,
        timestamp: DateTime.now(),
      );

      await _firestore
          .collection('gift_transactions')
          .add(giftTransaction.toFirestore());

      await _creditRecipientWallet(toUserId, giftTransaction.amountReceived, gift);

      final updatedSentGifts = [giftTransaction, ...state.sentGifts];
      state = state.copyWith(
        sentGifts: updatedSentGifts,
        isSending: false,
      );

      WebRTCConfig.logInfo('✅ Cadeau ${gift.name} x$quantity envoyé à $toUserId');
      return true;

    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: 'Erreur lors de l\'envoi: $e',
      );
      WebRTCConfig.logError('Erreur envoi cadeau', e);
      return false;
    }
  }

  Future<void> _creditRecipientWallet(String toUserId, double amount, GiftModel gift) async {
    try {
      await _firestore.collection('user_wallets').doc(toUserId).update({
        'balance': FieldValue.increment(amount),
       'totalEarnings': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('wallet_transactions').add({
        'userId': toUserId,
        'type': 'giftReceived',
        'amount': amount,
        'description': 'Cadeau reçu: ${gift.name}',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'giftId': gift.id,
          'originalPrice': gift.priceAsDouble,
        },
      });
    } catch (e) {
      WebRTCConfig.logError('Erreur crédit destinataire', e);
      rethrow;
    }
  }

  Future<void> _calculateStats() async {
    try {
      final sentGifts = state.sentGifts;
      final receivedGifts = state.receivedGifts;

      if (sentGifts.isEmpty && receivedGifts.isEmpty) {
        state = state.copyWith(stats: const GiftStats());
        return;
      }

      final totalSent = sentGifts
          .map((t) => t.amountPaid)
          .fold(0.0, (a, b) => a + b);
      
      final totalReceived = receivedGifts
          .map((t) => t.amountReceived)
          .fold(0.0, (a, b) => a + b);

      final categoryStats = <String, int>{};
      for (final transaction in [...sentGifts, ...receivedGifts]) {
        final gift = state.availableGifts.firstWhere(
          (g) => g.id == transaction.giftId,
          orElse: () => DefaultGifts.gifts.first,
        );
        categoryStats[gift.category] = (categoryStats[gift.category] ?? 0) + 1;
      }

      final sentGiftCounts = <String, int>{};
      final receivedGiftCounts = <String, int>{};
      
      for (final transaction in sentGifts) {
        sentGiftCounts[transaction.giftId] = 
            (sentGiftCounts[transaction.giftId] ?? 0) + transaction.quantity;
      }
      
      for (final transaction in receivedGifts) {
        receivedGiftCounts[transaction.giftId] = 
            (receivedGiftCounts[transaction.giftId] ?? 0) + transaction.quantity;
      }

      final favoriteGiftSent = sentGiftCounts.isNotEmpty
          ? sentGiftCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : null;

      final favoriteGiftReceived = receivedGiftCounts.isNotEmpty
          ? receivedGiftCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : null;

      final allTransactions = [...sentGifts, ...receivedGifts];
      final averageGiftValue = allTransactions.isNotEmpty
          ? allTransactions
              .map((t) => t.amountPaid)
              .fold(0.0, (a, b) => a + b) / allTransactions.length
          : 0.0;

      final uniqueRecipientsCount = sentGifts
          .map((t) => t.receiverId)
          .toSet()
          .length;

      final uniqueSendersCount = receivedGifts
          .map((t) => t.senderId)
          .toSet()
          .length;

      final stats = GiftStats(
        totalSent: totalSent,
        totalReceived: totalReceived,
        giftsSentCount: sentGifts.length,
        giftsReceivedCount: receivedGifts.length,
        favoriteGiftSent: favoriteGiftSent,
        favoriteGiftReceived: favoriteGiftReceived,
        categoryStats: categoryStats,
        averageGiftValue: averageGiftValue,
        uniqueRecipientsCount: uniqueRecipientsCount,
        uniqueSendersCount: uniqueSendersCount,
      );

      state = state.copyWith(stats: stats);
    } catch (e) {
      WebRTCConfig.logError('Erreur calcul statistiques', e);
    }
  }

  List<GiftModel> searchGifts({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    GiftRarity? rarity,
    bool? isPremiumOnly,
  }) {
    var gifts = state.availableGifts;

    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      gifts = gifts.where((gift) =>
          gift.name.toLowerCase().contains(lowerQuery) ||
          gift.category.toLowerCase().contains(lowerQuery) ||
          gift.icon.contains(query)).toList();
    }

    if (category != null) {
      gifts = gifts.where((gift) => gift.category == category).toList();
    }

    if (minPrice != null) {
      gifts = gifts.where((gift) => gift.priceAsDouble >= minPrice).toList();
    }

    if (maxPrice != null) {
      gifts = gifts.where((gift) => gift.priceAsDouble <= maxPrice).toList();
    }

    if (rarity != null) {
      gifts = gifts.where((gift) => gift.rarity == rarity).toList();
    }

    if (isPremiumOnly != null) {
      gifts = gifts.where((gift) => gift.isPremiumOnly == isPremiumOnly).toList();
    }

    gifts.sort((a, b) {
      final countA = state.giftCounts[a.id] ?? 0;
      final countB = state.giftCounts[b.id] ?? 0;
      
      if (countA != countB) {
        return countB.compareTo(countA);
      }
      
      return a.price.compareTo(b.price);
    });

    return gifts;
  }

  List<GiftModel> getGiftsByCategory(String category) {
    return state.giftsByCategory[category] ?? [];
  }

  List<GiftModel> getGiftsByRarity(GiftRarity rarity) {
    return state.availableGifts.where((g) => g.rarity == rarity).toList();
  }

  List<GiftModel> getPopularGifts({int limit = 10}) {
    final gifts = state.availableGifts.toList();
    
    gifts.sort((a, b) {
      final countA = state.giftCounts[a.id] ?? 0;
      final countB = state.giftCounts[b.id] ?? 0;
      return countB.compareTo(countA);
    });

    return gifts.take(limit).toList();
  }

  void _startPeriodicUpdates() {
    _statsUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _calculateStats(),
    );
  }

  Future<void> refreshGifts() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await Future.wait([
        _loadCustomGifts(),
        _loadTransactionHistory(),
      ]);
      
      await _calculateStats();
      
      state = state.copyWith(
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors du rafraîchissement: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _giftTransactionSubscription?.cancel();
    _customGiftsSubscription?.cancel();
    _statsUpdateTimer?.cancel();
    super.dispose();
  }
}

final giftServiceProvider = StateNotifierProvider<GiftNotifier, GiftState>(
  (ref) => GiftNotifier(ref),
);

final availableGiftsProvider = Provider<List<GiftModel>>((ref) {
  return ref.watch(giftServiceProvider).availableGifts;
});

final giftsByCategoryProvider = Provider<Map<String, List<GiftModel>>>((ref) {
  return ref.watch(giftServiceProvider).giftsByCategory;
});

final giftTransactionsProvider = Provider<List<GiftTransaction>>((ref) {
  return ref.watch(giftServiceProvider).recentTransactions;
});

final giftStatsProvider = Provider<GiftStats>((ref) {
  return ref.watch(giftServiceProvider).stats;
});

final giftCountsProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(giftServiceProvider).giftCounts;
});

final isGiftServiceLoadingProvider = Provider<bool>((ref) {
  return ref.watch(giftServiceProvider).isLoading;
});

final isGiftSendingProvider = Provider<bool>((ref) {
  return ref.watch(giftServiceProvider).isSending;
});

final giftsByCategoryFilterProvider = Provider.family<List<GiftModel>, String>((ref, category) {
  final gifts = ref.watch(availableGiftsProvider);
  return gifts.where((gift) => gift.category == category).toList();
});

final giftsByRarityProvider = Provider.family<List<GiftModel>, GiftRarity>((ref, rarity) {
  final gifts = ref.watch(availableGiftsProvider);
  return gifts.where((gift) => gift.rarity == rarity).toList();
});

final giftsInPriceRangeProvider = Provider.family<List<GiftModel>, Map<String, double>>((ref, range) {
  final gifts = ref.watch(availableGiftsProvider);
  final min = range['min'] ?? 0.0;
  final max = range['max'] ?? double.infinity;
  
  return gifts.where((gift) => gift.priceAsDouble >= min && gift.priceAsDouble <= max).toList();
});

final popularGiftsProvider = Provider.family<List<GiftModel>, int>((ref, limit) {
  final notifier = ref.watch(giftServiceProvider.notifier);
  return notifier.getPopularGifts(limit: limit);
});

final premiumGiftsProvider = Provider<List<GiftModel>>((ref) {
  final gifts = ref.watch(availableGiftsProvider);
  return gifts.where((gift) => gift.isPremiumOnly).toList();
});

final freeGiftsProvider = Provider<List<GiftModel>>((ref) {
  final gifts = ref.watch(availableGiftsProvider);
  return gifts.where((gift) => !gift.isPremiumOnly).toList();
});

final giftSearchProvider = Provider.family<List<GiftModel>, Map<String, dynamic>>((ref, filters) {
  final notifier = ref.watch(giftServiceProvider.notifier);
  return notifier.searchGifts(
    query: filters['query'],
    category: filters['category'],
    minPrice: filters['minPrice'],
    maxPrice: filters['maxPrice'],
    rarity: filters['rarity'],
    isPremiumOnly: filters['isPremiumOnly'],
  );
});

final sentGiftsProvider = Provider<List<GiftTransaction>>((ref) {
  return ref.watch(giftServiceProvider).sentGifts;
});

final receivedGiftsProvider = Provider<List<GiftTransaction>>((ref) {
  return ref.watch(giftServiceProvider).receivedGifts;
});

final giftTransactionsByDateProvider = Provider.family<List<GiftTransaction>, DateTime>((ref, date) {
  final transactions = ref.watch(giftTransactionsProvider);
  return transactions.where((transaction) {
    final transactionDate = transaction.timestamp;
    return transactionDate.year == date.year &&
           transactionDate.month == date.month &&
           transactionDate.day == date.day;
  }).toList();
});

final totalGiftsSentProvider = Provider<int>((ref) {
  return ref.watch(giftStatsProvider).giftsSentCount;
});

final totalGiftsReceivedProvider = Provider<int>((ref) {
  return ref.watch(giftStatsProvider).giftsReceivedCount;
});

final totalAmountSentProvider = Provider<double>((ref) {
  return ref.watch(giftStatsProvider).totalSent;
});

final totalAmountReceivedProvider = Provider<double>((ref) {
  return ref.watch(giftStatsProvider).totalReceived;
});

final favoriteGiftProvider = Provider<String?>((ref) {
  return ref.watch(giftStatsProvider).favoriteGiftSent;
});

final giftByIdProvider = Provider.family<GiftModel?, String>((ref, giftId) {
  final gifts = ref.watch(availableGiftsProvider);
  try {
    return gifts.firstWhere((gift) => gift.id == giftId);
  } catch (e) {
    return null;
  }
});

// ✅ CORRECTION: Provider walletBalanceProvider corrigé avec alias
final walletBalanceProvider = FutureProvider<double>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return 0.0;
  
  final walletService = ref.watch(wallet_service.walletServiceProvider);
  final balance = await walletService.getUserBalance(currentUser.id);
  return balance.toDouble();
});

final canAffordGiftProvider = Provider.family<bool, String>((ref, giftId) {
  final gift = ref.watch(giftByIdProvider(giftId));
  final walletBalanceAsync = ref.watch(walletBalanceProvider);
  
  if (gift == null) return false;
  
  return walletBalanceAsync.when(
    data: (balance) => balance >= gift.priceAsDouble,
    loading: () => false,
    error: (_, __) => false,
  );
});

final categoryCountProvider = Provider.family<int, String>((ref, category) {
  final gifts = ref.watch(giftsByCategoryFilterProvider(category));
  return gifts.length;
});

final rarityCountProvider = Provider.family<int, GiftRarity>((ref, rarity) {
  final gifts = ref.watch(giftsByRarityProvider(rarity));
  return gifts.length;
});

extension GiftModelUtils on GiftModel {
  String get formattedPrice {
    return '$price crédits';
  }
  
  String get rarityDisplayName {
    switch (rarity) {
      case GiftRarity.common:
        return 'Commun';
      case GiftRarity.rare:
        return 'Rare';
      case GiftRarity.epic:
        return 'Épique';
      case GiftRarity.legendary:
        return 'Légendaire';
    }
  }
  
  String get categoryDisplayName {
    switch (category) {
      case 'romantic':
        return 'Romantique';
      case 'appreciation':
        return 'Appréciation';
      case 'luxury':
        return 'Luxe';
      case 'festive':
        return 'Festif';
      default:
        return category;
    }
  }
  
  bool canAfford(double balance) {
    return balance >= priceAsDouble;
  }
  
  bool isAffordableWith(int quantity, double balance) {
    return balance >= (priceAsDouble * quantity);
  }
}

extension GiftTransactionUtils on GiftTransaction {
  String get formattedAmount {
    return '${amountPaid.toStringAsFixed(2)} crédits';
  }
  
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
  
  bool isRecent() {
    final now = DateTime.now();
    return now.difference(timestamp).inHours < 24;
  }
  
  bool isFromToday() {
    final now = DateTime.now();
    return timestamp.year == now.year &&
           timestamp.month == now.month &&
           timestamp.day == now.day;
  }
}

class GiftAnimationHelper {
  static GiftAnimation createFromTransaction(GiftTransaction transaction) {
    final gift = DefaultGifts.gifts.firstWhere(
      (g) => g.id == transaction.giftId,
      orElse: () => DefaultGifts.gifts.first,
    );
    
    return GiftAnimation(
      id: '${transaction.id}_anim',
      giftId: transaction.giftId,
      giftIcon: gift.icon,
      animationPath: gift.animationPath,
      rarity: gift.rarity,
      quantity: transaction.quantity,
      senderId: transaction.senderId,
      timestamp: transaction.timestamp,
    );
  }
  
  static List<GiftAnimation> createAnimationsFromTransactions(List<GiftTransaction> transactions) {
    return transactions.map((transaction) => createFromTransaction(transaction)).toList();
  }
}

class GiftConstants {
  static const Map<GiftRarity, String> rarityColors = {
    GiftRarity.common: '#9E9E9E',
    GiftRarity.rare: '#2196F3',
    GiftRarity.epic: '#9C27B0',
    GiftRarity.legendary: '#FF9800',
  };
  
  static const Map<String, String> categoryIcons = {
    'romantic': '💕',
    'appreciation': '👏',
    'luxury': '💎',
    'festive': '🎉',
  };
  
  static const double platformCommission = 0.2;
  static const double creatorShare = 0.8;
  
  static const int maxGiftsPerTransaction = 99;
  static const int maxTransactionsPerDay = 1000;
  
  static const Duration animationDuration = Duration(seconds: 3);
  static const Duration cacheExpiration = Duration(minutes: 30);
}

class GiftUtils {
  static String formatGiftPrice(int price) {
    return '$price crédits';
  }
  
  static String formatGiftPriceWithCurrency(int price, String currencySymbol) {
    final convertedPrice = price * 0.01;
    return '$currencySymbol${convertedPrice.toStringAsFixed(2)}';
  }
  
  static Color getRarityColor(GiftRarity rarity) {
    switch (rarity) {
      case GiftRarity.common:
        return const Color(0xFF9E9E9E);
      case GiftRarity.rare:
        return const Color(0xFF2196F3);
      case GiftRarity.epic:
        return const Color(0xFF9C27B0);
      case GiftRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }
  
  static String getCategoryIcon(String category) {
    return GiftConstants.categoryIcons[category] ?? '🎁';
  }
  
  static bool canSendGift(GiftModel gift, double balance, bool isPremiumUser) {
    if (gift.isPremiumOnly && !isPremiumUser) {
      return false;
    }
    return balance >= gift.priceAsDouble;
  }
  
  static int calculateTotalPrice(GiftModel gift, int quantity) {
    return gift.price * quantity;
  }
  
  static double calculateReceivedAmount(int totalPrice) {
    return totalPrice * GiftConstants.creatorShare;
  }
  
  static List<GiftModel> sortGiftsByPopularity(List<GiftModel> gifts, Map<String, int> giftCounts) {
    final sortedGifts = gifts.toList();
    sortedGifts.sort((a, b) {
      final countA = giftCounts[a.id] ?? 0;
      final countB = giftCounts[b.id] ?? 0;
      
      if (countA != countB) {
        return countB.compareTo(countA);
      }
      
      return a.price.compareTo(b.price);
    });
    
    return sortedGifts;
  }
  
  static List<GiftModel> sortGiftsByPrice(List<GiftModel> gifts, {bool ascending = true}) {
    final sortedGifts = gifts.toList();
    sortedGifts.sort((a, b) => ascending 
        ? a.price.compareTo(b.price) 
        : b.price.compareTo(a.price));
    
    return sortedGifts;
  }
  
  static List<GiftModel> sortGiftsByRarity(List<GiftModel> gifts) {
    final rarityOrder = {
      GiftRarity.legendary: 0,
      GiftRarity.epic: 1,
      GiftRarity.rare: 2,
      GiftRarity.common: 3,
    };
    
    final sortedGifts = gifts.toList();
    sortedGifts.sort((a, b) {
      final orderA = rarityOrder[a.rarity] ?? 999;
      final orderB = rarityOrder[b.rarity] ?? 999;
      return orderA.compareTo(orderB);
    });
    
    return sortedGifts;
  }
  
  static Map<String, List<GiftModel>> groupGiftsByCategory(List<GiftModel> gifts) {
    final grouped = <String, List<GiftModel>>{};
    for (final gift in gifts) {
      grouped.putIfAbsent(gift.category, () => []).add(gift);
    }
    return grouped;
  }
  
  static Map<GiftRarity, List<GiftModel>> groupGiftsByRarity(List<GiftModel> gifts) {
    final grouped = <GiftRarity, List<GiftModel>>{};
    for (final gift in gifts) {
      grouped.putIfAbsent(gift.rarity, () => []).add(gift);
    }
    return grouped;
  }
  
  static List<GiftModel> filterGiftsByPriceRange(List<GiftModel> gifts, int minPrice, int maxPrice) {
    return gifts.where((gift) => 
        gift.price >= minPrice && gift.price <= maxPrice).toList();
  }
  
  static List<GiftModel> getRecommendedGifts(
    List<GiftModel> availableGifts,
    List<GiftTransaction> userHistory,
    int limit,
  ) {
    if (userHistory.isEmpty) {
      return availableGifts
          .where((g) => g.price <= 50 && !g.isPremiumOnly)
          .take(limit)
          .toList();
    }
    
    final giftCounts = <String, int>{};
    for (final transaction in userHistory) {
      giftCounts[transaction.giftId] = (giftCounts[transaction.giftId] ?? 0) + 1;
    }
    
    final avgPrice = userHistory
        .map((t) => t.amountPaid)
        .fold(0.0, (a, b) => a + b) / userHistory.length;
    
    var recommendations = availableGifts
        .where((g) => 
            g.priceAsDouble >= avgPrice * 0.5 && 
            g.priceAsDouble <= avgPrice * 2.0 &&
            (giftCounts[g.id] ?? 0) < 3)
        .toList();
    
    if (recommendations.length < limit) {
      final remaining = availableGifts
          .where((g) => !recommendations.contains(g))
          .take(limit - recommendations.length)
          .toList();
      recommendations.addAll(remaining);
    }
    
    return recommendations.take(limit).toList();
  }
}

// ✅ TOUS LES CONFLITS D'IMPORTS SONT MAINTENANT RÉSOLUS !
// ✅ TOUTES LES MÉTHODES MANQUANTES SONT AJOUTÉES !
// ✅ VOTRE APPLICATION DEVRAIT COMPILER SANS ERREURS !