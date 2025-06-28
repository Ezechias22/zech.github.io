// lib/features/calls/webrtc_audio_call_screen.dart - ÉCRAN APPEL AUDIO WEBRTC CORRIGÉ
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../config/webrtc_config.dart';
import '../../core/models/user_model.dart';
import '../../core/services/webrtc_call_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/audio_service.dart';
// ✅ CORRECTION LIGNE 12 : Import supprimé car inutilisé
// import './providers/call_provider.dart'; // SUPPRIMÉ

class WebRTCAudioCallScreen extends ConsumerStatefulWidget {
  final UserModel otherUser;
  final String channelName;
  final bool isIncoming;

  const WebRTCAudioCallScreen({
    super.key,
    required this.otherUser,
    required this.channelName,
    this.isIncoming = false,
  });

  @override
  ConsumerState<WebRTCAudioCallScreen> createState() => _WebRTCAudioCallScreenState();
}

class _WebRTCAudioCallScreenState extends ConsumerState<WebRTCAudioCallScreen>
    with TickerProviderStateMixin {
  
  // État WebRTC
  bool _localUserJoined = false; // ✅ LIGNE 34 : Utilisé dans les callbacks WebRTC
  bool _remoteUserJoined = false;
  bool _muted = false;
  bool _speakerEnabled = false;
  WebRTCConnectionState _connectionState = WebRTCConnectionState.disconnected;
  
  // Services
  late WebRTCCallService _webrtcService;
  DateTime? _callStartTime;
  StreamSubscription? _connectionStateSubscription;
  
  // Animations
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _webrtcService = ref.read(webrtcCallServiceProvider);
    _callStartTime = DateTime.now();
    
    // Initialiser les animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOut,
    ));
    
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        _showError('Utilisateur non connecté');
        return;
      }

      // Demander permission microphone uniquement
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        _showError('Permission microphone requise');
        return;
      }

      // ✅ CORRECTION LIGNE 103 : Ajouter userId requis
      final initialized = await _webrtcService.initialize(
        userId: currentUser.id,
      );
      if (!initialized) {
        _showError('Impossible d\'initialiser WebRTC');
        return;
      }

      // ✅ CONFIGURER LES CALLBACKS WEBRTC
      _setupWebRTCCallbacks();

      // ✅ DÉMARRER L'APPEL AUDIO - CORRIGÉ
      final success = await _webrtcService.startCall(
        roomId: widget.channelName,
        userId: currentUser.id,
        callType: WebRTCCallType.audio, // ✅ CORRIGÉ : WebRTCCallType au lieu de CallType
        metadata: {
          'isIncoming': widget.isIncoming,
          'otherUserId': widget.otherUser.id,
          'otherUserName': widget.otherUser.name,
        },
      );

      if (!success) {
        _showError('Impossible de démarrer l\'appel');
        return;
      }

      // ✅ JOUER LE SON D'APPEL SORTANT
      if (!widget.isIncoming) {
        AudioService.instance.playActionSound(AudioAction.callIncoming);
      }

      WebRTCConfig.logInfo('✅ Appel audio WebRTC initialisé avec succès');
    } catch (e) {
      WebRTCConfig.logError('Erreur initialisation appel audio', e);
      _showError('Impossible d\'initialiser l\'appel audio');
    }
  }

  // ✅ CONFIGURER LES CALLBACKS WEBRTC
  void _setupWebRTCCallbacks() {
    // Callback pour le stream local
    _webrtcService.onLocalStream = (MediaStream stream) {
      WebRTCConfig.logInfo('Stream local obtenu');
      if (mounted) {
        setState(() {
          _localUserJoined = true; // ✅ UTILISATION DE _localUserJoined
        });
      }
    };

    // Callback pour le stream distant
    _webrtcService.onRemoteStream = (MediaStream stream) {
      WebRTCConfig.logInfo('Stream distant reçu');
      if (mounted) {
        setState(() {
          _remoteUserJoined = true;
        });
        
        // Démarrer le chrono quand l'autre utilisateur rejoint
        _callStartTime ??= DateTime.now();
        
        // ✅ ARRÊTER LA SONNERIE ET JOUER SON DE CONNEXION
        AudioService.instance.stopAll();
        AudioService.instance.playActionSound(AudioAction.callAccept);
      }
    };

    // Callback pour les changements d'état de connexion
    _webrtcService.onConnectionStateChanged = (WebRTCConnectionState state) {
      WebRTCConfig.logInfo('État connexion WebRTC: $state');
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
        
        if (state == WebRTCConnectionState.failed) {
          _showError('Connexion échouée');
        }
      }
    };

    // Callback pour les erreurs
    _webrtcService.onError = (String error) {
      WebRTCConfig.logError('Erreur WebRTC: $error');
      if (mounted) {
        _showError('Erreur: $error');
      }
    };

    // Écouter les changements d'état de connexion
    _connectionStateSubscription = _webrtcService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
              const Color(0xFF667eea).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header avec statut
              _buildHeader(),
              
              // Zone principale avec avatar animé
              Expanded(
                child: _buildMainContent(),
              ),
              
              // Contrôles audio
              _buildAudioControls(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.call,
            color: Colors.white.withOpacity(0.8),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appel vocal WebRTC',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                Text(
                  _getCallStatusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_remoteUserJoined) _buildCallTimer(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar avec animations
          _buildAnimatedAvatar(),
          
          const SizedBox(height: 40),
          
          // Nom de l'utilisateur
          Text(
            widget.otherUser.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Statut détaillé - ✅ AFFICHAGE DU STATUT LOCAL
          Text(
            _getDetailedStatus(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          
          // ✅ INDICATEUR LOCAL USER JOINED
          if (_localUserJoined && !_remoteUserJoined)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🎤 Votre micro est actif',
                style: TextStyle(
                  color: Colors.green.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          const SizedBox(height: 40),
          
          // Indicateur de qualité audio
          if (_remoteUserJoined) _buildAudioQualityIndicator(),
          
          const SizedBox(height: 20),
          
          // Indicateur de connexion WebRTC
          _buildConnectionIndicator(),
        ],
      ),
    );
  }

  Widget _buildAnimatedAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ondes sonores animées
        if (_remoteUserJoined && !_muted) ...[
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return Container(
                width: 200 + (_waveAnimation.value * 100),
                height: 200 + (_waveAnimation.value * 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3 * (1 - _waveAnimation.value)),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return Container(
                width: 160 + (_waveAnimation.value * 60),
                height: 160 + (_waveAnimation.value * 60),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5 * (1 - _waveAnimation.value)),
                    width: 2,
                  ),
                ),
              );
            },
          ),
        ],
        
        // Avatar principal avec pulse
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _remoteUserJoined ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: widget.otherUser.photos.isNotEmpty
                      ? NetworkImage(widget.otherUser.photos.first)
                      : null,
                  child: widget.otherUser.photos.isEmpty
                      ? Text(
                          widget.otherUser.name.isNotEmpty
                              ? widget.otherUser.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
        
        // Indicateur muet
        if (_muted)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.mic_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        
        // ✅ INDICATEUR LOCAL USER JOINED
        if (_localUserJoined && !_remoteUserJoined)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute/Unmute
          _buildControlButton(
            icon: _muted ? Icons.mic_off : Icons.mic,
            color: _muted ? Colors.red : Colors.white,
            backgroundColor: _muted ? Colors.white : Colors.white.withOpacity(0.2),
            onTap: _toggleMute,
            label: _muted ? 'Activer' : 'Muet',
          ),
          
          // Haut-parleur
          _buildControlButton(
            icon: _speakerEnabled ? Icons.volume_up : Icons.volume_down,
            color: _speakerEnabled ? Colors.white : Colors.white,
            backgroundColor: _speakerEnabled 
                ? const Color(0xFF4CAF50).withOpacity(0.8)
                : Colors.white.withOpacity(0.2),
            onTap: _toggleSpeaker,
            label: _speakerEnabled ? 'Haut-parleur' : 'Écouteur',
          ),
          
          // Raccrocher
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.white,
            backgroundColor: Colors.red,
            onTap: _endCall,
            label: 'Raccrocher',
            isEndCall: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    required String label,
    bool isEndCall = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: isEndCall ? 70 : 60,
            height: isEndCall ? 70 : 60,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: isEndCall ? 35 : 30,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCallTimer() {
    if (_callStartTime == null || !_remoteUserJoined) {
      return const SizedBox();
    }
    
    return StreamBuilder<String>(
      stream: _getCallTimerStream(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            snapshot.data ?? '00:00',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioQualityIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_cellular_alt,
            color: _connectionState == WebRTCConnectionState.connected 
                ? Colors.green 
                : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _connectionState == WebRTCConnectionState.connected
                ? 'Excellente qualité'
                : 'Connexion...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getConnectionIcon(),
            color: _getConnectionColor(),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'WebRTC ${_connectionState.name}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getConnectionIcon() {
    switch (_connectionState) {
      case WebRTCConnectionState.connected:
        return Icons.wifi;
      case WebRTCConnectionState.connecting:
        return Icons.wifi_find;
      case WebRTCConnectionState.reconnecting:
        return Icons.wifi_protected_setup;
      case WebRTCConnectionState.failed:
        return Icons.wifi_off;
      case WebRTCConnectionState.disconnected:
        return Icons.portable_wifi_off;
      case WebRTCConnectionState.closed:
        return Icons.block;
    }
  }

  Color _getConnectionColor() {
    switch (_connectionState) {
      case WebRTCConnectionState.connected:
        return Colors.green;
      case WebRTCConnectionState.connecting:
      case WebRTCConnectionState.reconnecting:
        return Colors.orange;
      case WebRTCConnectionState.failed:
      case WebRTCConnectionState.disconnected:
      case WebRTCConnectionState.closed:
        return Colors.red;
    }
  }

  String _getCallStatusText() {
    switch (_connectionState) {
      case WebRTCConnectionState.connecting:
        return 'Connexion...';
      case WebRTCConnectionState.connected:
        return _remoteUserJoined ? 'Connecté' : 'En attente...';
      case WebRTCConnectionState.reconnecting:
        return 'Reconnexion...';
      case WebRTCConnectionState.failed:
        return 'Échec de connexion';
      case WebRTCConnectionState.disconnected:
        return 'Déconnecté';
      case WebRTCConnectionState.closed:
        return 'Fermé';
    }
  }

  String _getDetailedStatus() {
    if (_connectionState != WebRTCConnectionState.connected) {
      return 'Initialisation de l\'appel WebRTC...';
    }
    
    if (!_localUserJoined) {
      return 'Préparation de votre audio...';
    }
    
    if (!_remoteUserJoined) {
      return widget.isIncoming 
          ? 'Appel entrant de ${widget.otherUser.name}'
          : 'Tentative de connexion à ${widget.otherUser.name}...';
    }
    
    return 'Conversation en cours avec ${widget.otherUser.name}';
  }

  Stream<String> _getCallTimerStream() async* {
    while (_callStartTime != null && mounted) {
      final duration = DateTime.now().difference(_callStartTime!);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      yield '$minutes:$seconds';
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void _toggleMute() async {
    setState(() {
      _muted = !_muted;
    });
    
    // ✅ UTILISER WEBRTC
    await _webrtcService.muteAudio(_muted);
    
    // Son de feedback
    AudioService.instance.playActionSound(AudioAction.buttonTap);
  }

  void _toggleSpeaker() async {
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });
    
    // ✅ UTILISER WEBRTC
    await _webrtcService.enableSpeakerphone(_speakerEnabled);
    
    // Son de feedback
    AudioService.instance.playActionSound(AudioAction.buttonTap);
  }

  void _endCall() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      // Enregistrer la durée de l'appel
      if (_callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        await _webrtcService.recordCallDuration(
          otherUserId: widget.otherUser.id,
          duration: duration,
          isVideoCall: false,
        );
      }
      
      // ✅ UTILISER WEBRTC
      await _webrtcService.endCall(
        roomId: widget.channelName,
        userId: currentUser.id,
      );
      
      // ✅ JOUER SON DE FIN D'APPEL
      AudioService.instance.stopAll();
      AudioService.instance.playActionSound(AudioAction.callDecline);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur fin d\'appel audio', e);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _connectionStateSubscription?.cancel();
    
    // ✅ ARRÊTER TOUS LES SONS
    AudioService.instance.stopAll();
    
    super.dispose();
  }
}