// lib/features/calls/incoming_call_screen.dart - ÉCRAN APPEL ENTRANT CORRIGÉ
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../config/webrtc_config.dart';
import '../../core/models/call_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/audio_service.dart';
import './providers/call_provider.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final Call call;
  final UserModel caller;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.caller,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _rippleController;
  
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rippleAnimation;
  
  Timer? _autoDeclineTimer;
  Timer? _vibrationTimer;
  int _remainingSeconds = 30; // Auto-decline après 30 secondes
  
  bool _isAnswering = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    
    // Vibration et son de sonnerie
    _startRingtone();
    
    // Animations
    _setupAnimations();
    
    // Timer d'auto-decline
    _startAutoDeclineTimer();
    
    // Bloquer rotation écran
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    WebRTCConfig.logInfo('📞 Écran d\'appel entrant initialisé');
  }

  void _setupAnimations() {
    // Animation de pulse pour l'avatar
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Animation de slide pour les boutons
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    // Animation de ripple pour les effets visuels
    _rippleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    // Démarrer les animations
    _slideController.forward();
  }

  void _startRingtone() {
    try {
      // Vibration pattern initiale
      HapticFeedback.heavyImpact();
      
      // Démarrer la sonnerie via le service audio
      AudioService.instance.playRingtone();
      
      // Vibration continue toutes les 2 secondes
      _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted && !_isAnswering && !_isDeclining) {
          HapticFeedback.lightImpact();
        } else {
          timer.cancel();
        }
      });

      WebRTCConfig.logInfo('🔔 Sonnerie et vibrations démarrées');
    } catch (e) {
      WebRTCConfig.logError('Erreur démarrage sonnerie', e);
    }
  }

  void _startAutoDeclineTimer() {
    _autoDeclineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });
        
        if (_remainingSeconds <= 0) {
          WebRTCConfig.logInfo('⏰ Auto-refus de l\'appel (timeout)');
          _declineCall();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _acceptCall() {
    if (_isAnswering || _isDeclining) return;
    
    WebRTCConfig.logInfo('✅ Acceptation de l\'appel entrant');
    
    setState(() {
      _isAnswering = true;
    });
    
    // Arrêter sonnerie et vibrations
    _stopRingtone();
    
    // Son d'acceptation
    AudioService.instance.playCallAcceptSound();
    
    // Feedback haptique
    HapticFeedback.mediumImpact();
    
    // Animation d'acceptation puis callback
    _slideController.reverse().then((_) {
      if (mounted) {
        widget.onAccept();
      }
    });
  }

  void _declineCall() {
    if (_isAnswering || _isDeclining) return;
    
    WebRTCConfig.logInfo('❌ Refus de l\'appel entrant');
    
    setState(() {
      _isDeclining = true;
    });
    
    // Arrêter sonnerie et vibrations
    _stopRingtone();
    
    // Son de refus
    AudioService.instance.playCallDeclineSound();
    
    // Feedback haptique
    HapticFeedback.heavyImpact();
    
    // Animation de refus puis callback
    _slideController.reverse().then((_) {
      if (mounted) {
        widget.onDecline();
      }
    });
  }

  void _stopRingtone() {
    try {
      AudioService.instance.stopRingtone();
      _vibrationTimer?.cancel();
      WebRTCConfig.logInfo('🔇 Sonnerie et vibrations arrêtées');
    } catch (e) {
      WebRTCConfig.logError('Erreur arrêt sonnerie', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( // ✅ AJOUTÉ POUR ÉVITER OVERFLOW
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ CHANGÉ
                children: [
                  // Header avec statut d'appel
                  _buildHeader(isSmallScreen),
                  
                  // Zone principale avec avatar animé - ✅ PLUS DE EXPANDED PROBLÉMATIQUE
                  _buildMainContent(isSmallScreen, screenWidth),
                  
                  // Contrôles d'appel
                  _buildCallControls(isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? 15 : 30), // ✅ ADAPTATIF
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 20), // ✅ ADAPTATIF
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ
        children: [
          Text(
            widget.call.type == CallType.video ? 'Appel vidéo entrant' : 'Appel entrant',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: isSmallScreen ? 14 : 16, // ✅ ADAPTATIF
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 8), // ✅ ADAPTATIF
          
          // Indicateur WebRTC
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12, 
              vertical: isSmallScreen ? 2 : 4,
            ), // ✅ ADAPTATIF
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi,
                  color: Colors.blue,
                  size: isSmallScreen ? 12 : 14, // ✅ ADAPTATIF
                ),
                SizedBox(width: isSmallScreen ? 4 : 6), // ✅ ADAPTATIF
                Text(
                  'WebRTC',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: isSmallScreen ? 10 : 12, // ✅ ADAPTATIF
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 4 : 8), // ✅ ADAPTATIF
          
          // Timer de refus automatique
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16, 
              vertical: isSmallScreen ? 4 : 6,
            ), // ✅ ADAPTATIF
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Auto-refus dans ${_remainingSeconds}s',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: isSmallScreen ? 12 : 14, // ✅ ADAPTATIF
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isSmallScreen, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24), // ✅ ADAPTATIF
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ
        children: [
          // Avatar avec effets visuels
          _buildAnimatedAvatar(isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 20 : 40), // ✅ ADAPTATIF
          
          // Nom de l'appelant - ✅ TAILLE RESPONSIVE
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.caller.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 28 : 36, // ✅ ADAPTATIF
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 8 : 12), // ✅ ADAPTATIF
          
          // Informations supplémentaires
          if (widget.caller.bio.isNotEmpty == true)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1), // ✅ RESPONSIVE
              child: Text(
                widget.caller.bio,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: isSmallScreen ? 14 : 16, // ✅ ADAPTATIF
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          SizedBox(height: isSmallScreen ? 12 : 20), // ✅ ADAPTATIF
          
          // Indicateur de type d'appel - ✅ RESPONSIVE
          Container(
            constraints: BoxConstraints(maxWidth: screenWidth * 0.8), // ✅ LIMITE LARGEUR
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16, 
              vertical: isSmallScreen ? 6 : 8,
            ), // ✅ ADAPTATIF
            decoration: BoxDecoration(
              color: widget.call.type == CallType.video 
                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                  : const Color(0xFF2196F3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.call.type == CallType.video 
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.call.type == CallType.video ? Icons.videocam : Icons.call,
                  color: widget.call.type == CallType.video 
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF2196F3),
                  size: isSmallScreen ? 16 : 20, // ✅ ADAPTATIF
                ),
                SizedBox(width: isSmallScreen ? 6 : 8), // ✅ ADAPTATIF
                Flexible( // ✅ AJOUTÉ POUR ÉVITER OVERFLOW
                  child: Text(
                    widget.call.type == CallType.video ? 'Appel vidéo WebRTC' : 'Appel vocal WebRTC',
                    style: TextStyle(
                      color: widget.call.type == CallType.video 
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2196F3),
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 12 : 14, // ✅ ADAPTATIF
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAvatar(bool isSmallScreen) {
    final avatarSize = isSmallScreen ? 120.0 : 160.0; // ✅ ADAPTATIF
    final effectSize = isSmallScreen ? 240.0 : 300.0; // ✅ ADAPTATIF
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripples d'arrière-plan
        AnimatedBuilder(
          animation: _rippleAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(effectSize, effectSize),
              painter: RipplePainter(
                animationValue: _rippleAnimation.value,
                color: Colors.white.withOpacity(0.1),
              ),
            );
          },
        ),
        
        // Avatar principal avec pulse
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 20 : 30, // ✅ ADAPTATIF
                      spreadRadius: isSmallScreen ? 5 : 10, // ✅ ADAPTATIF
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  backgroundImage: widget.caller.photos.isNotEmpty
                      ? NetworkImage(widget.caller.photos.first)
                      : null,
                  child: widget.caller.photos.isEmpty
                      ? Text(
                          widget.caller.name.isNotEmpty
                              ? widget.caller.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 32 : 48, // ✅ ADAPTATIF
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
        
        // Indicateur de type d'appel sur l'avatar
        Positioned(
          bottom: isSmallScreen ? 5 : 10, // ✅ ADAPTATIF
          right: isSmallScreen ? 5 : 10, // ✅ ADAPTATIF
          child: Container(
            width: isSmallScreen ? 30 : 40, // ✅ ADAPTATIF
            height: isSmallScreen ? 30 : 40, // ✅ ADAPTATIF
            decoration: BoxDecoration(
              color: widget.call.type == CallType.video ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              widget.call.type == CallType.video ? Icons.videocam : Icons.call,
              color: Colors.white,
              size: isSmallScreen ? 15 : 20, // ✅ ADAPTATIF
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls(bool isSmallScreen) {
    final buttonSize = isSmallScreen ? 60.0 : 70.0; // ✅ ADAPTATIF
    
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24 : 40), // ✅ ADAPTATIF
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Bouton refuser
            _buildActionButton(
              icon: Icons.call_end,
              color: Colors.white,
              backgroundColor: Colors.red,
              onTap: _declineCall,
              isLoading: _isDeclining,
              size: buttonSize,
              label: 'Refuser',
              isSmallScreen: isSmallScreen,
            ),
            
            // Espace central avec indicateur d'appel
            Flexible( // ✅ AJOUTÉ FLEXIBLE
              child: Column(
                mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 12, 
                      vertical: isSmallScreen ? 4 : 6,
                    ), // ✅ ADAPTATIF
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Glisser pour répondre',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: isSmallScreen ? 10 : 12, // ✅ ADAPTATIF
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bouton accepter
            _buildActionButton(
              icon: widget.call.type == CallType.video ? Icons.videocam : Icons.call,
              color: Colors.white,
              backgroundColor: const Color(0xFF4CAF50),
              onTap: _acceptCall,
              isLoading: _isAnswering,
              size: buttonSize,
              label: 'Accepter',
              isSmallScreen: isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    required bool isLoading,
    required double size,
    required String label,
    required bool isSmallScreen, // ✅ AJOUTÉ
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ
      children: [
        GestureDetector(
          onTap: isLoading ? null : onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.4),
                  blurRadius: isSmallScreen ? 15 : 20, // ✅ ADAPTATIF
                  spreadRadius: isSmallScreen ? 3 : 5, // ✅ ADAPTATIF
                ),
              ],
            ),
            child: isLoading
                ? CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: isSmallScreen ? 2 : 3, // ✅ ADAPTATIF
                  )
                : Icon(
                    icon,
                    color: color,
                    size: size * 0.5,
                  ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 8), // ✅ ADAPTATIF
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: isSmallScreen ? 12 : 14, // ✅ ADAPTATIF
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WebRTCConfig.logInfo('🔚 Nettoyage écran appel entrant');
    
    // Arrêter sonnerie et vibrations
    _stopRingtone();
    
    // Nettoyer timers et animations
    _autoDeclineTimer?.cancel();
    _vibrationTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _rippleController.dispose();
    
    // Rétablir orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }
}

// ✅ PAINTER POUR LES EFFETS DE RIPPLE - OPTIMISÉ
class RipplePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  RipplePainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    // Dessiner plusieurs cercles avec différentes opacités
    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + (i * 0.3)) % 1.0;
      final radius = maxRadius * progress;
      final opacity = (1.0 - progress) * 0.6;
      
      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}