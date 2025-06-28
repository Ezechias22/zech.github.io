// lib/features/calls/webrtc_video_call_screen.dart - ÉCRAN APPEL VIDÉO WEBRTC CORRIGÉ
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/webrtc_config.dart';
import '../../core/models/user_model.dart';
import '../../core/services/webrtc_call_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/audio_service.dart';
// ✅ CORRECTION LIGNE 12 : Import supprimé car inutilisé
// import './providers/call_provider.dart'; // SUPPRIMÉ

class WebRTCVideoCallScreen extends ConsumerStatefulWidget {
  final UserModel otherUser;
  final String channelName;
  final bool isIncoming;

  const WebRTCVideoCallScreen({
    super.key,
    required this.otherUser,
    required this.channelName,
    this.isIncoming = false,
  });

  @override
  ConsumerState<WebRTCVideoCallScreen> createState() => _WebRTCVideoCallScreenState();
}

class _WebRTCVideoCallScreenState extends ConsumerState<WebRTCVideoCallScreen> {
  
  // État WebRTC
  bool _localUserJoined = false;
  bool _remoteUserJoined = false;
  bool _muted = false;
  bool _videoDisabled = false;
  bool _speakerEnabled = true;
  WebRTCConnectionState _connectionState = WebRTCConnectionState.disconnected;
  
  // Streams WebRTC
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // Renderers WebRTC
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  // Services
  late WebRTCCallService _webrtcService;
  DateTime? _callStartTime;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _localStreamSubscription;
  StreamSubscription? _remoteStreamSubscription;
  
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _webrtcService = ref.read(webrtcCallServiceProvider);
    _callStartTime = DateTime.now();
    
