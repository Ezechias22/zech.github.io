// lib/shared/widgets/gift_animation_overlay.dart - ANIMATIONS DE CADEAUX VIRTUELS CORRIGÉ
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/live_models.dart';
import '../../core/models/gift_model.dart';

class GiftAnimationOverlay extends StatefulWidget {
  final List<VirtualGift> gifts;
  final VoidCallback? onAnimationComplete;

  const GiftAnimationOverlay({
    super.key,
    required this.gifts,
    this.onAnimationComplete,
  });

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with TickerProviderStateMixin {
  
  final List<GiftAnimationData> _activeAnimations = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _processGifts();
  }

  @override
  void didUpdateWidget(GiftAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gifts.length > oldWidget.gifts.length) {
      _processNewGifts(oldWidget.gifts);
    }
  }

  void _processGifts() {
    for (final gift in widget.gifts) {
      _createGiftAnimation(gift);
    }
  }

  void _processNewGifts(List<VirtualGift> oldGifts) {
    final newGifts = widget.gifts.where((gift) => 
      !oldGifts.any((oldGift) => oldGift.id == gift.id)
    ).toList();
    
    for (final gift in newGifts) {
      _createGiftAnimation(gift);
    }
  }

  void _createGiftAnimation(VirtualGift gift) {
    final animationData = GiftAnimationData(
      gift: gift,
      vsync: this,
      onComplete: () => _removeAnimation(gift.id),
    );
    
    setState(() {
      _activeAnimations.add(animationData);
    });
    
    animationData.start();
  }

  void _removeAnimation(String giftId) {
    setState(() {
      _activeAnimations.removeWhere((animation) => animation.gift.id == giftId);
    });
    
    if (_activeAnimations.isEmpty) {
      widget.onAnimationComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: _activeAnimations.map((animationData) {
            return _buildSingleGiftAnimation(animationData);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSingleGiftAnimation(GiftAnimationData animationData) {
    final gift = animationData.gift;
    
    return AnimatedBuilder(
      animation: animationData.mainController,
      builder: (context, child) {
        return Stack(
          children: [
            // Particules en arrière-plan
            CustomPaint(
              painter: ParticlePainter(
                particles: animationData.particles,
                progress: animationData.particleAnimation.value,
                screenSize: MediaQuery.of(context).size,
              ),
              child: Container(),
            ),
            
            // Cadeau principal
            _buildMainGift(animationData),
            
            // Texte d'information
            _buildGiftText(animationData),
            
            // Effet de combo si quantité élevée
            if (gift.quantity >= 10) _buildComboEffect(animationData),
          ],
        );
      },
    );
  }

  Widget _buildMainGift(GiftAnimationData animationData) {
    final gift = animationData.gift;
    final screenSize = MediaQuery.of(context).size;
    
    // Position aléatoire de départ
    final startX = _random.nextDouble() * screenSize.width;
    final startY = screenSize.height * 0.6 + _random.nextDouble() * 200;
    
    return Positioned(
      left: startX,
      top: startY,
      child: Transform.scale(
        scale: animationData.scaleAnimation.value,
        child: Transform.translate(
          offset: Offset(
            animationData.slideAnimation.value.dx * 100,
            animationData.slideAnimation.value.dy * 200,
          ),
          child: Transform.rotate(
            angle: _shouldRotate(gift.giftId) ? animationData.rotationAnimation.value : 0.0,
            child: Opacity(
              opacity: 1.0 - animationData.opacityAnimation.value,
              child: _buildGiftWidget(gift),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiftWidget(VirtualGift gift) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: _getGiftColor(gift.giftId).withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getGiftEmoji(gift.giftId),
              style: const TextStyle(fontSize: 32),
            ),
            if (gift.quantity > 1) ...[
              const SizedBox(height: 2),
              Text(
                '×${gift.quantity}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGiftText(GiftAnimationData animationData) {
    final gift = animationData.gift;
    
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: animationData.textController,
        builder: (context, child) {
          return Transform.scale(
            scale: animationData.textScaleAnimation.value,
            child: Opacity(
              opacity: animationData.textOpacityAnimation.value,
              child: Column(
                children: [
                  Text(
                    gift.senderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'a envoyé ${_getGiftName(gift.giftId)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      shadows: const [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (gift.quantity > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      '×${gift.quantity}',
                      style: TextStyle(
                        color: _getGiftColor(gift.giftId),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComboEffect(GiftAnimationData animationData) {
    return Positioned.fill(
      child: CustomPaint(
        painter: ComboEffectPainter(
          progress: animationData.mainController.value,
          color: _getGiftColor(animationData.gift.giftId),
        ),
      ),
    );
  }

  Color _getGiftColor(String giftId) {
    switch (giftId) {
      case 'heart':
        return Colors.red;
      case 'diamond':
        return Colors.blue;
      case 'crown':
        return Colors.yellow;
      case 'rose':
        return Colors.pink;
      default:
        return Colors.white;
    }
  }

  String _getGiftEmoji(String giftId) {
    switch (giftId) {
      case 'heart':
        return '❤️';
      case 'rose':
        return '🌹';
      case 'diamond':
        return '💎';
      case 'crown':
        return '👑';
      default:
        return '🎁';
    }
  }

  String _getGiftName(String giftId) {
    switch (giftId) {
      case 'heart':
        return 'un cœur';
      case 'rose':
        return 'une rose';
      case 'diamond':
        return 'un diamant';
      case 'crown':
        return 'une couronne';
      default:
        return 'un cadeau';
    }
  }

  bool _shouldRotate(String giftId) {
    return ['diamond', 'crown'].contains(giftId);
  }

  @override
  void dispose() {
    for (final animation in _activeAnimations) {
      animation.dispose();
    }
    super.dispose();
  }
}

// ✅ CLASSE POUR GÉRER UNE ANIMATION DE CADEAU
class GiftAnimationData {
  final VirtualGift gift;
  final TickerProvider vsync;
  final VoidCallback onComplete;
  
  late AnimationController mainController;
  late AnimationController particleController;
  late AnimationController textController;
  
  late Animation<double> scaleAnimation;
  late Animation<double> opacityAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> rotationAnimation;
  late Animation<double> particleAnimation;
  late Animation<double> textScaleAnimation;
  late Animation<double> textOpacityAnimation;
  
  final List<Particle> particles = [];

  GiftAnimationData({
    required this.gift,
    required this.vsync,
    required this.onComplete,
  }) {
    _initializeAnimations();
    _generateParticles();
  }

  void _initializeAnimations() {
    // Contrôleurs
    mainController = AnimationController(
      duration: Duration(milliseconds: gift.giftId == 'heart' ? 2000 : 3000),
      vsync: vsync,
    );
    
    particleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: vsync,
    );
    
    textController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: vsync,
    );
    
    // Animations
    scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: mainController,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    ));
    
    opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: mainController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));
    
    slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(0.0, -1.0),
    ).animate(CurvedAnimation(
      parent: mainController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: mainController,
      curve: Curves.linear,
    ));
    
    particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: particleController,
      curve: Curves.easeOut,
    ));
    
    textScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: textController,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));
    
    textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: textController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));
  }

  void _generateParticles() {
    final random = Random();
    final particleCount = gift.quantity * 5 + 10;
    
    for (int i = 0; i < particleCount; i++) {
      particles.add(Particle(
        startPosition: Offset(
          random.nextDouble() * 100 - 50,
          random.nextDouble() * 100 - 50,
        ),
        endPosition: Offset(
          random.nextDouble() * 300 - 150,
          random.nextDouble() * 300 - 150,
        ),
        color: _getParticleColor(),
        size: random.nextDouble() * 6 + 2,
        delay: random.nextDouble() * 0.5,
        emoji: _getParticleEmoji(),
      ));
    }
  }

  Color _getParticleColor() {
    switch (gift.giftId) {
      case 'heart':
        return Colors.red;
      case 'diamond':
        return Colors.blue;
      case 'crown':
        return Colors.yellow;
      case 'rose':
        return Colors.pink;
      default:
        return Colors.white;
    }
  }

  String _getParticleEmoji() {
    switch (gift.giftId) {
      case 'heart':
        return '❤️';
      case 'diamond':
        return '💎';
      case 'crown':
        return '👑';
      case 'rose':
        return '🌸';
      default:
        return '✨';
    }
  }

  void start() {
    mainController.forward();
    particleController.forward();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      textController.forward();
    });
    
    mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          onComplete();
        });
      }
    });
  }

  void dispose() {
    mainController.dispose();
    particleController.dispose();
    textController.dispose();
  }
}

