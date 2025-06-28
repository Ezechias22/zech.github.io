// lib/features/calls/call_history_screen.dart - ÉCRAN HISTORIQUE APPELS CORRIGÉ
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/webrtc_config.dart';
import '../../core/models/call_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import './providers/call_provider.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen>
    with TickerProviderStateMixin {
  
  // Filtres
  CallHistoryFilter _currentFilter = CallHistoryFilter.all;
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Animation
  late TabController _tabController;
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WebRTCConfig.logInfo('📞 Écran historique appels initialisé');
  }

  @override
  Widget build(BuildContext context) {
    final callHistoryAsync = ref.watch(callHistoryProvider);
    final callStatsAsync = ref.watch(callStatsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Historique d\'appels'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _toggleStats,
            icon: Icon(_showStats ? Icons.bar_chart_outlined : Icons.bar_chart),
          ),
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Exporter'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Tout effacer'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),
          
          // Filtres rapides
          _buildQuickFilters(),
          
          // Statistiques (si activées)
          if (_showStats) _buildStatsSection(callStatsAsync),
          
          // Liste des appels
          Expanded(
            child: _buildCallsList(callHistoryAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un contact...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      height: 50,
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.blue,
        tabs: const [
          Tab(text: 'Tous'),
          Tab(text: 'Entrants'),
          Tab(text: 'Sortants'),
          Tab(text: 'Manqués'),
          Tab(text: 'Vidéo'),
          Tab(text: 'Audio'),
        ],
        onTap: (index) {
          setState(() {
            _currentFilter = CallHistoryFilter.values[index];
          });
        },
      ),
    );
  }

  Widget _buildStatsSection(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: statsAsync.when(
        data: (stats) => _buildStatsContent(stats),
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Erreur: $error'),
        ),
      ),
    );
  }

  Widget _buildStatsContent(Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques d\'appels',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard(
                'Total appels',
                '${stats['totalCalls'] ?? 0}',
                Icons.call,
                Colors.blue,
              ),
              _buildStatCard(
                'Appels répondus',
                '${stats['answeredCalls'] ?? 0}',
                Icons.call_received,
                Colors.green,
              ),
              _buildStatCard(
                'Appels manqués',
                '${stats['missedCalls'] ?? 0}',
                Icons.call_missed,
                Colors.red,
              ),
              _buildStatCard(
                'Durée totale',
                '${stats['totalDurationMinutes'] ?? 0}min',
                Icons.timer,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallsList(AsyncValue<List<CallLog>> callHistoryAsync) {
    return callHistoryAsync.when(
      data: (callLogs) {
        final filteredCalls = _filterCalls(callLogs);
        
        if (filteredCalls.isEmpty) {
          return _buildEmptyState();
        }
        
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredCalls.length,
          itemBuilder: (context, index) {
            final callLog = filteredCalls[index];
            return _buildCallItem(callLog);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erreur: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(callHistoryProvider),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.call_end,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun appel trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos appels apparaîtront ici',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallItem(CallLog callLog) {
    return FutureBuilder<UserModel?>(
      future: _getOtherUser(callLog.otherUserId),
      builder: (context, snapshot) {
        final otherUser = snapshot.data;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: _buildCallIcon(callLog),
            title: Text(
              otherUser?.name ?? 'Utilisateur inconnu',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatCallTime(callLog.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (callLog.duration.inSeconds > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Durée: ${_formatDuration(callLog.duration)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showCallOptions(callLog, otherUser),
                  icon: const Icon(Icons.more_vert),
                ),
                IconButton(
                  onPressed: () => _initiateCall(callLog, otherUser),
                  icon: Icon(
                    callLog.type == CallType.video ? Icons.videocam : Icons.call,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallIcon(CallLog callLog) {
    Color color;
    IconData icon;
    
    if (!callLog.wasAnswered) {
      color = Colors.red;
      icon = callLog.isIncoming ? Icons.call_missed : Icons.call_missed_outgoing;
    } else {
      color = callLog.isIncoming ? Colors.green : Colors.blue;
      icon = callLog.isIncoming ? Icons.call_received : Icons.call_made;
    }
    
    if (callLog.type == CallType.video) {
      icon = Icons.videocam;
    }
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  // ✅ MÉTHODES UTILITAIRES

  List<CallLog> _filterCalls(List<CallLog> calls) {
    var filtered = calls.where((call) {
      // Filtre par texte de recherche
      if (_searchQuery.isNotEmpty) {
        // Note: Pour une recherche optimale, vous pourriez mettre en cache les noms d'utilisateurs
        // ou utiliser une recherche Firestore avec index
        return call.otherUserId.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      
      // Filtre par type
      switch (_currentFilter) {
        case CallHistoryFilter.incoming:
          return call.isIncoming;
        case CallHistoryFilter.outgoing:
          return !call.isIncoming;
        case CallHistoryFilter.missed:
          return !call.wasAnswered;
        case CallHistoryFilter.video:
          return call.type == CallType.video;
        case CallHistoryFilter.audio:
          return call.type == CallType.audio;
        case CallHistoryFilter.all:
        default:
          return true;
      }
    }).toList();
    
    // Filtre par date
    if (_dateRange != null) {
      filtered = filtered.where((call) {
        return call.timestamp.isAfter(_dateRange!.start) &&
               call.timestamp.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    
    return filtered;
  }

  Future<UserModel?> _getOtherUser(String userId) async {
    try {
      // ✅ RÉCUPÉRER L'UTILISATEUR DEPUIS FIRESTORE
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        return UserModel.fromMap({
          ...userDoc.data()!,
          'id': userDoc.id,
        });
      }
      
      return null;
    } catch (e) {
      WebRTCConfig.logError('Erreur récupération utilisateur $userId', e);
      return null;
    }
  }

  // ✅ SUPPRIMER UN LOG D'APPEL SPÉCIFIQUE
  Future<void> _deleteCallLog(CallLog callLog) async {
    try {
      await FirebaseFirestore.instance
          .collection('call_logs')
          .doc(callLog.id)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appel supprimé de l\'historique')),
      );
      
      // Rafraîchir la liste
      ref.refresh(callHistoryProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ EFFACER TOUT L'HISTORIQUE
  Future<void> _clearAllHistory() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      final batch = FirebaseFirestore.instance.batch();
      final callLogs = await FirebaseFirestore.instance
          .collection('call_logs')
          .where('participantId', isEqualTo: currentUser.id)
          .get();

      for (final doc in callLogs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historique effacé')),
      );
      
      // Rafraîchir la liste
      ref.refresh(callHistoryProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'effacement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatCallTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Hier ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm', 'fr_FR').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  void _toggleStats() {
    setState(() {
      _showStats = !_showStats;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtres'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Période'),
              subtitle: _dateRange != null
                  ? Text('${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}')
                  : const Text('Toutes les dates'),
              trailing: const Icon(Icons.date_range),
              onTap: _selectDateRange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _dateRange = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Réinitialiser'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportHistory();
        break;
      case 'clear':
        _showClearConfirmation();
        break;
    }
  }

  void _exportHistory() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      // Récupérer tous les logs d'appels
      final callLogs = await FirebaseFirestore.instance
          .collection('call_logs')
          .where('participantId', isEqualTo: currentUser.id)
          .orderBy('timestamp', descending: true)
          .get();

      if (callLogs.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun appel à exporter')),
        );
        return;
      }

      // Pour l'instant, on affiche juste le nombre d'appels
      // L'export vers fichier peut être ajouté plus tard avec des packages comme csv ou share_plus
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${callLogs.docs.length} appels prêts à exporter'),
          action: SnackBarAction(
            label: 'Développer',
            onPressed: () {
              // Ici vous pourriez ajouter l'export CSV/Excel selon vos besoins
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l\'historique'),
        content: const Text('Êtes-vous sûr de vouloir effacer tout l\'historique d\'appels ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllHistory();
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  void _showCallOptions(CallLog callLog, UserModel? otherUser) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.call),
            title: const Text('Appel audio'),
            onTap: () {
              Navigator.pop(context);
              _initiateCall(callLog, otherUser, forceAudio: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Appel vidéo'),
            onTap: () {
              Navigator.pop(context);
              _initiateCall(callLog, otherUser, forceVideo: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Envoyer un message'),
            onTap: () {
              Navigator.pop(context);
              // Naviguer vers le chat (peut être implémenté selon votre structure)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité de chat à connecter')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteCallLog(callLog);
            },
          ),
        ],
      ),
    );
  }

  void _initiateCall(CallLog callLog, UserModel? otherUser, {bool forceAudio = false, bool forceVideo = false}) async {
    if (otherUser == null) return;
    
    try {
      final callNotifier = ref.read(callProvider.notifier);
      
      if (forceVideo || (!forceAudio && callLog.type == CallType.video)) {
        await callNotifier.initiateVideoCall(
          otherUser: otherUser,
          context: context,
        );
      } else {
        await callNotifier.initiateAudioCall(
          otherUser: otherUser,
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'appel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

// ✅ ENUM POUR LES FILTRES
enum CallHistoryFilter {
  all,
  incoming,
  outgoing,
  missed,
  video,
  audio,
}