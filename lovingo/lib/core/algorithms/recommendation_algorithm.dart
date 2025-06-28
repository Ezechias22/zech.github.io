import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/interaction_model.dart';

class RecommendationAlgorithm {
  static const double _ageWeight = 0.15;
  static const double _distanceWeight = 0.25;
  static const double _interestsWeight = 0.20;
  static const double _activityWeight = 0.15;
  static const double _premiumWeight = 0.10;
  static const double _popularityWeight = 0.15;

  static Future<List<UserModel>> getRecommendations({
    required UserModel currentUser,
    required int limit,
  }) async {
    final firestore = FirebaseFirestore.instance;
    
    // Récupérer tous les utilisateurs potentiels
    final usersQuery = await firestore
        .collection('users')
        .where('id', isNotEqualTo: currentUser.id)
        .where('isActive', isEqualTo: true)
        .limit(100)
        .get();

    List<UserModel> candidateUsers = usersQuery.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((user) => _isEligible(currentUser, user))
        .toList();

    // Calculer le score pour chaque utilisateur
    List<UserScore> scoredUsers = [];
    for (UserModel user in candidateUsers) {
      double score = await _calculateScore(currentUser, user);
      scoredUsers.add(UserScore(user: user, score: score));
    }

    // Trier par score décroissant
    scoredUsers.sort((a, b) => b.score.compareTo(a.score));

    // Appliquer diversité et anti-patterns
    List<UserModel> diversifiedList = _applyDiversification(
      scoredUsers.map((us) => us.user).toList(),
      currentUser,
    );

    return diversifiedList.take(limit).toList();
  }

  static bool _isEligible(UserModel currentUser, UserModel candidate) {
    // Vérifier les préférences de genre
    if (!_matchesGenderPreference(currentUser, candidate)) return false;
    
    // Vérifier l'âge
    if (!_matchesAgePreference(currentUser, candidate)) return false;
    
    // Vérifier si déjà interagi récemment
    if (_hasRecentInteraction(currentUser.id, candidate.id)) return false;
    
    return true;
  }

  static Future<double> _calculateScore(UserModel currentUser, UserModel candidate) async {
    double totalScore = 0.0;

    // Score âge
    double ageScore = _calculateAgeScore(currentUser, candidate);
    totalScore += ageScore * _ageWeight;

    // Score distance
    double distanceScore = _calculateDistanceScore(currentUser, candidate);
    totalScore += distanceScore * _distanceWeight;

    // Score intérêts communs
    double interestsScore = _calculateInterestsScore(currentUser, candidate);
    totalScore += interestsScore * _interestsWeight;

    // Score activité
    double activityScore = _calculateActivityScore(candidate);
    totalScore += activityScore * _activityWeight;

    // Bonus premium
    double premiumScore = candidate.isPremium ? 1.0 : 0.5;
    totalScore += premiumScore * _premiumWeight;

    // Score popularité
    double popularityScore = await _calculatePopularityScore(candidate);
    totalScore += popularityScore * _popularityWeight;

    return min(totalScore, 1.0);
  }

  static double _calculateAgeScore(UserModel currentUser, UserModel candidate) {
    int ageDiff = (currentUser.age - candidate.age).abs();
    if (ageDiff <= 2) return 1.0;
    if (ageDiff <= 5) return 0.8;
    if (ageDiff <= 10) return 0.6;
    if (ageDiff <= 15) return 0.4;
    return 0.2;
  }

  static double _calculateDistanceScore(UserModel currentUser, UserModel candidate) {
    if (currentUser.location == null || candidate.location == null) return 0.5;
    
    double distance = _calculateDistance(
      currentUser.location!.latitude,
      currentUser.location!.longitude,
      candidate.location!.latitude,
      candidate.location!.longitude,
    );

    if (distance <= 5) return 1.0;
    if (distance <= 25) return 0.8;
    if (distance <= 50) return 0.6;
    if (distance <= 100) return 0.4;
    return 0.2;
  }

  static double _calculateInterestsScore(UserModel currentUser, UserModel candidate) {
    Set<String> currentInterests = currentUser.interests.toSet();
    Set<String> candidateInterests = candidate.interests.toSet();
    
    int commonInterests = currentInterests.intersection(candidateInterests).length;
    int totalInterests = currentInterests.union(candidateInterests).length;
    
    return totalInterests > 0 ? commonInterests / totalInterests : 0.0;
  }

  static double _calculateActivityScore(UserModel candidate) {
    DateTime now = DateTime.now();
    Duration timeSinceLastActive = now.difference(candidate.lastActive);
    
    if (timeSinceLastActive.inHours <= 1) return 1.0;
    if (timeSinceLastActive.inHours <= 6) return 0.8;
    if (timeSinceLastActive.inDays <= 1) return 0.6;
    if (timeSinceLastActive.inDays <= 3) return 0.4;
    return 0.2;
  }

  static Future<double> _calculatePopularityScore(UserModel candidate) async {
    // Calculer basé sur les likes reçus, messages, etc.
    final firestore = FirebaseFirestore.instance;
    
    final likesQuery = await firestore
        .collection('likes')
        .where('receiverId', isEqualTo: candidate.id)
        .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
        .get();
    
    int recentLikes = likesQuery.docs.length;
    return min(recentLikes / 50.0, 1.0); // Normaliser sur 50 likes max
  }

  static List<UserModel> _applyDiversification(List<UserModel> users, UserModel currentUser) {
    List<UserModel> diversified = [];
    Set<String> addedInterests = {};
    Set<String> addedLocations = {};
    
    for (UserModel user in users) {
      bool shouldAdd = true;
      
      // Éviter trop d'utilisateurs avec les mêmes intérêts
      String primaryInterest = user.interests.isNotEmpty ? user.interests.first : '';
      if (addedInterests.contains(primaryInterest) && addedInterests.length > 3) {
        shouldAdd = false;
      }
      
      // Diversifier géographiquement
      String location = user.location?.toString() ?? '';
      if (addedLocations.contains(location) && addedLocations.length > 5) {
        shouldAdd = false;
      }
      
      if (shouldAdd) {
        diversified.add(user);
        addedInterests.add(primaryInterest);
        addedLocations.add(location);
      }
      
      if (diversified.length >= 20) break;
    }
    
    return diversified;
  }

  // Fonctions utilitaires
  static bool _matchesGenderPreference(UserModel currentUser, UserModel candidate) {
    return currentUser.genderPreference.contains(candidate.gender) ||
           currentUser.genderPreference.contains('both');
  }

  static bool _matchesAgePreference(UserModel currentUser, UserModel candidate) {
    return candidate.age >= currentUser.minAge && 
           candidate.age <= currentUser.maxAge;
  }

  static bool _hasRecentInteraction(String userId1, String userId2) {
    // À implémenter : vérifier les interactions récentes
    return false;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}

class UserScore {
  final UserModel user;
  final double score;

  UserScore({required this.user, required this.score});
}