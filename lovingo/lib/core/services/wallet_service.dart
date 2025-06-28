// lib/core/services/wallet_service.dart - SERVICE PORTEFEUILLE CORRIGÉ
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/webrtc_config.dart';
import 'auth_service.dart';
import 'currency_service.dart';
import '../models/user_model.dart';

// ✅ ÉTAT DU WALLET
@immutable
class WalletState {
  final double balance;
  final double totalEarnings;
  final double pendingWithdrawal;
  final String? paymentMethod;
  final List<WalletTransaction> recentTransactions;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final WalletStats stats;

  const WalletState({
    this.balance = 0.0,
    this.totalEarnings = 0.0,
    this.pendingWithdrawal = 0.0,
    this.paymentMethod,
    this.recentTransactions = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.stats = const WalletStats(),
  });

  WalletState copyWith({
    double? balance,
    double? totalEarnings,
    double? pendingWithdrawal,
    String? paymentMethod,
    List<WalletTransaction>? recentTransactions,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    WalletStats? stats,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      pendingWithdrawal: pendingWithdrawal ?? this.pendingWithdrawal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      stats: stats ?? this.stats,
    );
  }

  getUserBalance(String id) {}

  deductBalance(String id, int int) {}
}

// ✅ STATISTIQUES DU WALLET
@immutable
class WalletStats {
  final double totalTopUps;
  final double totalGiftsReceived;
  final double totalGiftsSent;
  final double totalWithdrawals;
  final int transactionCount;
  final DateTime? firstTransactionDate;
  final double averageTransactionAmount;
  final Map<WalletTransactionType, double> byCategory;

  const WalletStats({
    this.totalTopUps = 0.0,
    this.totalGiftsReceived = 0.0,
    this.totalGiftsSent = 0.0,
    this.totalWithdrawals = 0.0,
    this.transactionCount = 0,
    this.firstTransactionDate,
    this.averageTransactionAmount = 0.0,
    this.byCategory = const {},
  });

  WalletStats copyWith({
    double? totalTopUps,
    double? totalGiftsReceived,
    double? totalGiftsSent,
    double? totalWithdrawals,
    int? transactionCount,
    DateTime? firstTransactionDate,
    double? averageTransactionAmount,
    Map<WalletTransactionType, double>? byCategory,
  }) {
    return WalletStats(
      totalTopUps: totalTopUps ?? this.totalTopUps,
      totalGiftsReceived: totalGiftsReceived ?? this.totalGiftsReceived,
      totalGiftsSent: totalGiftsSent ?? this.totalGiftsSent,
      totalWithdrawals: totalWithdrawals ?? this.totalWithdrawals,
      transactionCount: transactionCount ?? this.transactionCount,
      firstTransactionDate: firstTransactionDate ?? this.firstTransactionDate,
      averageTransactionAmount: averageTransactionAmount ?? this.averageTransactionAmount,
      byCategory: byCategory ?? this.byCategory,
    );
  }
}

