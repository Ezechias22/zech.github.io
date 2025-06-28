// lib/features/home/home_screen.dart - CORRIGÉ AVEC VRAI SYSTÈME LIVE
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lovingo/core/services/auth_service.dart';
import 'package:lovingo/core/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/user_model.dart';
import '../../core/models/live_models.dart';
import '../../core/providers/providers.dart';
import '../../shared/themes/app_theme.dart';

// ✅ IMPORTS DE VOS VRAIS ÉCRANS
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../calls/live_streaming_screen.dart';
import '../../shared/widgets/user_card.dart';
import '../../shared/widgets/filter_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _giftButtonController;
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _giftButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          DiscoveryPage(),              // Votre page découverte
          ChatListScreen(),            // ✅ VOTRE VRAI ÉCRAN CHAT
          LiveHomePage(),              // ✅ PAGE D'ACCUEIL LIVE
          ProfileScreen(),             // ✅ VOTRE VRAI ÉCRAN PROFIL
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingGiftButton(
              key: const Key('discovery_gift_button'),
              animationController: _giftButtonController,
              onPressed: _showGiftSelection,
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Découvrir',
          ),
          BottomNavigationBarItem(
            icon: _buildChatIcon(),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: 'Live',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildChatIcon() {
    final currentUser = ref.watch(currentUserProvider);
    
    if (currentUser == null) {
      return const Icon(Icons.chat);
    }

    return Consumer(
      builder: (context, ref, child) {
        return FutureBuilder<int>(
          future: _getUnreadCount(currentUser.id),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Stack(
              children: [
                const Icon(Icons.chat),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<int> _getUnreadCount(String userId) async {
    try {
      final chatService = ref.read(chatServiceProvider);
      return chatService.getUnreadMessagesCount(userId).first;
    } catch (e) {
      return 0;
    }
  }

  void _showGiftSelection() {
    _giftButtonController.forward().then((_) {
      _giftButtonController.reverse();
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelectionSheetSimple(
        onGiftSelected: (giftId, quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cadeau envoyé: $giftId x$quantity')),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _giftButtonController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

// ✅ PAGE D'ACCUEIL LIVE AVEC VOS VRAIS SERVICES
class LiveHomePage extends ConsumerStatefulWidget {
  const LiveHomePage({super.key});

  @override
  ConsumerState<LiveHomePage> createState() => _LiveHomePageState();
}

class _LiveHomePageState extends ConsumerState<LiveHomePage> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: _showLiveSettings,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF6B9D),
              Color(0xFFC44FC8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Section Lives en cours
              Expanded(
                flex: 3,
                child: _buildActiveLives(),
              ),
              
              // Section Actions rapides
              Expanded(
                flex: 1,
                child: _buildQuickActions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveLives() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lives en cours',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildLivesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLivesList() {
    // ✅ UTILISATION DES VRAIES DONNÉES FIREBASE
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live_rooms')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyLivesState();
        }

        final lives = snapshot.data!.docs.map((doc) {
          try {
            return LiveRoom.fromFirestore(doc);
          } catch (e) {
            debugPrint('Erreur parsing live: $e');
            return null;
          }
        }).where((live) => live != null).cast<LiveRoom>().toList();

        if (lives.isEmpty) {
          return _buildEmptyLivesState();
        }

        return ListView.builder(
          itemCount: lives.length,
          itemBuilder: (context, index) {
            final live = lives[index];
            return _buildLiveCard(live);
          },
        );
      },
    );
  }

  Widget _buildLiveCard(LiveRoom live) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[300],
              child: Text(
                live.title.isNotEmpty ? live.title[0].toUpperCase() : 'L',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          live.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.visibility, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              '${live.viewerCount} spectateurs',
              style: const TextStyle(color: Colors.white70),
            ),
            if (live.guestCount > 0) ...[
              const SizedBox(width: 10),
              const Icon(Icons.people, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                '${live.guestCount} invités',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _joinLive(live),
      ),
    );
  }

  Widget _buildEmptyLivesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 80,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun live en cours',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Soyez le premier à démarrer un live !',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Bouton Démarrer un Live
          Expanded(
            child: _buildActionButton(
              icon: Icons.video_call,
              label: 'Démarrer Live',
              color: Colors.red,
              onTap: _startLive,
            ),
          ),
          const SizedBox(width: 16),
          
          // Bouton Rejoindre via code
          Expanded(
            child: _buildActionButton(
              icon: Icons.qr_code_scanner,
              label: 'Code Live',
              color: Colors.blue,
              onTap: _joinByCode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startLive() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour démarrer un live'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Démarrer un Live'),
        content: const Text('Voulez-vous démarrer un live maintenant ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // ✅ NAVIGATION VERS VOTRE VRAI LiveStreamingScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LiveStreamingScreen(
                    isHost: true, // ✅ Mode host
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Démarrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _joinByCode() {
    final TextEditingController codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejoindre un Live'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: 'Entrez le code du live',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (codeController.text.isNotEmpty) {
                // ✅ NAVIGATION VERS VOTRE VRAI LiveStreamingScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveStreamingScreen(
                      liveId: codeController.text,
                      isHost: false, // ✅ Mode viewer
                    ),
                  ),
                );
              }
            },
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }

  void _joinLive(LiveRoom live) {
    // ✅ NAVIGATION VERS VOTRE VRAI LiveStreamingScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamingScreen(
          liveId: live.id,
          isHost: false, // ✅ Mode viewer
          title: live.title,
          description: live.description,
        ),
      ),
    );
  }

  void _showLiveSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: const Text(
                'Paramètres Live',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.video_settings),
                    title: const Text('Qualité vidéo'),
                    subtitle: const Text('HD 720p'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implémenter changement qualité
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Notifications de nouveaux lives'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {
                        // TODO: Implémenter paramètres notifications
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Confidentialité'),
                    subtitle: const Text('Gérer qui peut voir vos lives'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implémenter paramètres confidentialité
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Historique des lives'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implémenter historique
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PAGE DE DÉCOUVERTE
class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage> {
  @override
  void initState() {
    super.initState();
    // ✅ FORCER LE RECHARGEMENT DES UTILISATEURS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryServiceProvider.notifier).loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryServiceProvider);
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Découvrir',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            if (currentUser != null)
              GestureDetector(
                onTap: () {
                  final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                  homeState?._pageController.animateToPage(
                    3,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: currentUser.photos.isNotEmpty
                      ? NetworkImage(currentUser.photos.first)
                      : null,
                  child: currentUser.photos.isEmpty
                      ? Text(
                          currentUser.name.isNotEmpty 
                              ? currentUser.name[0].toUpperCase() 
                              : '?',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: discoveryState.users.isEmpty
            ? _buildEmptyDiscoveryState()
            : Stack(
                children: [
                  ...discoveryState.users.asMap().entries.map((entry) {
                    final index = entry.key;
                    final user = entry.value;
                    
                    return Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20 + (index * 10),
                          bottom: 120,
                        ),
                        child: UserCard(
                          user: user,
                          onSwipeLeft: () => _handleSwipe(user, false),
                          onSwipeRight: () => _handleSwipe(user, true),
                          onSuperLike: () => _handleSuperLike(user),
                        ),
                      ),
                    );
                  }).toList().reversed.toList(),
                  
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: _buildActionButtons(),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildEmptyDiscoveryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.explore, size: 100, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Aucun utilisateur à découvrir',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revenez plus tard pour de nouveaux profils',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ref.read(discoveryServiceProvider.notifier).loadUsers();
            },
            child: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.close,
            color: Colors.grey,
            onTap: () {
              final discoveryState = ref.read(discoveryServiceProvider);
              if (discoveryState.users.isNotEmpty) {
                _handleSwipe(discoveryState.users.first, false);
              }
            },
          ),
          _buildActionButton(
            icon: Icons.star,
            color: Colors.blue,
            onTap: () {
              final discoveryState = ref.read(discoveryServiceProvider);
              if (discoveryState.users.isNotEmpty) {
                _handleSuperLike(discoveryState.users.first);
              }
            },
          ),
          _buildActionButton(
            icon: Icons.favorite,
            color: Colors.pink,
            onTap: () {
              final discoveryState = ref.read(discoveryServiceProvider);
              if (discoveryState.users.isNotEmpty) {
                _handleSwipe(discoveryState.users.first, true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  void _handleSwipe(UserModel user, bool isLike) {
    ref.read(discoveryServiceProvider.notifier).swipeUser(user.id, isLike);
    if (isLike) _showMatchAnimation();
  }

  void _handleSuperLike(UserModel user) {
    ref.read(discoveryServiceProvider.notifier).superLikeUser(user.id);
    _showSuperLikeAnimation();
  }

  void _showMatchAnimation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white),
            SizedBox(width: 8),
            Text('Liked!'),
          ],
        ),
        backgroundColor: Colors.pink,
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  void _showSuperLikeAnimation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.star, color: Colors.white),
            SizedBox(width: 8),
            Text('Super Like!'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        onFiltersApplied: (filters) {
          ref.read(discoveryServiceProvider.notifier).applyFilters(filters);
        },
      ),
    );
  }
}

// WIDGETS UTILITAIRES
class FloatingGiftButton extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onPressed;
  final Key? key;

  const FloatingGiftButton({
    this.key,
    required this.animationController,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "discovery_gift_button", // ✅ HERO TAG UNIQUE
      onPressed: onPressed,
      backgroundColor: AppTheme.primaryColor,
      child: const Icon(Icons.card_giftcard),
    );
  }
}

class GiftSelectionSheetSimple extends StatelessWidget {
  final Function(String giftId, int quantity) onGiftSelected;

  const GiftSelectionSheetSimple({
    super.key,
    required this.onGiftSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sélectionner un cadeau',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              children: [
                _buildGiftItem('🌹', 'Rose', 10),
                _buildGiftItem('❤️', 'Cœur', 5),
                _buildGiftItem('💎', 'Diamant', 100),
                _buildGiftItem('👑', 'Couronne', 500),
                _buildGiftItem('🏎️', 'Ferrari', 1000),
                _buildGiftItem('🎁', 'Surprise', 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftItem(String emoji, String name, int price) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          onGiftSelected(name.toLowerCase(), 1);
          Navigator.pop(context);
        },
        child: Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              Text(name, style: const TextStyle(fontSize: 12)),
              Text('$price', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}