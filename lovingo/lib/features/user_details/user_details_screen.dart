import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/user_model.dart';
import '../../core/services/discovery_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../shared/themes/app_theme.dart';
import '../chat/chat_screen.dart';

class UserDetailsScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const UserDetailsScreen({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _slideController;
  late AnimationController _actionController;
  late AnimationController _heartController;
  
  int _currentMediaIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _slideController = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );
    _actionController = AnimationController(
      duration: AppTheme.fastAnimation,
      vsync: this,
    );
    _heartController = AnimationController(
      duration: AppTheme.slowAnimation,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMedia = [...widget.user.photos, ...widget.user.videos];
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media carousel
          _buildMediaCarousel(allMedia),
          
          // Gradient overlay
          _buildGradientOverlay(),
          
          // Header with close button
          _buildHeader(),
          
          // Media indicators
          if (allMedia.length > 1) _buildMediaIndicators(allMedia.length),
          
          // Content
          _buildUserContent(),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildMediaCarousel(List<String> allMedia) {
    return Positioned.fill(
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentMediaIndex = index;
            _disposeVideoController();
            
            // Si c'est une vidéo, initialiser le lecteur
            if (index >= widget.user.photos.length) {
              final videoIndex = index - widget.user.photos.length;
              if (videoIndex < widget.user.videos.length) {
                _initializeVideoController(widget.user.videos[videoIndex]);
              }
            }
          });
        },
        itemCount: allMedia.length,
        itemBuilder: (context, index) {
          // Photo
          if (index < widget.user.photos.length) {
            return _buildPhotoViewer(widget.user.photos[index]);
          }
          
          // Vidéo
          final videoIndex = index - widget.user.photos.length;
          if (videoIndex < widget.user.videos.length) {
            return _buildVideoViewer(widget.user.videos[videoIndex]);
          }
          
          return Container();
        },
      ),
    );
  }

  Widget _buildPhotoViewer(String photoUrl) {
    return GestureDetector(
      onTap: () => _showFullScreenMedia(photoUrl, isVideo: false),
      child: Hero(
        tag: 'photo_$photoUrl',
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[900],
            child: const Icon(
              Icons.error,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoViewer(String videoUrl) {
    return Stack(
      children: [
        if (_videoController != null && _videoController!.value.isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          )
        else
          Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
        
        // Play/Pause button
        Center(
          child: GestureDetector(
            onTap: _toggleVideoPlayback,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ],
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
              Colors.black.withOpacity(0.3),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
            ),
          ),
          
          // Premium badge
          if (widget.user.isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 16),
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
          
          // More options
          GestureDetector(
            onTap: _showMoreOptions,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.more_vert,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaIndicators(int mediaCount) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 20,
      right: 20,
      child: Row(
        children: List.generate(
          mediaCount,
          (index) => Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: _currentMediaIndex == index
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

  Widget _buildUserContent() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom et âge
              Row(
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.user.age}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const Spacer(),
                  if (widget.user.isOnline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'En ligne',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Localisation
              if (widget.user.location != null)
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.user.location!.city ?? 'Ville inconnue'}, ${widget.user.location!.country ?? 'Pays inconnu'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              // Bio
              if (widget.user.bio.isNotEmpty)
                Text(
                  widget.user.bio,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Intérêts
              if (widget.user.interests.isNotEmpty) ...[
                const Text(
                  'Centres d\'intérêt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.user.interests.map((interest) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Vues', widget.user.stats.profileViews.toString()),
                  _buildStatItem('Matches', widget.user.stats.totalMatches.toString()),
                  _buildStatItem('Likes', widget.user.stats.totalLikes.toString()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Bouton Passer
            _buildActionButton(
              icon: Icons.close,
              color: Colors.grey,
              size: 50,
              onTap: _handlePass,
            ),
            
            // Bouton Chat
            _buildActionButton(
              icon: Icons.chat,
              color: AppTheme.primaryColor,
              size: 55,
              onTap: _handleChat,
            ),
            
            // Bouton Super Like
            _buildActionButton(
              icon: Icons.star,
              color: Colors.blue,
              size: 50,
              onTap: _handleSuperLike,
            ),
            
            // Bouton Like
            _buildActionButton(
              icon: Icons.favorite,
              color: Colors.pink,
              size: 60,
              onTap: _handleLike,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
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
              blurRadius: 15,
              color: Colors.black.withOpacity(0.3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.4,
        ),
      ),
    );
  }

  // Actions
  void _handlePass() {
    _actionController.forward().then((_) {
      if (mounted) {
        ref.read(discoveryServiceProvider.notifier).swipeUser(widget.user.id, false);
        Navigator.of(context).pop();
      }
    });
  }

  void _handleLike() {
    _heartController.forward();
    _actionController.forward().then((_) {
      if (mounted) {
        ref.read(discoveryServiceProvider.notifier).swipeUser(widget.user.id, true);
        Navigator.of(context).pop();
        _showMatchDialog();
      }
    });
  }

  void _handleSuperLike() {
    _actionController.forward().then((_) {
      if (mounted) {
        ref.read(discoveryServiceProvider.notifier).superLikeUser(widget.user.id);
        Navigator.of(context).pop();
        _showSuperLikeDialog();
      }
    });
  }

  Future<void> _handleChat() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !mounted) return;
    
    try {
      // Créer ou récupérer la conversation en utilisant votre ChatService existant
      final chatRoomId = await ref.read(chatServiceProvider).createChatRoom(
        widget.user.id,
        currentUser.id,
      );
      
      // Naviguer vers l'écran de chat
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoomId,
              otherUser: widget.user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture du chat: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showMatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('C\'est un match !'),
        content: Text('Vous et ${widget.user.name} vous êtes mutuellement likés !'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleChat();
            },
            child: const Text('Envoyer un message'),
          ),
        ],
      ),
    );
  }

  void _showSuperLikeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Super Like envoyé !'),
        content: Text('${widget.user.name} sera notifié(e) de votre Super Like.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Signaler'),
              onTap: () {
                Navigator.of(context).pop();
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Bloquer'),
              onTap: () {
                Navigator.of(context).pop();
                _showBlockDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler ce profil'),
        content: const Text('Voulez-vous vraiment signaler ce profil ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Ici vous pouvez implémenter la logique de signalement
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil signalé')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquer ce profil'),
        content: const Text('Voulez-vous vraiment bloquer ce profil ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Retour à la découverte
              // Ici vous pouvez implémenter la logique de blocage
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil bloqué')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
  }

  void _showFullScreenMedia(String url, {required bool isVideo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMediaViewer(
          url: url,
          isVideo: isVideo,
        ),
      ),
    );
  }

  void _initializeVideoController(String videoUrl) {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  void _toggleVideoPlayback() {
    if (_videoController == null) return;
    
    setState(() {
      if (_isVideoPlaying) {
        _videoController!.pause();
        _isVideoPlaying = false;
      } else {
        _videoController!.play();
        _isVideoPlaying = true;
      }
    });
  }

  void _disposeVideoController() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoPlaying = false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _actionController.dispose();
    _heartController.dispose();
    _disposeVideoController();
    super.dispose();
  }
}

// Widget pour afficher les médias en plein écran
class FullScreenMediaViewer extends StatefulWidget {
  final String url;
  final bool isVideo;

  const FullScreenMediaViewer({
    super.key,
    required this.url,
    required this.isVideo,
  });

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: widget.isVideo
            ? (_videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const CircularProgressIndicator())
            : Hero(
                tag: 'photo_${widget.url}',
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: widget.url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}