// lib/core/services/pip_service.dart - SERVICE PICTURE-IN-PICTURE - CORRIGÉ
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/webrtc_config.dart'; // ✅ Import WebRTCCallType
import '../models/user_model.dart';

// ✅ MIXIN POUR LES ÉCRANS COMPATIBLES PIP - CORRIGÉ
mixin PipCapable<T extends StatefulWidget> on State<T> {
  static OverlayEntry? _pipOverlay;
  static bool _isPipActive = false;
  static PipController? _pipController;

  // Activer le mode PiP - CORRIGÉ
  void enablePip({
    required UserModel otherUser,
    required WebRTCCallType callType, // ✅ CORRIGÉ : WebRTCCallType au lieu de CallType
    required String channelName,
    required bool isMuted,
    required bool isVideoEnabled,
  }) {
    if (_isPipActive) return;

    _pipController = PipController(
      otherUser: otherUser,
      callType: callType,
      channelName: channelName,
      isMuted: isMuted,
      isVideoEnabled: isVideoEnabled,
    );

    _pipOverlay = OverlayEntry(
      builder: (context) => PipWindow(controller: _pipController!),
    );

    Overlay.of(context).insert(_pipOverlay!);
    _isPipActive = true;

    WebRTCConfig.logInfo('✅ Mode PiP activé');
  }

  // Désactiver le mode PiP
  void disablePip() {
    if (!_isPipActive) return;

    _pipOverlay?.remove();
    _pipOverlay = null;
    _pipController = null;
    _isPipActive = false;

    WebRTCConfig.logInfo('✅ Mode PiP désactivé');
  }

  // Mettre à jour l'état du micro en PiP
  void updatePipMute(bool isMuted) {
    if (_isPipActive && _pipController != null) {
      _pipController!._updateMute(isMuted);
    }
  }

  // Mettre à jour l'état de la vidéo en PiP
  void updatePipVideo(bool isVideoEnabled) {
    if (_isPipActive && _pipController != null) {
      _pipController!._updateVideo(isVideoEnabled);
    }
  }

  // Vérifier si PiP est actif
  static bool get isPipActive => _isPipActive;
}

// ✅ CONTRÔLEUR PIP - CORRIGÉ
class PipController extends ChangeNotifier {
  final UserModel otherUser;
  final WebRTCCallType callType; // ✅ CORRIGÉ
  final String channelName;
  bool isMuted;
  bool isVideoEnabled;

  PipController({
    required this.otherUser,
    required this.callType,
    required this.channelName,
    required this.isMuted,
    required this.isVideoEnabled,
  });

  void _updateMute(bool muted) {
    isMuted = muted;
    notifyListeners();
  }

  void _updateVideo(bool enabled) {
    isVideoEnabled = enabled;
    notifyListeners();
  }
}

// ✅ FENÊTRE PIP
class PipWindow extends StatefulWidget {
  final PipController controller;

  const PipWindow({super.key, required this.controller});

  @override
  State<PipWindow> createState() => _PipWindowState();
}

class _PipWindowState extends State<PipWindow> 
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final pipWidth = _isExpanded ? 200.0 : 120.0;
    final pipHeight = _isExpanded ? 160.0 : 90.0;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onPanStart: (details) {
                _isDragging = true;
                HapticFeedback.lightImpact();
              },
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    (_position.dx + details.delta.dx).clamp(
                      0, 
                      screenSize.width - pipWidth,
                    ),
                    (_position.dy + details.delta.dy).clamp(
                      MediaQuery.of(context).padding.top, 
                      screenSize.height - pipHeight - 50,
                    ),
                  );
                });
              },
              onPanEnd: (details) {
                _isDragging = false;
                _snapToEdge(screenSize, pipWidth);
              },
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: pipWidth,
                height: pipHeight,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDragging ? Colors.white : Colors.grey,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      // Contenu vidéo/avatar
                      _buildPipContent(),
                      
                      // Overlay avec contrôles
                      _buildPipOverlay(),
                      
                      // Indicateur de statut
                      _buildStatusIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPipContent() {
    // ✅ CORRIGÉ : Utiliser l'extension sur WebRTCCallType
    if (widget.controller.callType.isVideo && widget.controller.isVideoEnabled) {
      // TODO: Intégrer le renderer vidéo WebRTC
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: Icon(
            Icons.videocam,
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    } else {
      // Afficher l'avatar pour les appels audio
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.8),
              Colors.purple.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: CircleAvatar(
            radius: _isExpanded ? 40 : 25,
            backgroundImage: widget.controller.otherUser.photos.isNotEmpty
                ? NetworkImage(widget.controller.otherUser.photos.first)
                : null,
            child: widget.controller.otherUser.photos.isEmpty
                ? Text(
                    widget.controller.otherUser.name.isNotEmpty
                        ? widget.controller.otherUser.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: _isExpanded ? 24 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
      );
    }
  }

  Widget _buildPipOverlay() {
    if (!_isExpanded) return const SizedBox();
    
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Nom de l'utilisateur
            Text(
              widget.controller.otherUser.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // Contrôles mini
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute
                GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.controller.isMuted 
                          ? Colors.red 
                          : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.controller.isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                
                // Agrandir
                GestureDetector(
                  onTap: _expandToFullScreen,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                
                // Fermer
                GestureDetector(
                  onTap: _closePip,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              // ✅ CORRIGÉ : Utiliser l'extension displayName
              widget.controller.callType.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snapToEdge(Size screenSize, double pipWidth) {
    setState(() {
      if (_position.dx < screenSize.width / 2) {
        // Snap à gauche
        _position = Offset(20, _position.dy);
      } else {
        // Snap à droite
        _position = Offset(screenSize.width - pipWidth - 20, _position.dy);
      }
    });
  }

  void _toggleMute() {
    // TODO: Implémenter la logique de mute
    HapticFeedback.lightImpact();
  }

  void _expandToFullScreen() {
    // TODO: Retourner à l'écran d'appel complet
    HapticFeedback.mediumImpact();
  }

  void _closePip() {
    _animationController.reverse().then((_) {
      // TODO: Terminer l'appel complètement
      widget.controller.dispose();
    });
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }
}