    _initializeRenderers();
    _initCall();
  }

  // ✅ INITIALISER LES RENDERERS WEBRTC
  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      WebRTCConfig.logInfo('✅ Renderers WebRTC initialisés');
    } catch (e) {
      WebRTCConfig.logError('Erreur initialisation renderers', e);
    }
  }

  Future<void> _initCall() async {
    try {
      if (_disposed) return;
      
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        _showError('Utilisateur non connecté');
        return;
      }

      // Demander les permissions
      final permissions = await [
        Permission.microphone,
        Permission.camera,
      ].request();

      if (permissions[Permission.microphone] != PermissionStatus.granted ||
          permissions[Permission.camera] != PermissionStatus.granted) {
        _showError('Permissions requises pour l\'appel vidéo');
        return;
      }

      // ✅ CORRECTION LIGNE 101 : Ajouter userId requis
      final initialized = await _webrtcService.initialize(
        userId: currentUser.id,
      );
      if (!initialized) {
        _showError('Impossible d\'initialiser WebRTC');
        return;
      }

      // ✅ CONFIGURER LES CALLBACKS WEBRTC
      _setupWebRTCCallbacks();

      // ✅ DÉMARRER L'APPEL VIDÉO - CORRIGÉ
      final success = await _webrtcService.startCall(
        roomId: widget.channelName,
        userId: currentUser.id,
        callType: WebRTCCallType.video, // ✅ CORRIGÉ : WebRTCCallType au lieu de CallType
        metadata: {
          'isIncoming': widget.isIncoming,
          'otherUserId': widget.otherUser.id,
          'otherUserName': widget.otherUser.name,
        },
      );

      if (!success) {
        _showError('Impossible de démarrer l\'appel vidéo');
        return;
      }

      // ✅ JOUER LE SON D'APPEL SORTANT
      if (!widget.isIncoming) {
        AudioService.instance.playActionSound(AudioAction.callIncoming);
      }

      WebRTCConfig.logInfo('✅ Appel vidéo WebRTC initialisé avec succès');
    } catch (e) {
      WebRTCConfig.logError('Erreur initialisation appel vidéo', e);
      if (mounted) {
        _showError('Impossible d\'initialiser l\'appel vidéo');
      }
    }
  }

  // ✅ CONFIGURER LES CALLBACKS WEBRTC
  void _setupWebRTCCallbacks() {
    // Callback pour le stream local
    _webrtcService.onLocalStream = (MediaStream stream) {
      WebRTCConfig.logInfo('Stream local obtenu');
      if (mounted && !_disposed) {
        setState(() {
          _localStream = stream;
          _localUserJoined = true;
        });
        _localRenderer.srcObject = stream;
      }
    };

    // Callback pour le stream distant
    _webrtcService.onRemoteStream = (MediaStream stream) {
      WebRTCConfig.logInfo('Stream distant reçu');
      if (mounted && !_disposed) {
        setState(() {
          _remoteStream = stream;
          _remoteUserJoined = true;
        });
        _remoteRenderer.srcObject = stream;
        
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
      if (mounted && !_disposed) {
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
      if (mounted && !_disposed) {
        _showError('Erreur: $error');
      }
    };

    // Écouter les streams
    _localStreamSubscription = _webrtcService.localStreamStream.listen((stream) {
      if (mounted && !_disposed) {
        setState(() {
          _localStream = stream;
          _localUserJoined = true;
        });
        _localRenderer.srcObject = stream;
      }
    });

    _remoteStreamSubscription = _webrtcService.remoteStreamStream.listen((stream) {
      if (mounted && !_disposed) {
        setState(() {
          _remoteStream = stream;
          _remoteUserJoined = true;
        });
        _remoteRenderer.srcObject = stream;
      }
    });

    _connectionStateSubscription = _webrtcService.connectionStateStream.listen((state) {
      if (mounted && !_disposed) {
        setState(() {
          _connectionState = state;
        });
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      // ✅ ARRÊTER TOUS LES SONS EN CAS D'ERREUR
      AudioService.instance.stopAll();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
      
      // Retourner à l'écran précédent après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Vue principale (utilisateur distant ou local)
          _buildMainView(),
          
          // Vue en incrustation (utilisateur local)
          if (_localUserJoined && _localStream != null) _buildPictureInPictureView(),
          
          // Informations utilisateur
          _buildUserInfo(),
          
          // Chronomètre
          _buildCallTimer(),
          
          // Contrôles d'appel
          _buildCallControls(),
          
          // État de connexion
          if (_connectionState != WebRTCConnectionState.connected) _buildConnectionStatus(),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    if (_remoteUserJoined && _remoteStream != null) {
      // Afficher la vidéo distante
      return SizedBox.expand(
        child: RTCVideoView(
          _remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirror: false,
        ),
      );
    } else if (_localUserJoined && _localStream != null) {
      // Afficher sa propre vidéo en attendant
      return SizedBox.expand(
        child: RTCVideoView(
          _localRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirror: true,
        ),
      );
    } else {
      // Afficher l'avatar en attendant
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFF6B6B).withOpacity(0.8),
              const Color(0xFFFF8E53).withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'user_avatar_${widget.otherUser.id}',
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.otherUser.photos.isNotEmpty
                      ? NetworkImage(widget.otherUser.photos.first)
                      : null,
                  child: widget.otherUser.photos.isEmpty
                      ? Text(
                          widget.otherUser.name.isNotEmpty
                              ? widget.otherUser.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.otherUser.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _getCallStatusText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildPictureInPictureView() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      right: 20,
      width: 120,
      height: 160,
      child: GestureDetector(
        onTap: _switchMainView,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _remoteUserJoined && _remoteStream != null
                ? RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: true,
                  )
                : Container(
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundImage: widget.otherUser.photos.isNotEmpty
                  ? NetworkImage(widget.otherUser.photos.first)
                  : null,
              child: widget.otherUser.photos.isEmpty
                  ? Text(
                      widget.otherUser.name.isNotEmpty
                          ? widget.otherUser.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.otherUser.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _getConnectionIcon(),
              color: _getConnectionColor(),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 30,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Contrôles principaux
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute/Unmute
                _buildControlButton(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  color: _muted ? Colors.red : Colors.white,
                  backgroundColor: _muted ? Colors.white : Colors.white.withOpacity(0.2),
                  onTap: _toggleMute,
                ),
                
                // Caméra On/Off
                _buildControlButton(
                  icon: _videoDisabled ? Icons.videocam_off : Icons.videocam,
                  color: _videoDisabled ? Colors.red : Colors.white,
                  backgroundColor: _videoDisabled ? Colors.white : Colors.white.withOpacity(0.2),
                  onTap: _toggleVideo,
                ),
                
                // Changer caméra
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  color: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  onTap: _switchCamera,
                ),
                
                // Haut-parleur
                _buildControlButton(
                  icon: _speakerEnabled ? Icons.volume_up : Icons.volume_down,
                  color: Colors.white,
                  backgroundColor: _speakerEnabled 
                      ? const Color(0xFF4CAF50).withOpacity(0.8)
                      : Colors.white.withOpacity(0.2),
                  onTap: _toggleSpeaker,
                ),
                
                // Raccrocher
                _buildControlButton(
                  icon: Icons.call_end,
                  color: Colors.white,
                  backgroundColor: Colors.red,
                  onTap: _endCall,
                  isEndCall: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    bool isEndCall = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isEndCall ? 70 : 50,
        height: isEndCall ? 70 : 50,
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
          size: isEndCall ? 35 : 25,
        ),
      ),
    );
  }

  Widget _buildCallTimer() {
    if (_callStartTime == null || !_remoteUserJoined) {
      return const SizedBox();
    }
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 20,
      child: StreamBuilder<String>(
        stream: _getCallTimerStream(),
        builder: (context, snapshot) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              snapshot.data ?? '00:00',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_connectionState == WebRTCConnectionState.connecting) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                _getConnectionIcon(),
                color: _getConnectionColor(),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'WebRTC ${_connectionState.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
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
        return 'Connexion WebRTC...';
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

  Stream<String> _getCallTimerStream() async* {
    while (_callStartTime != null && mounted && !_disposed) {
      final duration = DateTime.now().difference(_callStartTime!);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      yield '$minutes:$seconds';
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void _toggleMute() async {
    if (_disposed) return;
    
    setState(() {
      _muted = !_muted;
    });
    
    // ✅ UTILISER WEBRTC
    await _webrtcService.muteAudio(_muted);
    
    // Son de feedback
    AudioService.instance.playActionSound(AudioAction.buttonTap);
  }

  void _toggleVideo() async {
    if (_disposed) return;
    
    setState(() {
      _videoDisabled = !_videoDisabled;
    });
    
    // ✅ UTILISER WEBRTC
    await _webrtcService.muteVideo(_videoDisabled);
    
    // Son de feedback
    AudioService.instance.playActionSound(AudioAction.buttonTap);
  }

  void _toggleSpeaker() async {
    if (_disposed) return;
    
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });
    
    // ✅ UTILISER WEBRTC
    await _webrtcService.enableSpeakerphone(_speakerEnabled);
    
    // Son de feedback
    AudioService.instance.playActionSound(AudioAction.buttonTap);
  }

  void _switchCamera() async {
    if (_disposed) return;
    
    // ✅ UTILISER WEBRTC
    await _webrtcService.switchCamera();
    
    // Son de feedback
    AudioService.instance.playActionSound(AudioAction.buttonTap);
  }

  void _switchMainView() {
    // Échange entre vue locale et distante (fonctionnalité bonus)
    if (_remoteUserJoined && _localUserJoined) {
      AudioService.instance.playActionSound(AudioAction.buttonTap);
      // Cette fonctionnalité peut être implémentée plus tard
    }
  }

  void _endCall() async {
    if (_disposed) return;
    
    try {
      // ✅ ARRÊTER IMMÉDIATEMENT TOUS LES SONS
      AudioService.instance.stopAll();
      
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      // Enregistrer la durée de l'appel
      if (_callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        await _webrtcService.recordCallDuration(
          otherUserId: widget.otherUser.id,
          duration: duration,
          isVideoCall: true,
        );
      }
      
      // ✅ UTILISER WEBRTC
      await _webrtcService.endCall(
        roomId: widget.channelName,
        userId: currentUser.id,
      );
      
      // ✅ JOUER SON DE FIN D'APPEL
      AudioService.instance.playActionSound(AudioAction.callDecline);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur fin d\'appel vidéo', e);
      // ✅ EN CAS D'ERREUR, TOUJOURS ARRÊTER LES SONS ET QUITTER
      AudioService.instance.stopAll();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    
    try {
      // ✅ ARRÊTER LES SUBSCRIPTIONS
      _connectionStateSubscription?.cancel();
      _localStreamSubscription?.cancel();
      _remoteStreamSubscription?.cancel();
      
      // ✅ LIBÉRER LES RENDERERS
      _localRenderer.dispose();
      _remoteRenderer.dispose();
      
      // ✅ ARRÊTER TOUS LES SONS
      AudioService.instance.stopAll();
    } catch (e) {
      WebRTCConfig.logError('Erreur dispose', e);
    } finally {
      super.dispose();
    }
  }
}