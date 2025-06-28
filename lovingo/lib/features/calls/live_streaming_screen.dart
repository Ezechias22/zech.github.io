// lib/features/calls/live_streaming_screen.dart - VERSION COMPLÈTEMENT CORRIGÉE
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/live_streaming_service.dart';
import '../../core/services/gift_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/wallet_service.dart' as wallet_service;
import '../../core/models/live_models.dart' as live_models;
import '../../core/models/gift_model.dart';
import '../../core/models/user_model.dart';

class LiveStreamingScreen extends ConsumerStatefulWidget {
  final String? liveId;
  final bool isHost;
  final String? title;
  final String? description;

  const LiveStreamingScreen({
    super.key,
    this.liveId,
    this.isHost = false,
    this.title,
    this.description,
  });

  @override
  ConsumerState<LiveStreamingScreen> createState() => _LiveStreamingScreenState();
}

class _LiveStreamingScreenState extends ConsumerState<LiveStreamingScreen>
    with TickerProviderStateMixin {
  
  // Services
  late LiveStreamingService _liveService;
  late GiftService _giftService;
  late AudioService _audioService;
  
  // Controllers et animations
  late AnimationController _heartController;
  late AnimationController _liveIndicatorController;
  late AnimationController _giftController;
  late AnimationController _beautyFilterController;
  late AnimationController _chatAnimationController;
  late ScrollController _chatController;
  late TextEditingController _messageController;
  
  // État du live
  bool _isLive = false;
  bool _isLoading = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isBeautyFilterEnabled = false;
  bool _isChatVisible = true;
  bool _isRecording = false;
  bool _isScreenSharing = false;
  bool _isInitialized = false;
  
  // Permissions
  bool _cameraPermissionGranted = false;
  bool _microphonePermissionGranted = false;
  
  // Statistiques en temps réel
  int _viewerCount = 0;
  int _guestCount = 0;
  int _heartCount = 0;
  int _giftCount = 0;
  int _messageCount = 0;
  Duration _liveDuration = Duration.zero;
  
  // Listes avec alias
  final List<live_models.LiveGuest> _guests = [];
  final List<live_models.LiveViewer> _viewers = [];
  final List<live_models.LiveMessage> _messages = [];
  final List<live_models.VirtualGift> _recentGifts = [];
  
  // Streams
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  Map<String, MediaStream> _guestStreams = {};
  final Map<String, RTCVideoRenderer> _renderers = {};
  
  // Timers et animations
  Timer? _heartTimer;
  Timer? _statsTimer;
  Timer? _durationTimer;
  Timer? _cleanupTimer;
  final List<Widget> _floatingHearts = [];
  final List<Widget> _floatingGifts = [];
  
  // Configuration et constantes
  static const int maxChatMessages = 100;
  static const int maxFloatingAnimations = 15;
  static const int maxGuests = 4;
  
  // Catégories de cadeaux
  final Map<String, List<String>> _giftCategories = {
    'Populaire': ['heart', 'rose'],
    'Amour': ['heart', 'rose'],
    'Fête': ['crown'],
    'Luxe': ['diamond', 'crown'],
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeControllers();
    _initializeServices();
    _initializeApp();
  }

  void _initializeAnimations() {
    _heartController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _liveIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _giftController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _beautyFilterController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _chatAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  void _initializeControllers() {
    _chatController = ScrollController();
    _messageController = TextEditingController();
  }

  void _initializeServices() {
    _liveService = ref.read(liveStreamingServiceProvider);
    _giftService = GiftService();
    _audioService = AudioService.instance;
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    
    try {
      await _checkPermissions();
      await _initializeRenderers();
      _setupServiceListeners();
      await _startLiveOrJoin();
      
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Erreur d\'initialisation: $e');
      }
    }
  }

  Future<void> _initializeRenderers() async {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    
    setState(() {
      _cameraPermissionGranted = cameraStatus.isGranted;
      _microphonePermissionGranted = micStatus.isGranted;
    });
    
    if (!_cameraPermissionGranted || !_microphonePermissionGranted) {
      await _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    final permissions = <Permission>[];
    if (!_cameraPermissionGranted) permissions.add(Permission.camera);
    if (!_microphonePermissionGranted) permissions.add(Permission.microphone);
    
    final results = await permissions.request();
    
    setState(() {
      _cameraPermissionGranted = results[Permission.camera]?.isGranted ?? false;
      _microphonePermissionGranted = results[Permission.microphone]?.isGranted ?? false;
    });
  }

  void _setupServiceListeners() {
    // Stream des statistiques
    _liveService.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _viewerCount = stats.viewerCount;
          _guestCount = stats.guestCount;
          _heartCount = stats.heartCount;
          _giftCount = stats.giftCount;
          _liveDuration = stats.duration;
        });
        
        _playStatsUpdateSounds();
      }
    });
    
    // Stream des invités
    _liveService.guestsStream.listen((guests) {
      if (mounted) {
        setState(() {
          _guests.clear();
          _guests.addAll(guests);
          _guestStreams = _liveService.guestStreams;
        });
        _updateGuestRenderers();
      }
    });
    
    // Stream des spectateurs
    _liveService.viewersStream.listen((viewers) {
      if (mounted) {
        setState(() {
          _viewers.clear();
          _viewers.addAll(viewers);
        });
      }
    });
    
    // Stream des messages
    _liveService.messagesStream.listen((message) {
      _addMessage(message);
      _messageCount++;
    });
    
    // Stream des cadeaux
    _liveService.giftsStream.listen((gift) {
      _addGiftAnimation(gift);
      _playGiftSound(gift);
    });
    
    // Stream de la room
    _liveService.roomStream.listen((room) {
      if (mounted) {
        setState(() {
          // Mettre à jour les informations de la room
        });
      }
    });
  }

  void _addGiftAnimationFromTransaction(GiftTransaction transaction) {
    final virtualGift = live_models.VirtualGift(
      id: transaction.id,
      giftId: transaction.giftId,
      quantity: transaction.quantity,
      senderId: transaction.senderId,
      senderName: transaction.senderId,
      timestamp: transaction.timestamp,
      liveId: transaction.chatRoomId,
      value: 0,
    );
    _addGiftAnimation(virtualGift);
  }

  void _playStatsUpdateSounds() {
    if (_viewerCount > 0 && _viewerCount % 10 == 0) {
      _audioService.playActionSound(AudioAction.achievement);
    }
  }

  void _playGiftSound(live_models.VirtualGift gift) {
    final giftModel = _giftService.getGiftById(gift.giftId);
    if (giftModel != null) {
      switch (giftModel.rarity) {
        case GiftRarity.common:
          _audioService.playActionSound(AudioAction.giftReceived);
          break;
        case GiftRarity.rare:
          _audioService.playActionSound(AudioAction.achievement);
          break;
        case GiftRarity.epic:
        case GiftRarity.legendary:
          _audioService.playActionSound(AudioAction.combo);
          break;
      }
    }
  }

  void _updateGuestRenderers() {
    for (final guest in _guests) {
      if (!_renderers.containsKey(guest.userId)) {
        final renderer = RTCVideoRenderer();
        renderer.initialize().then((_) {
          final stream = _guestStreams[guest.userId];
          if (stream != null) {
            renderer.srcObject = stream;
          }
        });
        _renderers[guest.userId] = renderer;
      }
    }
    
    final currentGuestIds = _guests.map((g) => g.userId).toSet();
    _renderers.removeWhere((userId, renderer) {
      if (!currentGuestIds.contains(userId)) {
        renderer.dispose();
        return true;
      }
      return false;
    });
  }

  Future<void> _startLiveOrJoin() async {
    if (!mounted) return;
    
    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      if (currentUser == null) {
        _showErrorSnackbar('Utilisateur non connecté');
        return;
      }
      
      if (widget.isHost) {
        final success = await _showStartLiveDialog();
        if (success && mounted) {
          await _initializeLocalStream();
          _isLive = true;
          _startTimers();
          _startCleanupTimer();
          
          _audioService.playActionSound(AudioAction.giftReceived);
          _addSystemMessage('Live démarré ! Bienvenue 👋');
        }
      } else if (widget.liveId != null) {
        final success = await _liveService.joinLiveAsViewer(
          liveId: widget.liveId!,
          viewerId: currentUser.id,
        );
        if (success && mounted) {
          _isLive = true;
          _audioService.playActionSound(AudioAction.giftReceived);
          _addSystemMessage('Vous avez rejoint le live !');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Erreur lors du démarrage du live: $e');
      }
    }
  }

  Future<void> _initializeLocalStream() async {
    try {
      if (!_cameraPermissionGranted || !_microphonePermissionGranted) {
        await _requestPermissions();
      }

      final Map<String, dynamic> mediaConstraints = {
        'audio': _microphonePermissionGranted,
        'video': _cameraPermissionGranted ? {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'optional': [],
        } : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (_localRenderer != null && _localStream != null) {
        _localRenderer!.srcObject = _localStream;
      }

      setState(() {});
    } catch (e) {
      print('Erreur lors de l\'initialisation du stream local: $e');
      _showErrorSnackbar('Erreur lors de l\'accès à la caméra');
    }
  }

  Future<bool> _showStartLiveDialog() async {
    final titleController = TextEditingController(text: widget.title ?? '');
    final descController = TextEditingController(text: widget.description ?? '');
    bool allowGuests = true;
    bool allowChat = true;
    bool allowGifts = true;
    bool enableBeautyFilters = false;
    bool enableRecording = false;
    String selectedCategory = 'Général';
    
    final categories = ['Général', 'Musique', 'Gaming', 'Éducation', 'Lifestyle'];
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('Démarrer le Live'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre du live *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: categories.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                const Text('Paramètres avancés:', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                
                _buildAdvancedSetting(
                  icon: Icons.people,
                  title: 'Autoriser les invités',
                  subtitle: 'Max $maxGuests spectateurs peuvent rejoindre',
                  value: allowGuests,
                  onChanged: (value) => setDialogState(() => allowGuests = value),
                ),
                _buildAdvancedSetting(
                  icon: Icons.chat,
                  title: 'Chat en direct',
                  subtitle: 'Messages en temps réel des spectateurs',
                  value: allowChat,
                  onChanged: (value) => setDialogState(() => allowChat = value),
                ),
                _buildAdvancedSetting(
                  icon: Icons.card_giftcard,
                  title: 'Cadeaux virtuels',
                  subtitle: 'Monétisation avec cadeaux payants',
                  value: allowGifts,
                  onChanged: (value) => setDialogState(() => allowGifts = value),
                ),
                _buildAdvancedSetting(
                  icon: Icons.face,
                  title: 'Filtres de beauté',
                  subtitle: 'Amélioration automatique de l\'image',
                  value: enableBeautyFilters,
                  onChanged: (value) => setDialogState(() => enableBeautyFilters = value),
                ),
                _buildAdvancedSetting(
                  icon: Icons.fiber_manual_record,
                  title: 'Enregistrement automatique',
                  subtitle: 'Sauvegarder le live pour replay',
                  value: enableRecording,
                  onChanged: (value) => setDialogState(() => enableRecording = value),
                ),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Votre live sera visible publiquement. Respectez les règles de la communauté.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: titleController.text.trim().isEmpty ? null : () async {
                final currentUser = ref.read(authServiceProvider).currentUser!;
                
                if (!_cameraPermissionGranted || !_microphonePermissionGranted) {
                  await _requestPermissions();
                  if (!_cameraPermissionGranted || !_microphonePermissionGranted) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Permissions caméra/micro requises'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
                }
                
                final success = await _liveService.startLive(
                  hostId: currentUser.id,
                  title: titleController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  tags: [selectedCategory.toLowerCase(), 'live', 'streaming'],
                  settings: {
                    'allowGuests': allowGuests,
                    'allowChat': allowChat,
                    'allowGifts': allowGifts,
                    'enableBeautyFilters': enableBeautyFilters,
                    'enableRecording': enableRecording,
                    'maxGuests': maxGuests,
                    'chatModeration': true,
                    'category': selectedCategory,
                    'isPublic': true,
                  },
                );
                
                if (context.mounted) {
                  Navigator.pop(context, success);
                }
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Démarrer le Live'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
    
    titleController.dispose();
    descController.dispose();
    return result ?? false;
  }

  Widget _buildAdvancedSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        secondary: Icon(icon, color: value ? Colors.green : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isLive) {
        setState(() {
          _liveDuration = _liveDuration + const Duration(seconds: 1);
        });
      }
    });
    
    _durationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _isLive) {
        // Simuler des mises à jour de statistiques
        setState(() {
          if (_viewerCount == 0) _viewerCount = 1;
          if (math.Random().nextBool()) {
            _viewerCount += math.Random().nextInt(3);
          }
        });
      }
    });
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cleanupAnimations();
      _cleanupOldMessages();
    });
  }

  void _cleanupAnimations() {
    setState(() {
      if (_floatingHearts.length > maxFloatingAnimations) {
        _floatingHearts.removeRange(0, _floatingHearts.length - maxFloatingAnimations);
      }
      if (_floatingGifts.length > maxFloatingAnimations) {
        _floatingGifts.removeRange(0, _floatingGifts.length - maxFloatingAnimations);
      }
    });
  }

  void _cleanupOldMessages() {
    setState(() {
      if (_messages.length > maxChatMessages) {
        _messages.removeRange(0, _messages.length - maxChatMessages);
      }
    });
  }

  void _addMessage(live_models.LiveMessage message) {
    if (mounted) {
      setState(() {
        _messages.add(message);
        if (_messages.length > maxChatMessages) {
          _messages.removeAt(0);
        }
      });
      
      if (_isChatVisible) {
        _chatAnimationController.forward().then((_) {
          _chatAnimationController.reverse();
        });
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatController.hasClients) {
          _chatController.animateTo(
            _chatController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _addSystemMessage(String message) {
    final systemMessage = live_models.LiveMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'system',
      senderName: 'Système',
      message: message,
      timestamp: DateTime.now(),
      type: live_models.LiveMessageType.system,
    );
    _addMessage(systemMessage);
  }

  void _addGiftAnimation(live_models.VirtualGift gift) {
    if (mounted) {
      setState(() {
        _recentGifts.add(gift);
        if (_recentGifts.length > 10) {
          _recentGifts.removeAt(0);
        }
        _giftCount++;
      });
      
      _createFloatingGiftAnimation(gift);
      
      final giftModel = _giftService.getGiftById(gift.giftId);
      if (giftModel != null) {
        final giftMessage = live_models.LiveMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: gift.senderId,
          senderName: gift.senderName,
          message: 'a envoyé ${giftModel.name} ${giftModel.icon} x${gift.quantity}',
          timestamp: DateTime.now(),
          type: live_models.LiveMessageType.gift,
        );
        _addMessage(giftMessage);
      }
    }
  }

  void _createFloatingGiftAnimation(live_models.VirtualGift gift) {
    final giftModel = _giftService.getGiftById(gift.giftId);
    if (giftModel == null) return;
    
    final random = math.Random();
    final startX = random.nextDouble() * MediaQuery.of(context).size.width;
    
    final animationController = AnimationController(
      duration: Duration(milliseconds: 3000 + random.nextInt(2000)),
      vsync: this,
    );
    
    final animation = Tween<Offset>(
      begin: Offset(startX, MediaQuery.of(context).size.height),
      end: Offset(startX + (random.nextDouble() - 0.5) * 150, -100),
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutQuart,
    ));
    
    final scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.3),
    ));
    
    final fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.7, 1.0),
    ));
    
    final rotationAnimation = Tween<double>(
      begin: 0.0,
      end: random.nextDouble() * 2 * math.pi,
    ).animate(animationController);
    
    final widget = AnimatedBuilder(
      animation: animationController,
      builder: (context, child) => Positioned(
        left: animation.value.dx,
        top: animation.value.dy,
        child: Transform.scale(
          scale: scaleAnimation.value,
          child: Transform.rotate(
            angle: rotationAnimation.value,
            child: Opacity(
              opacity: fadeAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getGiftRarityColor(giftModel.rarity).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getGiftRarityColor(giftModel.rarity).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(giftModel.icon, style: const TextStyle(fontSize: 24)),
                    if (gift.quantity > 1) ...[
                      const SizedBox(width: 4),
                      Text('x${gift.quantity}', 
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    setState(() {
      _floatingGifts.add(widget);
      if (_floatingGifts.length > maxFloatingAnimations) {
        _floatingGifts.removeAt(0);
      }
    });
    
    animationController.forward().then((_) {
      animationController.dispose();
      if (mounted) {
        setState(() {
          _floatingGifts.remove(widget);
        });
      }
    });
  }

  Color _getGiftRarityColor(GiftRarity rarity) {
    switch (rarity) {
      case GiftRarity.common:
        return Colors.grey;
      case GiftRarity.rare:
        return Colors.blue;
      case GiftRarity.epic:
        return Colors.purple;
      case GiftRarity.legendary:
        return Colors.orange;
    }
  }

  void _sendHearts() {
    HapticFeedback.lightImpact();
    _audioService.playActionSound(AudioAction.giftReceived);
    
    setState(() {
      _heartCount += 5;
    });
    
    for (int i = 0; i < 5; i++) {
      Timer(Duration(milliseconds: i * 150), () {
        _createFloatingHeart();
      });
    }
  }

  void _createFloatingHeart() {
    final random = math.Random();
    final startX = MediaQuery.of(context).size.width * 0.8 + random.nextDouble() * 80;
    
    final animationController = AnimationController(
      duration: Duration(milliseconds: 2500 + random.nextInt(1500)),
      vsync: this,
    );
    
    final animation = Tween<Offset>(
      begin: Offset(startX, MediaQuery.of(context).size.height * 0.8),
      end: Offset(startX + (random.nextDouble() - 0.5) * 120, -50),
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutQuart,
    ));
    
    final scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.8,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.4),
    ));
    
    final fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.6, 1.0),
    ));
    
    final rotationAnimation = Tween<double>(
      begin: 0.0,
      end: (random.nextDouble() - 0.5) * math.pi,
    ).animate(animationController);
    
    final colors = [
      Colors.red, Colors.pink, Colors.purple, 
      Colors.blue, Colors.orange, Colors.yellow
    ];
    final heartColor = colors[random.nextInt(colors.length)];
    
    final widget = AnimatedBuilder(
      animation: animationController,
      builder: (context, child) => Positioned(
        left: animation.value.dx,
        top: animation.value.dy,
        child: Transform.scale(
          scale: scaleAnimation.value,
          child: Transform.rotate(
            angle: rotationAnimation.value,
            child: Opacity(
              opacity: fadeAnimation.value,
              child: Icon(
                Icons.favorite,
                color: heartColor,
                size: 20 + random.nextDouble() * 15,
                shadows: [
                  Shadow(
                    color: heartColor.withOpacity(0.7),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    setState(() {
      _floatingHearts.add(widget);
      if (_floatingHearts.length > maxFloatingAnimations) {
        _floatingHearts.removeAt(0);
      }
    });
    
    animationController.forward().then((_) {
      animationController.dispose();
      if (mounted) {
        setState(() {
          _floatingHearts.remove(widget);
        });
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) return;
    
    if (_messages.isNotEmpty) {
      final lastMessage = _messages.last;
      if (lastMessage.senderId == currentUser.id && 
          DateTime.now().difference(lastMessage.timestamp).inSeconds < 2) {
        _showErrorSnackbar('Attendez un peu avant d\'envoyer un autre message');
        return;
      }
    }
    
    final newMessage = live_models.LiveMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUser.id,
      senderName: currentUser.name,
      message: message,
      timestamp: DateTime.now(),
      type: live_models.LiveMessageType.chat,
    );
    
    _addMessage(newMessage);
    _messageController.clear();
    HapticFeedback.lightImpact();
  }

  void _showGiftSelection() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGiftSelectionSheet(),
    );
  }

  Widget _buildGiftSelectionSheet() {
    final currentUser = ref.read(authServiceProvider).currentUser;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            width: 50,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.pink.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Envoyer un cadeau',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.yellow, size: 16),
                      const SizedBox(width: 4),
                      FutureBuilder<double>(
                        future: _getCurrentBalance(),
                        builder: (context, snapshot) {
                          return Text(
                            '${snapshot.data?.toInt() ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _giftCategories.keys.length,
              itemBuilder: (context, index) {
                final category = _giftCategories.keys.elementAt(index);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: index == 0,
                    onSelected: (selected) {
                      // Implémenter la sélection de catégorie
                    },
                    selectedColor: Colors.purple.withOpacity(0.2),
                    checkmarkColor: Colors.purple,
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: _buildGiftsGrid(currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftsGrid(UserModel? currentUser) {
    final gifts = _giftService.getAllGifts();
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return _buildGiftCard(gift, currentUser);
      },
    );
  }

  Widget _buildGiftCard(GiftModel gift, UserModel? currentUser) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _sendGift(gift, currentUser),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getGiftRarityColor(gift.rarity).withOpacity(0.1),
                _getGiftRarityColor(gift.rarity).withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: _getGiftRarityColor(gift.rarity).withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getGiftRarityColor(gift.rarity),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gift.rarity.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getGiftRarityColor(gift.rarity).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  gift.icon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                gift.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getGiftRarityColor(gift.rarity),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '${gift.price}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<double> _getCurrentBalance() async {
    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      if (currentUser == null) return 0.0;
      
      final balance = await ref.read(wallet_service.walletServiceProvider).getUserBalance(currentUser.id);
      return balance.toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _sendGift(GiftModel gift, UserModel? currentUser) async {
    if (currentUser == null) return;
    
    Navigator.pop(context);
    
    final balance = await _getCurrentBalance();
    final canSend = _giftService.canSendGift(
      giftId: gift.id,
      balance: balance,
      isPremiumUser: false,
    );
    
    if (!canSend) {
      _showErrorSnackbar('Solde insuffisant pour envoyer ce cadeau');
      return;
    }
    
    // Créer un cadeau virtuel local pour l'animation
    final virtualGift = live_models.VirtualGift(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      giftId: gift.id,
      quantity: 1,
      senderId: currentUser.id,
      senderName: currentUser.name,
      timestamp: DateTime.now(),
      liveId: widget.liveId ?? 'current_live',
      value: gift.price,
    );
    
    _addGiftAnimation(virtualGift);
    
    HapticFeedback.heavyImpact();
    _showSuccessSnackbar('Cadeau ${gift.name} envoyé ! 🎁');
    
    if (gift.rarity == GiftRarity.legendary) {
      _createSpecialGiftEffect();
    }
  }

  void _createSpecialGiftEffect() {
    for (int i = 0; i < 10; i++) {
      Timer(Duration(milliseconds: i * 100), () {
        _createFloatingHeart();
      });
    }
  }

  void _showViewersList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Spectateurs ($_viewerCount)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.isHost)
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: _showInviteGuestDialog,
                    tooltip: 'Inviter un spectateur',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                _buildQuickStat('Total', '$_viewerCount', Icons.visibility, Colors.blue),
                const SizedBox(width: 12),
                _buildQuickStat('Invités', '$_guestCount', Icons.people, Colors.green),
                const SizedBox(width: 12),
                _buildQuickStat('Messages', '$_messageCount', Icons.chat, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: _viewerCount == 0 
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Aucun spectateur pour le moment',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Partagez votre live pour attirer du public !',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _viewerCount,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.primaries[index % Colors.primaries.length],
                            child: Text(
                              'S${index + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text('Spectateur ${index + 1}'),
                          subtitle: Text('Rejoint il y a ${math.Random().nextInt(30) + 1} minutes'),
                          trailing: widget.isHost 
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'invite') {
                                      // Inviter comme guest
                                    } else if (value == 'block') {
                                      // Bloquer spectateur
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem(
                                      value: 'invite',
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_add),
                                          SizedBox(width: 8),
                                          Text('Inviter comme guest'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'block',
                                      child: Row(
                                        children: [
                                          Icon(Icons.block, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Bloquer'),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLiveSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Paramètres du live',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView(
                children: [
                  _buildSettingsSection(
                    'Paramètres vidéo',
                    Icons.videocam,
                    [
                      SwitchListTile(
                        title: const Text('Filtres de beauté'),
                        subtitle: const Text('Amélioration automatique de l\'image'),
                        value: _isBeautyFilterEnabled,
                        onChanged: (bool value) {
                          setState(() {
                            _isBeautyFilterEnabled = value;
                          });
                          _toggleBeautyFilter();
                        },
                        secondary: const Icon(Icons.face),
                      ),
                      SwitchListTile(
                        title: const Text('Enregistrement'),
                        subtitle: const Text('Sauvegarder le live'),
                        value: _isRecording,
                        onChanged: (value) => _toggleRecording(),
                        secondary: const Icon(Icons.fiber_manual_record),
                      ),
                      SwitchListTile(
                        title: const Text('Partage d\'écran'),
                        subtitle: const Text('Partager votre écran'),
                        value: _isScreenSharing,
                        onChanged: (value) => _toggleScreenShare(),
                        secondary: const Icon(Icons.screen_share),
                      ),
                    ],
                  ),
                  
                  _buildSettingsSection(
                    'Paramètres chat',
                    Icons.chat,
                    [
                      SwitchListTile(
                        title: const Text('Chat visible'),
                        subtitle: const Text('Afficher le chat en overlay'),
                        value: _isChatVisible,
                        onChanged: (value) => _toggleChat(),
                        secondary: const Icon(Icons.chat_bubble),
                      ),
                      if (widget.isHost) ...[
                        ListTile(
                          title: const Text('Modération automatique'),
                          subtitle: const Text('Filtrer les messages inappropriés'),
                          trailing: Switch(
                            value: true,
                            onChanged: (value) {
                              // Implémenter modération
                            },
                          ),
                          leading: const Icon(Icons.security),
                        ),
                      ],
                    ],
                  ),
                  
                  if (widget.isHost) ...[
                    _buildSettingsSection(
                      'Actions d\'hôte',
                      Icons.admin_panel_settings,
                      [
                        ListTile(
                          title: const Text('Inviter des spectateurs'),
                          subtitle: const Text('Générer un lien d\'invitation'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            _showInviteGuestDialog();
                          },
                          leading: const Icon(Icons.person_add),
                        ),
                        ListTile(
                          title: const Text('Statistiques détaillées'),
                          subtitle: const Text('Voir les analytics du live'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            _showDetailedStats();
                          },
                          leading: const Icon(Icons.analytics),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showInviteGuestDialog() {
    final liveCode = widget.liveId ?? 'LIVE${DateTime.now().millisecondsSinceEpoch}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share),
            SizedBox(width: 8),
            Text('Inviter des spectateurs'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Partagez ce code pour inviter des spectateurs :'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Code du live:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          liveCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: liveCode));
                      _showSuccessSnackbar('Code copié !');
                    },
                    tooltip: 'Copier le code',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showDetailedStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics),
            SizedBox(width: 8),
            Text('Statistiques détaillées'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailedStatRow('Durée du live:', _formatDuration(_liveDuration), Icons.access_time),
              _buildDetailedStatRow('Spectateurs actuels:', '$_viewerCount', Icons.visibility),
              _buildDetailedStatRow('Pic de spectateurs:', '$_viewerCount', Icons.trending_up),
              _buildDetailedStatRow('Invités connectés:', '$_guestCount', Icons.people),
              _buildDetailedStatRow('Messages envoyés:', '${_messages.length}', Icons.chat),
              _buildDetailedStatRow('Cœurs reçus:', '$_heartCount', Icons.favorite),
              _buildDetailedStatRow('Cadeaux reçus:', '$_giftCount', Icons.card_giftcard),
              
              const SizedBox(height: 16),
              const Text(
                'Engagement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              LinearProgressIndicator(
                value: (_messages.length / math.max(_viewerCount, 1)).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 4),
              Text(
                'Taux de participation: ${((_messages.length / math.max(_viewerCount, 1)) * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _endLive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Terminer le live ?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Êtes-vous sûr de vouloir terminer ce live ?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('Résumé du live:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildStatRow('Durée:', _formatDuration(_liveDuration)),
                  _buildStatRow('Spectateurs max:', '$_viewerCount'),
                  _buildStatRow('Messages reçus:', '${_messages.length}'),
                  _buildStatRow('Cadeaux reçus:', '$_giftCount'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer le live'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Terminer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _isLive = false;
      });
      
      // Arrêter les timers
      _statsTimer?.cancel();
      _durationTimer?.cancel();
      _cleanupTimer?.cancel();
      
      // Arrêter le stream local
      await _stopLocalStream();
      
      // Notifier le service
      try {
        await _liveService.endLive();
      } catch (e) {
        print('Erreur lors de l\'arrêt du live: $e');
      }
      
      _audioService.playActionSound(AudioAction.giftReceived);
      
      if (mounted) {
        _showFinalSummary();
      }
    }
  }

  Future<void> _stopLocalStream() async {
    try {
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        await _localStream!.dispose();
        _localStream = null;
      }
      
      if (_localRenderer != null) {
        _localRenderer!.srcObject = null;
      }
    } catch (e) {
      print('Erreur lors de l\'arrêt du stream: $e');
    }
  }

  void _showFinalSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.green),
            SizedBox(width: 8),
            Text('Live terminé !'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Merci pour ce super live !',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade100, Colors.pink.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Statistiques finales:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildFinalStatRow('⏱️', 'Durée totale', _formatDuration(_liveDuration)),
                  _buildFinalStatRow('👥', 'Spectateurs', '$_viewerCount'),
                  _buildFinalStatRow('💬', 'Messages', '${_messages.length}'),
                  _buildFinalStatRow('❤️', 'Cœurs', '$_heartCount'),
                  _buildFinalStatRow('🎁', 'Cadeaux', '$_giftCount'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Fermer dialog
              Navigator.pop(context); // Retour écran précédent
            },
            icon: const Icon(Icons.home),
            label: const Text('Retour à l\'accueil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalStatRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen dans build() uniquement quand nécessaire
    if (_isInitialized) {
      ref.listen(giftServiceProvider, (previous, next) {
        if (mounted) {
          if (next.recentTransactions.isNotEmpty) {
            final latestTransaction = next.recentTransactions.first;
            _addGiftAnimationFromTransaction(latestTransaction);
          }
        }
      });
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.grey],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    color: Colors.red,
                    strokeWidth: 6,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Préparation du live...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Vérification des permissions et connexion',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🎬 STREAM VIDÉO PRINCIPAL
          _buildMainVideoView(),
          
          // 👥 GRILLE DES INVITÉS
          if (_guests.isNotEmpty) _buildGuestsGrid(),
          
          // 📊 BARRE DE STATISTIQUES EN HAUT
          _buildTopStatsBar(),
          
          // 💬 CHAT EN DIRECT
          if (_isChatVisible) _buildChatOverlay(),
          
          // 🎮 CONTRÔLES EN BAS
          _buildControlsOverlay(),
          
          // ❤️ ANIMATIONS DE CŒURS FLOTTANTS
          ..._floatingHearts,
          
          // 🎁 ANIMATIONS DE CADEAUX FLOTTANTS
          ..._floatingGifts,
          
          // 🎁 OVERLAY D'ANIMATION DE CADEAUX RÉCENTS
          if (_recentGifts.isNotEmpty)
            _buildRecentGiftsOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainVideoView() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.black],
          ),
        ),
        child: widget.isHost 
          ? (_localStream != null && _localRenderer != null
              ? RTCVideoView(
                  _localRenderer!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: _isFrontCamera,
                )
              : _buildCameraPlaceholder())
          : (_remoteStream != null && _remoteRenderer != null
              ? RTCVideoView(
                  _remoteRenderer!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : _buildViewerPlaceholder()),
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isCameraOff ? Icons.videocam_off : Icons.videocam,
            size: 80,
            color: _isCameraOff ? Colors.red : Colors.white38,
          ),
          const SizedBox(height: 20),
          Text(
            _isCameraOff ? 'Caméra désactivée' : 'Initialisation de la caméra...',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isCameraOff ? 'Activez votre caméra pour démarrer' : 'Veuillez patienter',
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv, size: 80, color: Colors.white38),
          SizedBox(height: 20),
          Text(
            'En attente du stream...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Le live va bientôt commencer',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGiftsOverlay() {
    return Positioned(
      top: 120,
      right: 20,
      child: Column(
        children: _recentGifts.take(3).map((gift) {
          final giftModel = _giftService.getGiftById(gift.giftId);
          if (giftModel == null) return const SizedBox.shrink();
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getGiftRarityColor(giftModel.rarity).withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getGiftRarityColor(giftModel.rarity).withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(giftModel.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
                if (gift.quantity > 1)
                  Text('x${gift.quantity}', 
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGuestsGrid() {
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        width: 120,
        constraints: const BoxConstraints(maxHeight: 500),
        child: ListView.separated(
          itemCount: _guests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final guest = _guests[index];
            final renderer = _renderers[guest.userId];
            
            return Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (renderer != null && guest.isVideoEnabled)
                      Positioned.fill(
                        child: RTCVideoView(
                          renderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      )
                    else
                      const Positioned.fill(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person, size: 40, color: Colors.white54),
                              SizedBox(height: 4),
                              Text(
                                'Invité',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (guest.isMuted)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red,
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.mic_off, size: 12, color: Colors.white),
                            ),
                          if (!guest.isVideoEnabled)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange,
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.videocam_off, size: 12, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                    
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    if (widget.isHost)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _removeGuest(guest.userId),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red,
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopStatsBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _liveIndicatorController,
              builder: (context, child) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isLive ? Color.lerp(
                    Colors.red,
                    Colors.red.withOpacity(0.6),
                    _liveIndicatorController.value,
                  ) : Colors.grey,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: _isLive ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLive ? Icons.fiber_manual_record : Icons.stop_circle,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isLive ? 'LIVE' : 'ARRÊTÉ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatDuration(_liveDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            
            const Spacer(),
            
            _buildAnimatedStatChip(Icons.visibility, '$_viewerCount', Colors.blue),
            const SizedBox(width: 6),
            _buildAnimatedStatChip(Icons.people, '$_guestCount', Colors.green),
            const SizedBox(width: 6),
            _buildAnimatedStatChip(Icons.favorite, '$_heartCount', Colors.pink),
            const SizedBox(width: 6),
            _buildAnimatedStatChip(Icons.card_giftcard, '$_giftCount', Colors.orange),
            
            const SizedBox(width: 12),
            
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showLiveSettings();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.settings, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay() {
    return AnimatedBuilder(
      animation: _chatAnimationController,
      builder: (context, child) => Positioned(
        left: 16,
        bottom: 140,
        right: 160,
        height: 250,
        child: Transform.scale(
          scale: 1.0 + (_chatAnimationController.value * 0.02),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Chat en direct',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_messages.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun message pour le moment\nÉcrivez le premier !',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _chatController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildChatMessage(message, index);
                        },
                      ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLength: 200,
                          decoration: const InputDecoration(
                            hintText: 'Tapez votre message...',
                            hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue, Colors.purple],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessage(live_models.LiveMessage message, int index) {
    Color messageColor;
    Widget messageContent;
    IconData? messageIcon;
    
    switch (message.type) {
      case live_models.LiveMessageType.system:
        messageColor = Colors.yellow;
        messageIcon = Icons.info;
        messageContent = Row(
          children: [
            Icon(messageIcon, size: 12, color: messageColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                message.message,
                style: TextStyle(
                  color: messageColor,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
        break;
      case live_models.LiveMessageType.gift:
        messageColor = Colors.orange;
        messageIcon = Icons.card_giftcard;
        messageContent = Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.withOpacity(0.2), Colors.pink.withOpacity(0.2)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(messageIcon, size: 14, color: messageColor),
              const SizedBox(width: 4),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${message.senderName} ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: message.message,
                        style: TextStyle(
                          color: messageColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        break;
      default:
        messageColor = Colors.white;
        messageContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${message.senderName}: ',
                  style: TextStyle(
                    color: Colors.primaries[index % Colors.primaries.length],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: message.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: messageContent,
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isHost) ...[
                _buildAdvancedControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  isActive: !_isMuted,
                  onTap: _toggleMute,
                  tooltip: _isMuted ? 'Activer le micro' : 'Couper le micro',
                  activeColor: Colors.green,
                  inactiveColor: Colors.red,
                ),
                
                const SizedBox(width: 6),
                
                _buildAdvancedControlButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  isActive: !_isCameraOff,
                  onTap: _toggleCamera,
                  tooltip: _isCameraOff ? 'Activer la caméra' : 'Désactiver la caméra',
                  activeColor: Colors.blue,
                  inactiveColor: Colors.orange,
                ),
                
                const SizedBox(width: 6),
                
                _buildAdvancedControlButton(
                  icon: Icons.flip_camera_ios,
                  isActive: true,
                  onTap: _switchCamera,
                  tooltip: 'Changer de caméra',
                  activeColor: Colors.purple,
                ),
                
                const SizedBox(width: 6),
                
                _buildAdvancedControlButton(
                  icon: Icons.face,
                  isActive: _isBeautyFilterEnabled,
                  onTap: _toggleBeautyFilter,
                  tooltip: 'Filtres de beauté',
                  activeColor: Colors.pink,
                ),
              ],
              
              const SizedBox(width: 6),
              
              _buildAdvancedControlButton(
                icon: Icons.favorite,
                isActive: true,
                onTap: _sendHearts,
                tooltip: 'Envoyer des cœurs',
                activeColor: Colors.red,
                showPulse: true,
              ),
              
              const SizedBox(width: 6),
              
              _buildAdvancedControlButton(
                icon: Icons.card_giftcard,
                isActive: true,
                onTap: _showGiftSelection,
                tooltip: 'Envoyer un cadeau',
                activeColor: Colors.orange,
                showPulse: true,
              ),
              
              const SizedBox(width: 6),
              
              _buildAdvancedControlButton(
                icon: _isChatVisible ? Icons.chat : Icons.chat_outlined,
                isActive: _isChatVisible,
                onTap: _toggleChat,
                tooltip: 'Basculer le chat',
                activeColor: Colors.teal,
              ),
              
              const SizedBox(width: 6),
              
              _buildAdvancedControlButton(
                icon: Icons.people,
                isActive: true,
                onTap: _showViewersList,
                tooltip: 'Voir les spectateurs',
                activeColor: Colors.indigo,
                badge: _viewerCount > 0 ? '$_viewerCount' : null,
              ),
              
              const SizedBox(width: 6),
              
              if (widget.isHost)
                _buildAdvancedControlButton(
                  icon: Icons.call_end,
                  isActive: true,
                  onTap: _endLive,
                  tooltip: 'Terminer le live',
                  activeColor: Colors.red,
                  isDestructive: true,
                )
              else
                _buildAdvancedControlButton(
                  icon: Icons.exit_to_app,
                  isActive: true,
                  onTap: () => Navigator.pop(context),
                  tooltip: 'Quitter le live',
                  activeColor: Colors.red,
                  isDestructive: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
    Color? activeColor,
    Color? inactiveColor,
    bool showPulse = false,
    bool isDestructive = false,
    String? badge,
  }) {
    final color = isActive 
        ? (activeColor ?? Colors.white)
        : (inactiveColor ?? Colors.red);
    
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive 
                    ? color.withOpacity(0.2)
                    : (isDestructive ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive 
                      ? color.withOpacity(0.6)
                      : (isDestructive ? Colors.red.withOpacity(0.6) : Colors.grey.withOpacity(0.6)),
                  width: 2,
                ),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: showPulse
                  ? AnimatedBuilder(
                      animation: _heartController,
                      builder: (context, child) => Transform.scale(
                        scale: 1.0 + (_heartController.value * 0.1),
                        child: Icon(
                          icon,
                          color: color,
                          size: 22,
                        ),
                      ),
                    )
                  : Icon(
                      icon,
                      color: isActive ? color : (isDestructive ? Colors.red : Colors.grey),
                      size: 22,
                    ),
            ),
            
            if (badge != null)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    badge,
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
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 🎮 MÉTHODES DE CONTRÔLE AVANCÉES

  void _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    }
    
    if (_isMuted) {
      _audioService.playActionSound(AudioAction.giftReceived);
      HapticFeedback.heavyImpact();
    } else {
      _audioService.playActionSound(AudioAction.giftReceived);
      HapticFeedback.lightImpact();
    }
    
    _addSystemMessage(_isMuted ? 'Micro coupé' : 'Micro activé');
  }

  void _toggleCamera() async {
    setState(() => _isCameraOff = !_isCameraOff);
    
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = !_isCameraOff;
      });
    }
    
    HapticFeedback.mediumImpact();
    _addSystemMessage(_isCameraOff ? 'Caméra désactivée' : 'Caméra activée');
  }

  void _switchCamera() async {
    setState(() => _isFrontCamera = !_isFrontCamera);
    
    try {
      if (_localStream != null) {
        await _stopLocalStream();
        await _initializeLocalStream();
      }
    } catch (e) {
      print('Erreur lors du changement de caméra: $e');
    }
    
    HapticFeedback.lightImpact();
    _addSystemMessage('Caméra ${_isFrontCamera ? 'avant' : 'arrière'} activée');
  }

  void _toggleBeautyFilter() {
    setState(() => _isBeautyFilterEnabled = !_isBeautyFilterEnabled);
    
    if (_isBeautyFilterEnabled) {
      _beautyFilterController.forward();
    } else {
      _beautyFilterController.reverse();
    }
    
    HapticFeedback.lightImpact();
    _addSystemMessage(_isBeautyFilterEnabled ? 'Filtres de beauté activés' : 'Filtres de beauté désactivés');
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    
    if (_isRecording) {
      _audioService.playActionSound(AudioAction.giftReceived);
      _addSystemMessage('🔴 Enregistrement démarré');
    } else {
      _audioService.playActionSound(AudioAction.giftReceived);
      _addSystemMessage('⏹️ Enregistrement arrêté');
    }
    
    HapticFeedback.heavyImpact();
  }

  void _toggleScreenShare() {
    setState(() => _isScreenSharing = !_isScreenSharing);
    
    if (_isScreenSharing) {
      _addSystemMessage('📱 Partage d\'écran démarré');
    } else {
      _addSystemMessage('📱 Partage d\'écran arrêté');
    }
    
    HapticFeedback.mediumImpact();
  }

  void _toggleChat() {
    setState(() => _isChatVisible = !_isChatVisible);
    
    if (_isChatVisible) {
      _chatAnimationController.forward();
    } else {
      _chatAnimationController.reverse();
    }
    
    HapticFeedback.lightImpact();
  }

  // 👥 GESTION AVANCÉE DES INVITÉS

  void _removeGuest(String guestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Retirer l\'invité'),
          ],
        ),
        content: const Text('Êtes-vous sûr de vouloir retirer cet invité du live ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Retirer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _liveService.removeGuest(guestId);
        HapticFeedback.heavyImpact();
        _addSystemMessage('Un invité a quitté le live');
      } catch (e) {
        _showErrorSnackbar('Erreur lors de la suppression de l\'invité');
      }
    }
  }

  @override
  void dispose() {
    print('🔴 WebRTC Lovingo: Nettoyage des ressources');
    
    // Arrêter tous les timers
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _cleanupTimer?.cancel();
    _heartTimer?.cancel();
    
    // Cleanup animations
    _heartController.dispose();
    _liveIndicatorController.dispose();
    _giftController.dispose();
    _beautyFilterController.dispose();
    _chatAnimationController.dispose();
    
    // Cleanup controllers
    _chatController.dispose();
    _messageController.dispose();
    
    // Cleanup streams et renderers
    _stopLocalStream();
    
    if (_localRenderer != null) {
      _localRenderer!.dispose();
    }
    if (_remoteRenderer != null) {
      _remoteRenderer!.dispose();
    }
    
    // Cleanup renderers des invités
    for (final renderer in _renderers.values) {
      renderer.dispose();
    }
    _renderers.clear();
    
    // Nettoyer le service de live streaming
    if (_isLive && widget.isHost) {
      _liveService.endLive().catchError((e) {
        print('Erreur lors de l\'arrêt du live: $e');
      });
    }
    
    super.dispose();
  }
}   