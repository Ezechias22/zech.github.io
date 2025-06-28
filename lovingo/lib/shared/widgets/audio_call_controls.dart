import 'package:flutter/material.dart';

class AudioCallControls extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerEnabled;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onEndCall;
  final VoidCallback? onAddCall;
  final VoidCallback? onKeypad;

  const AudioCallControls({
    super.key,
    required this.isMuted,
    required this.isSpeakerEnabled,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onEndCall,
    this.onAddCall,
    this.onKeypad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          // Première rangée - contrôles principaux
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                label: isMuted ? 'Activer' : 'Muet',
                color: isMuted ? Colors.red : Colors.white,
                backgroundColor: isMuted ? Colors.white : Colors.white.withOpacity(0.2),
                onTap: onMuteToggle,
              ),
              
              _buildControlButton(
                icon: isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
                label: isSpeakerEnabled ? 'Haut-parleur' : 'Écouteur',
                color: Colors.white,
                backgroundColor: isSpeakerEnabled 
                    ? const Color(0xFF4CAF50).withOpacity(0.8)
                    : Colors.white.withOpacity(0.2),
                onTap: onSpeakerToggle,
              ),
              
              _buildControlButton(
                icon: Icons.call_end,
                label: 'Raccrocher',
                color: Colors.white,
                backgroundColor: Colors.red,
                onTap: onEndCall,
                isEndCall: true,
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Deuxième rangée - contrôles secondaires
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onKeypad != null)
                _buildSecondaryButton(
                  icon: Icons.dialpad,
                  label: 'Clavier',
                  onTap: onKeypad!,
                ),
              
              if (onAddCall != null)
                _buildSecondaryButton(
                  icon: Icons.person_add,
                  label: 'Ajouter',
                  onTap: onAddCall!,
                ),
              
              _buildSecondaryButton(
                icon: Icons.bluetooth,
                label: 'Bluetooth',
                onTap: () {
                  // TODO: Implémenter basculement Bluetooth
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
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

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.8),
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}