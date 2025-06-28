import 'package:flutter/material.dart';

class FloatingGiftButton extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onPressed;
  
  const FloatingGiftButton({
    super.key,
    required this.animationController,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (animationController.value * 0.1),
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: const Color(0xFFFF6B6B),
            child: const Icon(
              Icons.card_giftcard,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