// ✅ NOTIFIER DU WALLET
class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription? _balanceSubscription;
  StreamSubscription? _transactionSubscription;
  Timer? _statsUpdateTimer;
  
  WalletNotifier(this._ref) : super(const WalletState()) {
    _initializeWallet();
    _startPeriodicUpdates();
  }

  // ✅ OBTENIR L'UTILISATEUR ACTUEL
  UserModel? get _currentUser => _ref.read(currentUserProvider);

  // ✅ INITIALISATION DU WALLET
  Future<void> _initializeWallet() async {
    if (_currentUser == null) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _loadWalletData();
      await _setupRealtimeListeners();
      await _loadCachedData();
      
      state = state.copyWith(isLoading: false);
      WebRTCConfig.logInfo('✅ Wallet initialisé');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur initialisation wallet: $e',
      );
      WebRTCConfig.logError('Erreur initialisation wallet', e);
    }
  }

  // ✅ CHARGER LES DONNÉES DU WALLET
  Future<void> _loadWalletData() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('user_wallets')
          .doc(user.id)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        state = state.copyWith(
          balance: (data['balance'] ?? 0.0).toDouble(),
          totalEarnings: (data['totalEarnings'] ?? 0.0).toDouble(),
          pendingWithdrawal: (data['pendingWithdrawal'] ?? 0.0).toDouble(),
          paymentMethod: data['paymentMethod'],
          lastUpdated: DateTime.now(),
        );
      } else {
        await _createInitialWallet(user.id);
      }
      
      await _loadRecentTransactions();
      await _calculateStats();
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement wallet', e);
      rethrow;
    }
  }

  // ✅ CRÉER LE WALLET INITIAL
  Future<void> _createInitialWallet(String userId) async {
    const welcomeBonus = 50.0;
    
    try {
      final walletData = {
        'balance': welcomeBonus,
        'totalEarnings': welcomeBonus,
        'pendingWithdrawal': 0.0,
        'paymentMethod': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('user_wallets')
          .doc(userId)
          .set(walletData);

      // Enregistrer la transaction de bonus
      await _recordTransaction(
        userId: userId,
        type: WalletTransactionType.bonus,
        amount: welcomeBonus,
        description: 'Bonus de bienvenue',
        metadata: {'isWelcomeBonus': true},
      );

      state = state.copyWith(
        balance: welcomeBonus,
        totalEarnings: welcomeBonus,
      );

      WebRTCConfig.logInfo('✅ Wallet initial créé avec bonus: $welcomeBonus');
    } catch (e) {
      WebRTCConfig.logError('Erreur création wallet initial', e);
      rethrow;
    }
  }

  // ✅ CONFIGURATION DES LISTENERS TEMPS RÉEL
  Future<void> _setupRealtimeListeners() async {
    final user = _currentUser;
    if (user == null) return;

    // Écouter les changements de solde
    _balanceSubscription = _firestore
        .collection('user_wallets')
        .doc(user.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        state = state.copyWith(
          balance: (data['balance'] ?? 0.0).toDouble(),
          totalEarnings: (data['totalEarnings'] ?? 0.0).toDouble(),
          pendingWithdrawal: (data['pendingWithdrawal'] ?? 0.0).toDouble(),
          paymentMethod: data['paymentMethod'],
          lastUpdated: DateTime.now(),
        );
        _saveToCache();
      }
    });

    // Écouter les nouvelles transactions
    _transactionSubscription = _firestore
        .collection('wallet_transactions')
        .where('userId', isEqualTo: user.id)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      final transactions = snapshot.docs
          .map((doc) => WalletTransaction.fromFirestore(doc))
          .toList();
      
      state = state.copyWith(recentTransactions: transactions);
      _calculateStats();
    });
  }

  // ✅ MISE À JOUR PÉRIODIQUE DES STATISTIQUES
  void _startPeriodicUpdates() {
    _statsUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _calculateStats(),
    );
  }

  // ✅ CACHE DES DONNÉES
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'balance': state.balance,
        'totalEarnings': state.totalEarnings,
        'pendingWithdrawal': state.pendingWithdrawal,
        'paymentMethod': state.paymentMethod,
        'lastUpdated': state.lastUpdated?.millisecondsSinceEpoch,
      };
      
      await prefs.setString('wallet_cache', jsonEncode(cacheData));
    } catch (e) {
      WebRTCConfig.logError('Erreur sauvegarde cache wallet', e);
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('wallet_cache');
      
      if (cacheString != null) {
        final cacheData = jsonDecode(cacheString);
        
        // Utiliser les données du cache si récentes (< 1 heure)
        final lastUpdated = cacheData['lastUpdated'] != null
            ? DateTime.fromMillisecondsSinceEpoch(cacheData['lastUpdated'])
            : null;
            
        if (lastUpdated != null && 
            DateTime.now().difference(lastUpdated).inHours < 1) {
          state = state.copyWith(
            balance: (cacheData['balance'] ?? 0.0).toDouble(),
            totalEarnings: (cacheData['totalEarnings'] ?? 0.0).toDouble(),
            pendingWithdrawal: (cacheData['pendingWithdrawal'] ?? 0.0).toDouble(),
            paymentMethod: cacheData['paymentMethod'],
            lastUpdated: lastUpdated,
          );
        }
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement cache wallet', e);
    }
  }

  // ✅ CHARGER LES TRANSACTIONS RÉCENTES
  Future<void> _loadRecentTransactions() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('wallet_transactions')
          .where('userId', isEqualTo: user.id)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final transactions = snapshot.docs
          .map((doc) => WalletTransaction.fromFirestore(doc))
          .toList();

      state = state.copyWith(recentTransactions: transactions);
    } catch (e) {
      WebRTCConfig.logError('Erreur chargement transactions récentes', e);
    }
  }

  // ✅ CALCULER LES STATISTIQUES
  Future<void> _calculateStats() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('wallet_transactions')
          .where('userId', isEqualTo: user.id)
          .get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(stats: const WalletStats());
        return;
      }

      final transactions = snapshot.docs
          .map((doc) => WalletTransaction.fromFirestore(doc))
          .toList();

      double totalTopUps = 0;
      double totalGiftsReceived = 0;
      double totalGiftsSent = 0;
      double totalWithdrawals = 0;
      final byCategory = <WalletTransactionType, double>{};
      DateTime? firstTransactionDate;

      for (final transaction in transactions) {
        switch (transaction.type) {
          case WalletTransactionType.topUp:
            totalTopUps += transaction.amount.abs();
            break;
          case WalletTransactionType.giftReceived:
            totalGiftsReceived += transaction.amount.abs();
            break;
          case WalletTransactionType.giftSent:
            totalGiftsSent += transaction.amount.abs();
            break;
          case WalletTransactionType.withdrawal:
            totalWithdrawals += transaction.amount.abs();
            break;
          default:
            break;
        }

        // Par catégorie
        byCategory[transaction.type] = 
            (byCategory[transaction.type] ?? 0) + transaction.amount.abs();

        // Première transaction
        if (firstTransactionDate == null || 
            transaction.timestamp.isBefore(firstTransactionDate)) {
          firstTransactionDate = transaction.timestamp;
        }
      }

      final totalAmount = transactions
          .map((t) => t.amount.abs())
          .fold(0.0, (a, b) => a + b);
      
      final averageAmount = transactions.isNotEmpty 
          ? totalAmount / transactions.length 
          : 0.0;

      final stats = WalletStats(
        totalTopUps: totalTopUps,
        totalGiftsReceived: totalGiftsReceived,
        totalGiftsSent: totalGiftsSent,
        totalWithdrawals: totalWithdrawals,
        transactionCount: transactions.length,
        firstTransactionDate: firstTransactionDate,
        averageTransactionAmount: averageAmount,
        byCategory: byCategory,
      );

      state = state.copyWith(stats: stats);
    } catch (e) {
      WebRTCConfig.logError('Erreur calcul statistiques', e);
    }
  }

  // ✅ AJOUTER DES FONDS
  Future<bool> addFunds({
    required double amount,
    required String paymentMethod,
    String? transactionId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _currentUser;
    if (user == null) return false;

    if (amount <= 0) {
      state = state.copyWith(error: 'Montant invalide');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Mettre à jour le solde
      await _firestore.collection('user_wallets').doc(user.id).update({
        'balance': FieldValue.increment(amount),
        'totalEarnings': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Enregistrer la transaction
      await _recordTransaction(
        userId: user.id,
        type: WalletTransactionType.topUp,
        amount: amount,
        description: 'Recharge par $paymentMethod',
        metadata: {
          'paymentMethod': paymentMethod,
          'transactionId': transactionId,
          ...?metadata,
        },
      );

      state = state.copyWith(
        isLoading: false,
        balance: state.balance + amount,
        totalEarnings: state.totalEarnings + amount,
      );

      WebRTCConfig.logInfo('✅ Fonds ajoutés: $amount');
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de la recharge: $e',
      );
      WebRTCConfig.logError('Erreur ajout fonds', e);
      return false;
    }
  }

  // ✅ DÉDUIRE DES FONDS
  Future<bool> deductFunds({
    required double amount,
    required String description,
    WalletTransactionType type = WalletTransactionType.purchase,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _currentUser;
    if (user == null) return false;

    if (amount <= 0) {
      state = state.copyWith(error: 'Montant invalide');
      return false;
    }

    if (state.balance < amount) {
      state = state.copyWith(error: 'Solde insuffisant');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Déduire du solde
      await _firestore.collection('user_wallets').doc(user.id).update({
        'balance': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Enregistrer la transaction
      await _recordTransaction(
        userId: user.id,
        type: type,
        amount: -amount,
        description: description,
        metadata: {
          'relatedId': relatedId,
          ...?metadata,
        },
      );

      state = state.copyWith(
        isLoading: false,
        balance: state.balance - amount,
      );

      WebRTCConfig.logInfo('✅ Fonds déduits: $amount');
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de la déduction: $e',
      );
      WebRTCConfig.logError('Erreur déduction fonds', e);
      return false;
    }
  }

  // ✅ RECEVOIR UN CADEAU
  Future<bool> receiveGift({
    required double amount,
    required String fromUserId,
    required String giftType,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _currentUser;
    if (user == null) return false;

    if (amount <= 0) return false;

    try {
      // Ajouter au solde
      await _firestore.collection('user_wallets').doc(user.id).update({
        'balance': FieldValue.increment(amount),
        'totalEarnings': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Enregistrer la transaction
      await _recordTransaction(
        userId: user.id,
        type: WalletTransactionType.giftReceived,
        amount: amount,
        description: 'Cadeau reçu: $giftType',
        metadata: {
          'fromUserId': fromUserId,
          'giftType': giftType,
          'message': message,
          ...?metadata,
        },
      );

      WebRTCConfig.logInfo('✅ Cadeau reçu: $amount de $fromUserId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur réception cadeau', e);
      return false;
    }
  }

  // ✅ ENVOYER UN CADEAU
  Future<bool> sendGift({
    required double amount,
    required String toUserId,
    required String giftType,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _currentUser;
    if (user == null) return false;

    if (amount <= 0 || state.balance < amount) return false;

    try {
      // Déduire du solde de l'expéditeur
      await deductFunds(
        amount: amount,
        description: 'Cadeau envoyé: $giftType',
        type: WalletTransactionType.giftSent,
        metadata: {
          'toUserId': toUserId,
          'giftType': giftType,
          'message': message,
          ...?metadata,
        },
      );

      WebRTCConfig.logInfo('✅ Cadeau envoyé: $amount à $toUserId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur envoi cadeau', e);
      return false;
    }
  }

  // ✅ ENREGISTRER UNE TRANSACTION
  Future<void> _recordTransaction({
    required String userId,
    required WalletTransactionType type,
    required double amount,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final transaction = {
        'userId': userId,
        'type': type.name,
        'amount': amount,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      };

      await _firestore.collection('wallet_transactions').add(transaction);
    } catch (e) {
      WebRTCConfig.logError('Erreur enregistrement transaction', e);
      rethrow;
    }
  }

  // ✅ OBTENIR L'HISTORIQUE COMPLET
  Future<List<WalletTransaction>> getTransactionHistory({
    int limit = 50,
    WalletTransactionType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = _currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('wallet_transactions')
          .where('userId', isEqualTo: user.id);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (startDate != null) {
        query = query.where('timestamp', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', 
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => WalletTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      WebRTCConfig.logError('Erreur historique transactions', e);
      return [];
    }
  }

  // ✅ CONFIGURER LA MÉTHODE DE PAIEMENT
  Future<bool> setPaymentMethod(String paymentMethod) async {
    final user = _currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('user_wallets').doc(user.id).update({
        'paymentMethod': paymentMethod,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(paymentMethod: paymentMethod);
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur configuration méthode paiement', e);
      return false;
    }
  }

  // ✅ ACTUALISER LES DONNÉES
  Future<void> refreshWallet() async {
    await _loadWalletData();
  }

  // ✅ EFFACER L'ERREUR
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _transactionSubscription?.cancel();
    _statsUpdateTimer?.cancel();
    super.dispose();
  }
}

// ✅ PROVIDERS PRINCIPAUX
final walletServiceProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(ref),
);

// Providers dérivés pour faciliter l'accès
final walletBalanceProvider = Provider<double>((ref) {
  return ref.watch(walletServiceProvider).balance;
});

final walletStatsProvider = Provider<WalletStats>((ref) {
  return ref.watch(walletServiceProvider).stats;
});

final walletTransactionsProvider = Provider<List<WalletTransaction>>((ref) {
  return ref.watch(walletServiceProvider).recentTransactions;
});

// ✅ MODÈLE DE TRANSACTION
@immutable
class WalletTransaction {
  final String id;
  final String userId;
  final WalletTransactionType type;
  final double amount;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type.name,
    'amount': amount,
    'description': description,
    'timestamp': Timestamp.fromDate(timestamp),
    'metadata': metadata,
  };

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: WalletTransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => WalletTransactionType.other,
      ),
      amount: (data['amount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  WalletTransaction copyWith({
    String? id,
    String? userId,
    WalletTransactionType? type,
    double? amount,
    String? description,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ✅ ENUM DES TYPES DE TRANSACTIONS
enum WalletTransactionType {
  topUp,          // Recharge
  purchase,       // Achat général
  giftSent,       // Cadeau envoyé
  giftReceived,   // Cadeau reçu
  withdrawal,     // Retrait
  bonus,          // Bonus système
  refund,         // Remboursement
  tip,            // Pourboire
  subscription,   // Abonnement
  commission,     // Commission
  penalty,        // Pénalité
  other,          // Autre
}