// ✅ MODÈLE DE PARTICULE
class Particle {
  final Offset startPosition;
  final Offset endPosition;
  final Color color;
  final double size;
  final double delay;
  final String emoji;

  Particle({
    required this.startPosition,
    required this.endPosition,
    required this.color,
    required this.size,
    required this.delay,
    required this.emoji,
  });
}

// ✅ PAINTER POUR LES PARTICULES
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final Size screenSize;

  ParticlePainter({
    required this.particles,
    required this.progress,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    
    for (final particle in particles) {
      final particleProgress = (progress - particle.delay).clamp(0.0, 1.0);
      
      if (particleProgress > 0) {
        final position = center + Offset.lerp(
          particle.startPosition,
          particle.endPosition,
          Curves.easeOut.transform(particleProgress),
        )!;
        
        final opacity = (1.0 - particleProgress).clamp(0.0, 1.0);
        
        // Dessiner la particule
        final paint = Paint()
          ..color = particle.color.withOpacity(opacity)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(position, particle.size, paint);
        
        // Dessiner l'emoji si nécessaire
        if (particle.emoji.isNotEmpty && particleProgress < 0.7) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: particle.emoji,
              style: TextStyle(
                fontSize: particle.size * 2,
                color: Colors.white.withOpacity(opacity),
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          
          textPainter.layout();
          textPainter.paint(
            canvas,
            position - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ✅ PAINTER POUR L'EFFET COMBO
class ComboEffectPainter extends CustomPainter {
  final double progress;
  final Color color;

  ComboEffectPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.5) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final comboProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);
    
    // Effet de vague circulaire
    for (int i = 0; i < 3; i++) {
      final waveProgress = (comboProgress - i * 0.2).clamp(0.0, 1.0);
      final radius = waveProgress * size.width * 0.3;
      final opacity = (1.0 - waveProgress) * 0.3;
      
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawCircle(center, radius, paint);
    }
    
    // Étoiles brillantes
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) + (comboProgress * pi * 2);
      final distance = 80 + sin(comboProgress * pi * 4) * 15;
      final starPosition = center + Offset(
        cos(angle) * distance,
        sin(angle) * distance,
      );
      
      _drawStar(canvas, starPosition, 6, starPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi / 5) - pi / 2;
      final x = center.dx + cos(angle) * size;
      final y = center.dy + sin(angle) * size;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      final innerAngle = angle + pi / 5;
      final innerX = center.dx + cos(innerAngle) * size * 0.4;
      final innerY = center.dy + sin(innerAngle) * size * 0.4;
      path.lineTo(innerX, innerY);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ComboEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}