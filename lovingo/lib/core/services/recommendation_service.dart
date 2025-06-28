import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../algorithms/recommendation_algorithm.dart';
import 'auth_service.dart';

final recommendationServiceProvider = FutureProvider<List<UserModel>>((ref) async {
  final currentUser = ref.watch(authServiceProvider).user;
  if (currentUser == null) return [];
  
  return await RecommendationAlgorithm.getRecommendations(
    currentUser: currentUser,
    limit: 20,
  );
});

final matchServiceProvider = Provider<MatchService>((ref) {
  return MatchService();
});

class MatchService {
  Future<void> likeUser(String userId) async {
    // TODO: Implémenter la logique de like
  }
  
  Future<void> superLikeUser(String userId) async {
    // TODO: Implémenter la logique de super like
  }
}