// lib/core/services/auth_service.dart - CORRIGÉ POUR ÉVITER L'ERREUR NULL
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

// ✅ PROVIDER PRINCIPAL CORRIGÉ
final authServiceProvider = StateNotifierProvider<AuthService, AuthState>(
  (ref) => AuthService(),
);

// ✅ PROVIDER UTILISATEUR ACTUEL CORRIGÉ
final currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authServiceProvider);
  return authState.user; // ✅ CORRIGÉ : accès direct à user
});

// ✅ AUTHSTATE CORRIGÉ - SUPPRESSION DU GETTER STATE PROBLÉMATIQUE
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final UserModel? user;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.user,
  });

  // ✅ GETTER CORRIGÉ
  UserModel? get currentUser => user;

  // ❌ SUPPRIMÉ : get state => null; (CAUSE DE L'ERREUR)

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    UserModel? user,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

// ✅ AUTHSERVICE CORRIGÉ
class AuthService extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService() : super(const AuthState()) {
    _checkAuthState();
  }

  // ✅ CORRIGÉ : Retourne vraiment l'utilisateur actuel
  UserModel? get currentUser => state.user;

  void _checkAuthState() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        state = const AuthState();
      }
    });
  }

  Future<void> _loadUserData(String userId) async {
    print('🔍 DÉBUT _loadUserData pour userId: $userId');
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      print('📊 Document existe: ${userDoc.exists}');
      
      if (userDoc.exists) {
        final rawData = userDoc.data();
        print('📊 Type de données: ${rawData.runtimeType}');
        print('📊 Données reçues: $rawData');
        
        if (rawData != null && rawData is Map<String, dynamic>) {
          print('✅ Données valides, création UserModel...');
          
          final userData = UserModel(
            id: rawData['id']?.toString() ?? userId,
            email: rawData['email']?.toString() ?? '',
            phone: rawData['phone']?.toString() ?? '',
            name: rawData['name']?.toString() ?? 'Utilisateur',
            age: (rawData['age'] as num?)?.toInt() ?? 25,
            gender: rawData['gender']?.toString() ?? 'other',
            genderPreference: (rawData['genderPreference'] as List<dynamic>?)
                ?.map((e) => e.toString()).toList() ?? ['both'],
            bio: rawData['bio']?.toString() ?? '',
            photos: (rawData['photos'] as List<dynamic>?)
                ?.map((e) => e.toString()).toList() ?? [],
            videos: (rawData['videos'] as List<dynamic>?)
                ?.map((e) => e.toString()).toList() ?? [],
            interests: (rawData['interests'] as List<dynamic>?)
                ?.map((e) => e.toString()).toList() ?? [],
            location: rawData['location'] != null 
                ? UserLocation(
                    latitude: (rawData['location']['latitude'] as num?)?.toDouble() ?? 0.0,
                    longitude: (rawData['location']['longitude'] as num?)?.toDouble() ?? 0.0,
                    city: rawData['location']['city']?.toString(),
                    country: rawData['location']['country']?.toString(),
                  )
                : null,
            isPremium: rawData['isPremium'] as bool? ?? false,
            isActive: rawData['isActive'] as bool? ?? true,
            isOnline: rawData['isOnline'] as bool? ?? false,
            lastActive: rawData['lastActive'] != null 
                ? _parseDateTime(rawData['lastActive'])
                : DateTime.now(),
            createdAt: rawData['createdAt'] != null 
                ? _parseDateTime(rawData['createdAt'])
                : DateTime.now(),
            minAge: (rawData['minAge'] as num?)?.toInt() ?? 18,
            maxAge: (rawData['maxAge'] as num?)?.toInt() ?? 50,
            maxDistance: (rawData['maxDistance'] as num?)?.toDouble() ?? 50.0,
            stats: rawData['stats'] != null 
                ? UserStats(
                    totalLikes: (rawData['stats']['totalLikes'] as num?)?.toInt() ?? 0,
                    totalMatches: (rawData['stats']['totalMatches'] as num?)?.toInt() ?? 0,
                    totalGiftsReceived: (rawData['stats']['totalGiftsReceived'] as num?)?.toInt() ?? 0,
                    totalGiftsSent: (rawData['stats']['totalGiftsSent'] as num?)?.toInt() ?? 0,
                    totalEarnings: (rawData['stats']['totalEarnings'] as num?)?.toDouble() ?? 0.0,
                    profileViews: (rawData['stats']['profileViews'] as num?)?.toInt() ?? 0,
                  )
                : const UserStats(),
            wallet: rawData['wallet'] != null 
                ? WalletInfo(
                    balance: (rawData['wallet']['balance'] as num?)?.toDouble() ?? 0.0,
                    totalEarnings: (rawData['wallet']['totalEarnings'] as num?)?.toDouble() ?? 0.0,
                    pendingWithdrawal: (rawData['wallet']['pendingWithdrawal'] as num?)?.toDouble() ?? 0.0,
                    paymentMethod: rawData['wallet']['paymentMethod']?.toString(),
                  )
                : const WalletInfo(),
            preferences: rawData['preferences'] as Map<String, dynamic>? ?? {},
          );
          
          print('✅ UserModel créé avec succès: ${userData.name}');
          
          state = AuthState(
            isAuthenticated: true,
            user: userData,
          );
          
          print('✅ État mis à jour: isAuthenticated = true');
        }
      } else {
        // 🚀 CRÉATION AUTOMATIQUE DU DOCUMENT
        print('🛠️ Document inexistant, création automatique...');
        
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // Créer directement une Map pour éviter les erreurs de sérialisation
          final newUserMap = {
            'id': userId,
            'email': currentUser.email ?? '',
            'phone': '',
            'name': currentUser.displayName ?? 'Utilisateur',
            'age': 25,
            'gender': 'other',
            'genderPreference': ['both'],
            'bio': '',
            'photos': [],
            'videos': [],
            'interests': [],
            'location': null,
            'isPremium': false,
            'isActive': true,
            'isOnline': false,
            'lastActive': DateTime.now().toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'minAge': 18,
            'maxAge': 50,
            'maxDistance': 50.0,
            'stats': {
              'totalLikes': 0,
              'totalMatches': 0,
              'totalGiftsReceived': 0,
              'totalGiftsSent': 0,
              'totalEarnings': 0.0,
              'profileViews': 0,
            },
            'wallet': {
              'balance': 0.0,
              'totalEarnings': 0.0,
              'pendingWithdrawal': 0.0,
              'paymentMethod': null,
            },
            'preferences': {},
          };
          
          // Créer le document dans Firestore
          await _firestore.collection('users').doc(userId).set(newUserMap);
          print('✅ Document utilisateur créé dans Firestore');
          
          // Créer l'objet UserModel après sauvegarde réussie
          final newUser = UserModel(
            id: userId,
            email: currentUser.email ?? '',
            phone: '',
            name: currentUser.displayName ?? 'Utilisateur',
            age: 25,
            gender: 'other',
            genderPreference: ['both'],
            bio: '',
            photos: [],
            videos: [],
            interests: [],
            lastActive: DateTime.now(),
            createdAt: DateTime.now(),
            stats: const UserStats(),
            wallet: const WalletInfo(),
          );
          
          state = AuthState(
            isAuthenticated: true,
            user: newUser,
          );
          
          print('✅ État mis à jour avec utilisateur créé automatiquement');
        } else {
          print('❌ Aucun utilisateur connecté dans Firebase Auth');
          state = AuthState(error: 'Utilisateur introuvable');
        }
      }
    } catch (e, stackTrace) {
      print('❌ ERREUR GLOBALE: $e');
      print('📍 Stack trace: $stackTrace');
      state = AuthState(error: e.toString());
    }
  }

  // ✅ HELPER POUR PARSER LES DATES
  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      return DateTime.parse(dateValue);
    } else {
      return DateTime.now();
    }
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true);
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        await _loadUserData(credential.user!.uid);
        return true;
      }
      
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required int age,
    required String gender,
  }) async {
    try {
      state = state.copyWith(isLoading: true);
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Créer directement une Map pour éviter les erreurs de sérialisation
        final userMap = {
          'id': credential.user!.uid,
          'email': email,
          'phone': '',
          'name': name,
          'age': age,
          'gender': gender,
          'genderPreference': ['both'],
          'bio': '',
          'photos': [],
          'videos': [],
          'interests': [],
          'location': null,
          'isPremium': false,
          'isActive': true,
          'isOnline': false,
          'lastActive': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'minAge': 18,
          'maxAge': 50,
          'maxDistance': 50.0,
          'stats': {
            'totalLikes': 0,
            'totalMatches': 0,
            'totalGiftsReceived': 0,
            'totalGiftsSent': 0,
            'totalEarnings': 0.0,
            'profileViews': 0,
          },
          'wallet': {
            'balance': 0.0,
            'totalEarnings': 0.0,
            'pendingWithdrawal': 0.0,
            'paymentMethod': null,
          },
          'preferences': {},
        };
        
        await _firestore.collection('users').doc(credential.user!.uid).set(userMap);
        await _loadUserData(credential.user!.uid);
        
        return true;
      }
      
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    state = const AuthState();
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void signOut() async {
    await logout();
  }
}