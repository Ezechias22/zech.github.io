// lib/core/services/admin_service.dart - SERVICE ADMIN - CORRIGÉ
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart' as geo; // ✅ SOLUTION: Préfixe pour éviter le conflit
import '../models/missing_models.dart'; // ✅ Votre ActivityType sera utilisé par défaut

// ✅ CORRIGÉ : Utiliser AdminStats au lieu de non_type_as_type_argument
final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  return AdminService().getAdminStats();
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ CORRIGÉ : Retourner AdminStats au lieu d'erreur de type
  Future<AdminStats> getAdminStats() async {
    // Données temporaires pour démo - CORRIGÉES
    return AdminStats(
      totalUsers: 1250,
      activeUsers: 850,
      totalRevenue: 5420,
      totalCalls: 2450,
      recentActivities: _generateRecentActivities(),
    );
  }

  // ✅ CORRIGÉ : Retourner List<ChartData> au lieu d'erreur
  List<ChartData> _generateUserActivityData() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return ChartData(
        category: _getDayName(date.weekday),
        value: 800 + (index * 50) + (index % 2 == 0 ? 100 : -50).toDouble(),
      );
    });
  }

  // ✅ CORRIGÉ : Retourner List<ChartData> avec constructeur const
  List<ChartData> _generateRevenueData() {
    return [
      const ChartData(category: 'Premium', value: 65.0),
      const ChartData(category: 'Cadeaux', value: 25.0),
      const ChartData(category: 'Super Likes', value: 10.0),
    ];
  }

  // ✅ CORRIGÉ : Retourner List<AdminActivity> avec enum correct
  List<AdminActivity> _generateRecentActivities() {
    final now = DateTime.now();
    return [
      AdminActivity(
        id: '1',
        type: ActivityType.userRegistration, // ✅ CORRIGÉ : Enum correct
        description: 'Marie, 24 ans s\'est inscrite',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      AdminActivity(
        id: '2',
        type: ActivityType.purchase, // ✅ CORRIGÉ : Enum correct
        description: 'Thomas a acheté Premium 1 mois',
        timestamp: now.subtract(const Duration(minutes: 15)),
      ),
      AdminActivity(
        id: '3',
        type: ActivityType.match, // ✅ CORRIGÉ : Enum correct
        description: 'Sarah et Alex ont matché',
        timestamp: now.subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[weekday - 1];
  }

  // ✅ AJOUT DE MÉTHODES UTILES POUR ADMIN

  // Obtenir les statistiques d'utilisation par pays
  Future<List<ChartData>> getUsageByCountry() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .get();

      final countryCount = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final country = data['location']?['country'] ?? 'Inconnu';
        countryCount[country] = (countryCount[country] ?? 0) + 1;
      }

      return countryCount.entries
          .map((entry) => ChartData(
                category: entry.key,
                value: entry.value.toDouble(),
              ))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    } catch (e) {
      return [];
    }
  }

  // Obtenir les revenus par période
  Future<List<ChartData>> getRevenueByPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final revenueByDay = <String, double>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp).toDate();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final dateKey = '${date.day}/${date.month}';
        
        revenueByDay[dateKey] = (revenueByDay[dateKey] ?? 0.0) + amount;
      }

      return revenueByDay.entries
          .map((entry) => ChartData(
                category: entry.key,
                value: entry.value,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Obtenir les utilisateurs actifs par heure
  Future<List<ChartData>> getActiveUsersByHour() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final snapshot = await _firestore
          .collection('users')
          .where('lastActive', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      final activeByHour = <int, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lastActive = (data['lastActive'] as Timestamp?)?.toDate();
        if (lastActive != null) {
          final hour = lastActive.hour;
          activeByHour[hour] = (activeByHour[hour] ?? 0) + 1;
        }
      }

      return List.generate(24, (hour) {
        return ChartData(
          category: '${hour.toString().padLeft(2, '0')}h',
          value: (activeByHour[hour] ?? 0).toDouble(),
        );
      });
    } catch (e) {
      return [];
    }
  }

  // Obtenir les signalements en attente
  Future<List<AdminActivity>> getPendingReports() async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AdminActivity(
          id: doc.id,
          type: ActivityType.reportSubmitted, // ✅ Utilise votre enum
          description: 'Signalement: ${data['reason'] ?? 'Raison inconnue'}',
          timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          userId: data['reportedUserId'],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Bannir un utilisateur
  Future<bool> banUser(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'banned',
        'banReason': reason,
        'bannedAt': FieldValue.serverTimestamp(),
      });

      // Enregistrer l'action admin
      await _firestore.collection('admin_actions').add({
        'type': 'ban_user',
        'targetUserId': userId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Débannir un utilisateur
  Future<bool> unbanUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
        'banReason': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
        'unbannedAt': FieldValue.serverTimestamp(),
      });

      // Enregistrer l'action admin
      await _firestore.collection('admin_actions').add({
        'type': 'unban_user',
        'targetUserId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Obtenir les métriques en temps réel
  Stream<AdminStats> getRealTimeStats() {
    return _firestore
        .collection('app_metrics')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return AdminStats(
          totalUsers: 0,
          activeUsers: 0,
          totalRevenue: 0,
          totalCalls: 0,
          recentActivities: [],
        );
      }

      final data = doc.data()!;
      return AdminStats(
        totalUsers: data['totalUsers'] ?? 0,
        activeUsers: data['activeUsers'] ?? 0,
        totalRevenue: (data['totalRevenue'] ?? 0).toInt(),
        totalCalls: data['totalCalls'] ?? 0,
        recentActivities: _generateRecentActivities(),
      );
    });
  }

  // Mettre à jour les métriques
  Future<void> updateMetrics() async {
    try {
      // Compter les utilisateurs totaux
      final usersSnapshot = await _firestore.collection('users').count().get();
      final totalUsers = usersSnapshot.count ?? 0;

      // Compter les utilisateurs actifs (dernières 24h)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final activeUsersSnapshot = await _firestore
          .collection('users')
          .where('lastActive', isGreaterThan: Timestamp.fromDate(yesterday))
          .count()
          .get();
      final activeUsers = activeUsersSnapshot.count ?? 0;

      // Calculer le revenu total
      final revenueSnapshot = await _firestore.collection('transactions').get();
      double totalRevenue = 0;
      for (final doc in revenueSnapshot.docs) {
        final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0;
        totalRevenue += amount;
      }

      // Compter les appels totaux
      final callsSnapshot = await _firestore.collection('call_history').count().get();
      final totalCalls = callsSnapshot.count ?? 0;

      // Mettre à jour le document de métriques
      await _firestore.collection('app_metrics').doc('current').set({
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'totalRevenue': totalRevenue,
        'totalCalls': totalCalls,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log error
    }
  }

  // ✅ BONUS: Méthode pour utiliser geolocator si nécessaire
  Future<geo.Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return null;
      }

      if (permission == geo.LocationPermission.deniedForever) return null;

      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }
}