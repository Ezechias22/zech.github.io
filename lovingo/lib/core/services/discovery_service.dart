// lib/core/services/discovery_service.dart - SERVICE DE DÉCOUVERTE COMPLET AVEC DEBUG
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../models/user_model.dart';
import 'auth_service.dart';

final discoveryServiceProvider = StateNotifierProvider<DiscoveryService, DiscoveryState>(
  (ref) => DiscoveryService(ref),
);

class DiscoveryState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> filters;
  final List<String> swipedUserIds;
  final bool hasMore;
  final int currentPage;

  const DiscoveryState({
    this.users = const [],
    this.isLoading = false,
    this.error,
    this.filters = const {},
    this.swipedUserIds = const [],
    this.hasMore = true,
    this.currentPage = 0,
  });

  DiscoveryState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? filters,
    List<String>? swipedUserIds,
    bool? hasMore,
    int? currentPage,
  }) {
    return DiscoveryState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filters: filters ?? this.filters,
      swipedUserIds: swipedUserIds ?? this.swipedUserIds,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class DiscoveryService extends StateNotifier<DiscoveryState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Ref _ref;
  DocumentSnapshot? _lastDocument;

  DiscoveryService(this._ref) : super(const DiscoveryState()) {
    _debugInfo('🚀 DiscoveryService initialisé');
    loadUsers();
  }

  // ✅ MÉTHODE DEBUG POUR IDENTIFIER LES PROBLÈMES
  void _debugInfo(String message) {
    print('🔍 DISCOVERY DEBUG: $message');
  }

  void _debugError(String message, [dynamic error]) {
    print('❌ DISCOVERY ERROR: $message');
    if (error != null) {
      print('   Details: $error');
    }
  }

  // ✅ CHARGER LES UTILISATEURS AVEC DEBUG COMPLET
  Future<void> loadUsers({bool refresh = false}) async {
    try {
      _debugInfo('📥 Début chargement utilisateurs (refresh: $refresh)');
      
      if (refresh) {
        _lastDocument = null;
        state = state.copyWith(users: [], currentPage: 0, hasMore: true);
      }
      
      state = state.copyWith(isLoading: true, error: null);
      
      // 1. Récupérer l'utilisateur actuel
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) {
        _debugError('Aucun utilisateur connecté');
        state = state.copyWith(
          isLoading: false,
          error: 'Utilisateur non connecté',
        );
        return;
      }
      
      _debugInfo('👤 Utilisateur actuel: ${currentUser.name} (${currentUser.id})');
      _debugInfo('🎯 Filtres appliqués: ${state.filters}');
      
      // 2. Construire la requête de base
      Query query = _firestore.collection('users');
      
      // 3. Appliquer les filtres
      query = _applyFilters(query, currentUser);
      
      // 4. Pagination
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      query = query.limit(20); // Charger 20 utilisateurs à la fois
      
      _debugInfo('🔍 Exécution de la requête Firestore...');
      
      // 5. Exécuter la requête
      final querySnapshot = await query.get();
      
      _debugInfo('📊 Résultats Firestore: ${querySnapshot.docs.length} documents');
      
      if (querySnapshot.docs.isEmpty) {
        _debugInfo('⚠️ Aucun document trouvé');
        
        // Debug: Vérifier combien d'utilisateurs total dans la collection
        final totalUsersSnapshot = await _firestore.collection('users').get();
        _debugInfo('📊 Total utilisateurs dans Firestore: ${totalUsersSnapshot.docs.length}');
        
        if (totalUsersSnapshot.docs.isEmpty) {
          _debugError('🚨 PROBLÈME: Aucun utilisateur dans la collection Firestore!');
          state = state.copyWith(
            isLoading: false,
            error: 'Aucun utilisateur trouvé dans la base de données',
          );
          return;
        }
        
        state = state.copyWith(
          isLoading: false,
          hasMore: false,
        );
        return;
      }
      
      // 6. Convertir les documents en UserModel
      final List<UserModel> newUsers = [];
      
      for (final doc in querySnapshot.docs) {
        try {
          _debugInfo('🔄 Traitement document: ${doc.id}');
          
          final data = doc.data() as Map<String, dynamic>;
          final user = UserModel.fromMap(data, doc.id);
          
          // Vérifications supplémentaires
          if (user.id != currentUser.id && !state.swipedUserIds.contains(user.id)) {
            newUsers.add(user);
            _debugInfo('✅ Utilisateur ajouté: ${user.name} (${user.id})');
          } else {
            _debugInfo('⚠️ Utilisateur exclu: ${user.name} (${user.id}) - Raison: ${user.id == currentUser.id ? 'utilisateur actuel' : 'déjà swipé'}');
          }
        } catch (e) {
          _debugError('Erreur traitement document ${doc.id}', e);
        }
      }
      
      _debugInfo('📋 Utilisateurs finaux: ${newUsers.length}');
      
      // 7. Appliquer filtres géographiques si nécessaire
      final filteredUsers = await _applyGeographicFilters(newUsers, currentUser);
      
      // 8. Mettre à jour l'état
      final allUsers = refresh ? filteredUsers : [...state.users, ...filteredUsers];
      
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }
      
      state = state.copyWith(
        users: allUsers,
        isLoading: false,
        hasMore: filteredUsers.length == 20, // S'il y a 20 résultats, il y en a peut-être plus
        currentPage: state.currentPage + 1,
      );
      
      _debugInfo('✅ Chargement terminé: ${allUsers.length} utilisateurs total');
      
      // 9. Si pas assez d'utilisateurs et qu'il pourrait y en avoir plus, recharger
      if (allUsers.length < 5 && state.hasMore) {
        _debugInfo('🔄 Pas assez d\'utilisateurs, rechargement...');
        await loadUsers();
      }
      
    } catch (e, stackTrace) {
      _debugError('Erreur globale loadUsers', e);
      _debugError('Stack trace', stackTrace);
      
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur de chargement: $e',
      );
    }
  }

  // ✅ APPLIQUER LES FILTRES À LA REQUÊTE
  Query _applyFilters(Query query, UserModel currentUser) {
    _debugInfo('🎛️ Application des filtres...');
    
    // Exclure l'utilisateur actuel
    // Note: Firestore ne supporte pas != avec des index composites complexes
    // On filtrera côté client si nécessaire
    
    // Filtre par genre
    if (state.filters['gender'] != null && state.filters['gender'] != 'all') {
      query = query.where('gender', isEqualTo: state.filters['gender']);
      _debugInfo('🎯 Filtre genre appliqué: ${state.filters['gender']}');
    }
    
    // Filtre par âge
    if (state.filters['minAge'] != null) {
      query = query.where('age', isGreaterThanOrEqualTo: state.filters['minAge']);
      _debugInfo('🎯 Filtre âge min appliqué: ${state.filters['minAge']}');
    }
    
    if (state.filters['maxAge'] != null) {
      query = query.where('age', isLessThanOrEqualTo: state.filters['maxAge']);
      _debugInfo('🎯 Filtre âge max appliqué: ${state.filters['maxAge']}');
    }
    
    // Filtre utilisateurs actifs seulement
    query = query.where('isActive', isEqualTo: true);
    _debugInfo('🎯 Filtre utilisateurs actifs appliqué');
    
    // Ordonner par dernière activité (les plus récents d'abord)
    query = query.orderBy('lastActive', descending: true);
    _debugInfo('🎯 Tri par dernière activité appliqué');
    
    return query;
  }

  // ✅ APPLIQUER LES FILTRES GÉOGRAPHIQUES
  Future<List<UserModel>> _applyGeographicFilters(List<UserModel> users, UserModel currentUser) async {
    // Si pas de filtre de distance ou pas de localisation, retourner tous
    if (state.filters['maxDistance'] == null || currentUser.location == null) {
      _debugInfo('🌍 Pas de filtre géographique');
      return users;
    }
    
    final maxDistance = state.filters['maxDistance'] as double;
    final filteredUsers = <UserModel>[];
    
    _debugInfo('🌍 Application filtre géographique: ${maxDistance}km');
    
    for (final user in users) {
      if (user.location == null) continue;
      
      final distance = _calculateDistance(
        currentUser.location!.latitude,
        currentUser.location!.longitude,
        user.location!.latitude,
        user.location!.longitude,
      );
      
      if (distance <= maxDistance) {
        filteredUsers.add(user);
        _debugInfo('✅ ${user.name}: ${distance.toStringAsFixed(1)}km');
      } else {
        _debugInfo('❌ ${user.name}: ${distance.toStringAsFixed(1)}km (trop loin)');
      }
    }
    
    _debugInfo('🌍 Utilisateurs dans le rayon: ${filteredUsers.length}/${users.length}');
    return filteredUsers;
  }

  // ✅ CALCULER LA DISTANCE ENTRE DEUX POINTS
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Rayon de la Terre en km
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // ✅ SWIPER UN UTILISATEUR
  void swipeUser(String userId, bool isLike) {
    _debugInfo('👆 Swipe ${isLike ? 'LIKE' : 'PASS'} sur utilisateur: $userId');
    
    // Retirer l'utilisateur de la liste
    final updatedUsers = state.users.where((user) => user.id != userId).toList();
    
    // Ajouter à la liste des utilisateurs swipés
    final updatedSwipedIds = [...state.swipedUserIds, userId];
    
    state = state.copyWith(
      users: updatedUsers, 
      swipedUserIds: updatedSwipedIds,
    );
    
    // Enregistrer le swipe dans Firestore
    _recordSwipe(userId, isLike ? 'like' : 'pass');
    
    // Recharger si plus d'utilisateurs
    if (updatedUsers.length <= 2 && state.hasMore) {
      _debugInfo('🔄 Peu d\'utilisateurs restants, rechargement...');
      loadUsers();
    }
  }

  // ✅ SUPER LIKER UN UTILISATEUR
  void superLikeUser(String userId) {
    _debugInfo('⭐ Super Like sur utilisateur: $userId');
    
    // Retirer l'utilisateur de la liste
    final updatedUsers = state.users.where((user) => user.id != userId).toList();
    
    // Ajouter à la liste des utilisateurs swipés
    final updatedSwipedIds = [...state.swipedUserIds, userId];
    
    state = state.copyWith(
      users: updatedUsers,
      swipedUserIds: updatedSwipedIds,
    );
    
    // Enregistrer le super like dans Firestore
    _recordSwipe(userId, 'super_like');
    
    // Recharger si plus d'utilisateurs
    if (updatedUsers.length <= 2 && state.hasMore) {
      loadUsers();
    }
  }

  // ✅ ENREGISTRER UN SWIPE DANS FIRESTORE
  Future<void> _recordSwipe(String targetUserId, String swipeType) async {
    try {
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) return;
      
      final swipeData = {
        'userId': currentUser.id,
        'targetUserId': targetUserId,
        'swipeType': swipeType, // 'like', 'pass', 'super_like'
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('swipes').add(swipeData);
      _debugInfo('💾 Swipe enregistré: $swipeType vers $targetUserId');
      
      // Si c'est un like, vérifier s'il y a match
      if (swipeType == 'like' || swipeType == 'super_like') {
        await _checkForMatch(currentUser.id, targetUserId);
      }
      
    } catch (e) {
      _debugError('Erreur enregistrement swipe', e);
    }
  }

  // ✅ VÉRIFIER S'IL Y A MATCH
  Future<void> _checkForMatch(String userId, String targetUserId) async {
    try {
      // Chercher si l'autre utilisateur nous a aussi liké
      final reciprocalSwipe = await _firestore
          .collection('swipes')
          .where('userId', isEqualTo: targetUserId)
          .where('targetUserId', isEqualTo: userId)
          .where('swipeType', whereIn: ['like', 'super_like'])
          .get();
      
      if (reciprocalSwipe.docs.isNotEmpty) {
        // Il y a match !
        _debugInfo('💕 MATCH détecté entre $userId et $targetUserId');
        
        // Créer le match dans Firestore
        await _createMatch(userId, targetUserId);
      }
    } catch (e) {
      _debugError('Erreur vérification match', e);
    }
  }

  // ✅ CRÉER UN MATCH
  Future<void> _createMatch(String userId1, String userId2) async {
    try {
      final matchId = '${userId1}_$userId2';
      
      final matchData = {
        'id': matchId,
        'users': [userId1, userId2],
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'lastMessageAt': null,
      };
      
      await _firestore.collection('matches').doc(matchId).set(matchData);
      _debugInfo('💕 Match créé: $matchId');
      
    } catch (e) {
      _debugError('Erreur création match', e);
    }
  }

  // ✅ APPLIQUER DES FILTRES
  void applyFilters(Map<String, dynamic> filters) {
    _debugInfo('🎛️ Application de nouveaux filtres: $filters');
    
    state = state.copyWith(filters: filters);
    
    // Recharger avec les nouveaux filtres
    _lastDocument = null;
    loadUsers(refresh: true);
  }

  // ✅ RÉINITIALISER LES FILTRES
  void resetFilters() {
    _debugInfo('🔄 Réinitialisation des filtres');
    
    state = state.copyWith(filters: {});
    
    // Recharger sans filtres
    _lastDocument = null;
    loadUsers(refresh: true);
  }

  // ✅ RECHARGER LES UTILISATEURS
  void refresh() {
    _debugInfo('🔄 Rechargement manuel des utilisateurs');
    _lastDocument = null;
    loadUsers(refresh: true);
  }

  // ✅ DEBUG: CRÉER DES UTILISATEURS DE TEST
  Future<void> createTestUsers() async {
    _debugInfo('🧪 Création d\'utilisateurs de test...');
    
    final testUsers = [
      {
        'name': 'Emma Martin',
        'age': 24,
        'gender': 'female',
        'bio': 'Aime voyager et la photographie 📸',
        'interests': ['voyage', 'photographie', 'cuisine'],
        'photos': ['https://images.unsplash.com/photo-1494790108755-2616b9e08d2d?w=400'],
      },
      {
        'name': 'Lucas Dupont',
        'age': 28,
        'gender': 'male',
        'bio': 'Passionné de sport et de musique 🎵',
        'interests': ['sport', 'musique', 'cinéma'],
        'photos': ['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400'],
      },
      {
        'name': 'Sophie Bernard',
        'age': 26,
        'gender': 'female',
        'bio': 'Développeuse et artiste 🎨',
        'interests': ['technologie', 'art', 'lecture'],
        'photos': ['https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400'],
      },
      {
        'name': 'Thomas Leroy',
        'age': 30,
        'gender': 'male',
        'bio': 'Chef cuisinier et aventurier 🍳',
        'interests': ['cuisine', 'nature', 'sport'],
        'photos': ['https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400'],
      },
    ];
    
    try {
      for (final userData in testUsers) {
        final userId = _firestore.collection('users').doc().id;
        
        final completeUserData = {
          'id': userId,
          'email': '${userData['name']!.toString().toLowerCase().replaceAll(' ', '.')}@test.com',
          'phone': '',
          'name': userData['name'],
          'age': userData['age'],
          'gender': userData['gender'],
          'genderPreference': ['both'],
          'bio': userData['bio'],
          'photos': userData['photos'],
          'videos': [],
          'interests': userData['interests'],
          'location': {
            'latitude': 48.8566 + (Random().nextDouble() - 0.5) * 0.1,
            'longitude': 2.3522 + (Random().nextDouble() - 0.5) * 0.1,
            'city': 'Paris',
            'country': 'France',
          },
          'isPremium': false,
          'isActive': true,
          'isOnline': Random().nextBool(),
          'lastActive': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'minAge': 18,
          'maxAge': 50,
          'maxDistance': 50.0,
          'stats': {
            'totalLikes': Random().nextInt(100),
            'totalMatches': Random().nextInt(20),
            'totalGiftsReceived': Random().nextInt(50),
            'totalGiftsSent': Random().nextInt(30),
            'totalEarnings': Random().nextDouble() * 500,
            'profileViews': Random().nextInt(200),
          },
          'wallet': {
            'balance': Random().nextDouble() * 100,
            'totalEarnings': Random().nextDouble() * 500,
            'pendingWithdrawal': 0.0,
            'paymentMethod': null,
          },
          'preferences': {},
        };
        
        await _firestore.collection('users').doc(userId).set(completeUserData);
        _debugInfo('✅ Utilisateur test créé: ${userData['name']}');
      }
      
      _debugInfo('🎉 Tous les utilisateurs de test créés!');
      
      // Recharger les utilisateurs
      refresh();
      
    } catch (e) {
      _debugError('Erreur création utilisateurs test', e);
    }
  }
}