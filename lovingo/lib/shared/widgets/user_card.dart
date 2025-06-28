import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ AJOUT
import '../../core/models/user_model.dart';
import '../../features/user_details/user_details_screen.dart';
import 'swipe_cards.dart';
import '../../features/calls/providers/call_provider.dart';

class UserCard extends ConsumerStatefulWidget { // ✅ MODIFIÉ : StatefulWidget -> ConsumerStatefulWidget
  final UserModel user;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onSuperLike;

  const UserCard({
    super.key,
    required this.user,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSuperLike,
  });

  @override
  ConsumerState<UserCard> createState() => _UserCardState(); // ✅ MODIFIÉ : State -> ConsumerState
}

class _UserCardState extends ConsumerState<UserCard> // ✅ MODIFIÉ : State -> ConsumerState
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _callButtonsController; // ✅ AJOUT
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _callButtonsAnimation; // ✅ AJOUT
  
  int _currentPhotoIndex = 0;
  PageController _pageController = PageController();
  bool _showCallButtons = false; // ✅ AJOUT

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // ✅ AJOUT NOUVEAU CONTROLLER POUR BOUTONS APPEL
    _callButtonsController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // ✅ AJOUT ANIMATION POUR BOUTONS APPEL
    _callButtonsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _callButtonsController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider); // ✅ AJOUT ÉCOUTE ÉTAT APPELS
    
    return GestureDetector(
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTap: () => _showUserDetails(context),
      onLongPress: _toggleCallButtons, // ✅ AJOUT APPUI LONG
      child: AnimatedBuilder(
        animation: Listenable.merge([_slideController, _scaleController]),
        builder: (context, child) {
          return Transform.translate(
            offset: _slideAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      spreadRadius: 2,
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Photos en arrière-plan
                      _buildPhotoCarousel(),
                      
                      // Gradient overlay
                      _buildGradientOverlay(),
                      
                      // Photo indicators
                      _buildPhotoIndicators(),
                      
                      // User info
                      _buildUserInfo(),
                      
                      // Action buttons
                      _buildActionButtons(),
                      
                      // ✅ AJOUT BOUTONS D'APPEL
                      if (_showCallButtons) _buildCallButtons(callState),
                      
                      // Premium badge
                      if (widget.user.isPremium) _buildPremiumBadge(),
                      
                      // Online indicator
                      if (widget.user.isOnline) _buildOnlineIndicator(),
                      
                      // ✅ AJOUT INDICATEUR APPEL EN COURS
                      if (callState.isInCall) _buildCallIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ AJOUT NOUVEAUX BOUTONS D'APPEL
  Widget _buildCallButtons(CallState callState) {
    return AnimatedBuilder(
      animation: _callButtonsAnimation,
      builder: (context, child) {
        return Positioned(
          top: 80, // Positionné en dessous des indicateurs
          right: 20,
          child: Transform.scale(
            scale: _callButtonsAnimation.value,
            child: Column(
              children: [
                // Bouton appel audio
                _buildFloatingCallButton(
                  icon: Icons.phone,
                  color: Colors.green,
                  onTap: () => _initiateAudioCall(callState),
                  label: 'Audio',
                  isDisabled: !callState.canMakeCall,
                ),
                
                const SizedBox(height: 12),
                
                // Bouton appel vidéo
                _buildFloatingCallButton(
                  icon: Icons.videocam,
                  color: Colors.blue,
                  onTap: () => _initiateVideoCall(callState),
                  label: 'Vidéo',
                  isDisabled: !callState.canMakeCall,
                ),
                
                const SizedBox(height: 12),
                
                // Bouton fermer
                _buildFloatingCallButton(
                  icon: Icons.close,
                  color: Colors.grey,
                  onTap: _toggleCallButtons,
                  label: 'Fermer',
                  isSmall: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    bool isDisabled = false,
    bool isSmall = false,
  }) {
    final size = isSmall ? 40.0 : 55.0;
    final iconSize = isSmall ? 20.0 : 25.0;
    
    return Column(
      children: [
        GestureDetector(
          onTap: isDisabled ? null : onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey[400] : color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDisabled ? Colors.grey : color).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ AJOUT INDICATEUR D'APPEL EN COURS
  Widget _buildCallIndicator() {
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phone_in_talk,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'EN APPEL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ AJOUT MÉTHODES D'APPEL
  void _toggleCallButtons() {
    setState(() {
      _showCallButtons = !_showCallButtons;
    });
    
    if (_showCallButtons) {
      _callButtonsController.forward();
    } else {
      _callButtonsController.reverse();
    }
  }

  void _initiateAudioCall(CallState callState) async {
    if (!callState.canMakeCall) {
      _showSnackBar('Impossible de passer un appel maintenant');
      return;
    }

    _toggleCallButtons(); // Fermer les boutons
    
    try {
      final success = await ref.read(callProvider.notifier).initiateAudioCall(
        otherUser: widget.user,
        context: context,
      );
      
      if (!success) {
        _showSnackBar('Impossible d\'initier l\'appel audio');
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'appel: $e');
    }
  }

  void _initiateVideoCall(CallState callState) async {
    if (!callState.canMakeCall) {
      _showSnackBar('Impossible de passer un appel maintenant');
      return;
    }

    _toggleCallButtons(); // Fermer les boutons
    
    try {
      final success = await ref.read(callProvider.notifier).initiateVideoCall(
        otherUser: widget.user,
        context: context,
      );
      
      if (!success) {
        _showSnackBar('Impossible d\'initier l\'appel vidéo');
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'appel: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ✅ RESTE DE VOTRE CODE ORIGINAL INCHANGÉ
  Widget _buildPhotoCarousel() {
    if (widget.user.photos.isEmpty) {
      return Container(
        height: double.infinity,
        color: Colors.grey[300],
        child: Center(
          child: Icon(
            Icons.person,
            size: 100,
            color: Colors.grey[500],
          ),
        ),
      );
    }

    return SizedBox(
      height: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPhotoIndex = index;
          });
        },
        itemCount: widget.user.photos.length,
        itemBuilder: (context, index) {
          return CachedNetworkImage(
            imageUrl: widget.user.photos[index],
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(
                Icons.error,
                color: Colors.red,
                size: 50,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoIndicators() {
    if (widget.user.photos.length <= 1) return const SizedBox();
    
    return Positioned(
      top: 20,
      left: 20,
      right: 80, // ✅ MODIFIÉ pour laisser place aux boutons appel
      child: Row(
        children: List.generate(
          widget.user.photos.length,
          (index) => Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: _currentPhotoIndex == index
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Positioned(
      bottom: 80,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.user.age}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.user.bio.isNotEmpty)
            Text(
              widget.user.bio,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          if (widget.user.location != null)
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.user.location!.city ?? 'Ville inconnue'} • À proximité',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass button
          _buildActionButton(
            icon: Icons.close,
            color: Colors.grey,
            size: 50,
            onTap: widget.onSwipeLeft,
          ),
          
          // Super like button
          _buildActionButton(
            icon: Icons.star,
            color: Colors.blue,
            size: 60,
            onTap: widget.onSuperLike,
            isPremium: true,
          ),
          
          // Like button
          _buildActionButton(
            icon: Icons.favorite,
            color: Colors.pink,
            size: 50,
            onTap: widget.onSwipeRight,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                icon,
                color: color,
                size: size * 0.4,
              ),
            ),
            if (isPremium)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD700), // Or
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Positioned(
      top: 200, // ✅ MODIFIÉ pour éviter les boutons appel
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFB300)], // Or
          ),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    return Positioned(
      top: 240, // ✅ MODIFIÉ pour éviter les boutons appel
      right: 20,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 4,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    if (delta.abs() > 5) {
      _scaleController.forward();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _scaleController.reverse();
    
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity > 300) {
      _slideController.forward().then((_) {
        widget.onSwipeRight();
      });
    } else if (velocity < -300) {
      _slideController.forward().then((_) {
        widget.onSwipeLeft();
      });
    }
  }

  void _showUserDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserDetailsScreen(user: widget.user),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _callButtonsController.dispose(); // ✅ AJOUT
    _pageController.dispose();
    super.dispose();
  }
}