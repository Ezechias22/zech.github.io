// lib/features/admin/admin_dashboard.dart - CORRIGÉ
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lovingo/core/models/missing_models.dart';
import 'package:lovingo/core/services/auth_service.dart';
import 'package:lovingo/features/admin/admin_dialogs.dart';
import '../../core/services/admin_service.dart';
import '../../core/providers/providers.dart'; // ✅ AJOUTÉ

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminStats = ref.watch(adminStatsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: adminStats.when(
        data: (stats) => AnimationLimiter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statistiques principales
                AnimationConfiguration.staggeredList(
                  position: 0,
                  child: SlideAnimation(
                    verticalOffset: 50,
                    child: FadeInAnimation(
                      child: _buildStatsGrid(stats),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Graphiques
                AnimationConfiguration.staggeredList(
                  position: 1,
                  child: SlideAnimation(
                    verticalOffset: 50,
                    child: FadeInAnimation(
                      child: _buildChartsSection(stats),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Actions rapides
                AnimationConfiguration.staggeredList(
                  position: 2,
                  child: SlideAnimation(
                    verticalOffset: 50,
                    child: FadeInAnimation(
                      child: _buildQuickActions(context),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Activité récente
                AnimationConfiguration.staggeredList(
                  position: 3,
                  child: SlideAnimation(
                    verticalOffset: 50,
                    child: FadeInAnimation(
                      child: _buildRecentActivity(stats.recentActivities),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text('Erreur: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(adminStatsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(AdminStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        AdminStatCardSimple(
          title: 'Utilisateurs Actifs',
          value: stats.activeUsers.toString(),
          icon: Icons.people,
          color: Colors.blue,
        ),
        AdminStatCardSimple(
          title: 'Revenus du Jour',
          value: '${stats.totalRevenue.toStringAsFixed(2)}€',
          icon: Icons.euro,
          color: Colors.green,
        ),
        AdminStatCardSimple(
          title: 'Total Appels',
          value: stats.totalCalls.toString(),
          icon: Icons.call,
          color: Colors.red,
        ),
        AdminStatCardSimple(
          title: 'Total Utilisateurs',
          value: stats.totalUsers.toString(),
          icon: Icons.group,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildChartsSection(AdminStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analyses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: AdminChartSimple(
            title: 'Statistiques Générales',
            data: [
              ChartData(category: 'Utilisateurs', value: stats.totalUsers.toDouble()),
              ChartData(category: 'Revenus', value: stats.totalRevenue.toDouble()),
              ChartData(category: 'Appels', value: stats.totalCalls.toDouble()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions Rapides',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              title: 'Utilisateurs',
              icon: Icons.people_alt,
              color: Colors.blue,
              onTap: () => _showTemporaryDialog(context, 'Gestion Utilisateurs'),
            ),
            _buildActionCard(
              title: 'Modération',
              icon: Icons.shield,
              color: Colors.orange,
              onTap: () => _showTemporaryDialog(context, 'Modération de Contenu'),
            ),
            _buildActionCard(
              title: 'Finances',
              icon: Icons.analytics,
              color: Colors.green,
              onTap: () => _showTemporaryDialog(context, 'Analyses Financières'),
            ),
            _buildActionCard(
              title: 'Notifications',
              icon: Icons.notifications,
              color: Colors.purple,
              onTap: () => _showNotificationDialog(context),
            ),
            _buildActionCard(
              title: 'Paramètres',
              icon: Icons.settings,
              color: Colors.grey,
              onTap: () => _showSettingsDialog(context),
            ),
            _buildActionCard(
              title: 'Support',
              icon: Icons.support_agent,
              color: Colors.teal,
              onTap: () => _showSupportDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: color.withOpacity(0.3),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<AdminActivity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activité Récente',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                leading: Icon(
                  _getActivityIcon(activity.type),
                  color: _getActivityColor(activity.type),
                ),
                title: Text(activity.title),
                subtitle: Text(activity.description),
                trailing: Text(
                  _formatTime(activity.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.userRegistration:
        return Icons.person_add;
      case ActivityType.purchase:
        return Icons.shopping_cart;
      case ActivityType.report:
        return Icons.report;
      case ActivityType.match:
        return Icons.favorite;
      case ActivityType.gift:
        return Icons.card_giftcard;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.userRegistration:
        return Colors.green;
      case ActivityType.purchase:
        return Colors.blue;
      case ActivityType.report:
        return Colors.red;
      case ActivityType.match:
        return Colors.pink;
      case ActivityType.gift:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}j';
    }
  }

  void _showTemporaryDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('$title à implémenter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NotificationDialog(),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AdminSettingsDialog(),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SupportTicketsDialog(),
    );
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              // ✅ CORRIGÉ : Utiliser le bon provider
              ref.read(authServiceProvider.notifier).signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}

// ✅ WIDGETS SIMPLIFIÉS TEMPORAIRES

class AdminStatCardSimple extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const AdminStatCardSimple({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              value, 
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title, 
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminChartSimple extends StatelessWidget {
  final String title;
  final List<ChartData> data;

  const AdminChartSimple({
    super.key,
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            title, 
            style: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(item.category),
                      ),
                      Expanded(
                        flex: 3,
                        child: LinearProgressIndicator(
                          value: item.value / data.map((e) => e.value).reduce((a, b) => a > b ? a : b),
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.value.toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}