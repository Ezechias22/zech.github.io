// lib/shared/widgets/call_controls.dart - CONTRÔLES D'APPEL PARTAGÉS
import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  final bool isMuted;
  final bool isVideoDisabled;
  final bool isSpeakerEnabled;
  final bool isVideoCall;
  final VoidCallback onMuteToggle;
  final VoidCallback? onVideoToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onEndCall;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onBeautyToggle;
  final bool? isBeautyEnabled;

  const CallControls({
    super.key,
    required this.isMuted,
    required this.isVideoDisabled,
    required this.isSpeakerEnabled,
    required this.isVideoCall,
    required this.onMuteToggle,
    this.onVideoToggle,
    required this.onSpeakerToggle,
    required this.onEndCall,
    this.onSwitchCamera,
    this.onBeautyToggle,
    this.isBeautyEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Contrôles principaux
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute/Unmute
              _buildControlButton(
                icon: isMuted ? Icons.mic_off : Icons.mic,
                isActive: !isMuted,
                onTap: onMuteToggle,
                tooltip: isMuted ? 'Activer micro' : 'Couper micro',
                activeColor: Colors.white,
                inactiveColor: Colors.red,
              ),
              
              // Vidéo (si appel vidéo)
              if (isVideoCall && onVideoToggle != null)
                _buildControlButton(
                  icon: isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                  isActive: !isVideoDisabled,
                  onTap: onVideoToggle!,
                  tooltip: isVideoDisabled ? 'Activer caméra' : 'Couper caméra',
                  activeColor: Colors.white,
                  inactiveColor: Colors.red,
                ),
              
              // Haut-parleur
              _buildControlButton(
                icon: isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
                isActive: isSpeakerEnabled,
                onTap: onSpeakerToggle,
                tooltip: isSpeakerEnabled ? 'Écouteur' : 'Haut-parleur',
                activeColor: Colors.green,
                inactiveColor: Colors.white,
              ),
              
              // Changer caméra (si appel vidéo)
              if (isVideoCall && onSwitchCamera != null)
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  isActive: true,
                  onTap: onSwitchCamera!,
                  tooltip: 'Changer caméra',
                  activeColor: Colors.white,
                  inactiveColor: Colors.white,
                ),
              
              // Raccrocher
              _buildControlButton(
                icon: Icons.call_end,
                isActive: false,
                onTap: onEndCall,
                tooltip: 'Raccrocher',
                activeColor: Colors.white,
                inactiveColor: Colors.white,
                backgroundColor: Colors.red,
                size: 70,
              ),
            ],
          ),
          
          // Contrôles secondaires (si appel vidéo)
          if (isVideoCall && (onBeautyToggle != null || isBeautyEnabled != null)) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Filtres beauté
                if (onBeautyToggle != null)
                  _buildSecondaryControlButton(
                    icon: Icons.face_retouching_natural,
                    isActive: isBeautyEnabled ?? false,
                    onTap: onBeautyToggle!,
                    tooltip: 'Filtres beauté',
                    activeColor: Colors.pink,
                    inactiveColor: Colors.white,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
    required Color activeColor,
    required Color inactiveColor,
    Color? backgroundColor,
    double size = 60,
  }) {
    final bgColor = backgroundColor ?? 
        (isActive ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1));
    final iconColor = isActive ? activeColor : inactiveColor;
    
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? activeColor.withOpacity(0.5) : Colors.white.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
    required Color activeColor,
    required Color inactiveColor,
    double size = 45,
  }) {
    final bgColor = isActive 
        ? activeColor.withOpacity(0.2) 
        : Colors.white.withOpacity(0.1);
    final iconColor = isActive ? activeColor : inactiveColor;
    
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? activeColor : Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }
}

// ✅ CONTRÔLES POUR LIVE STREAMING
class LiveStreamControls extends StatelessWidget {
  final bool isMuted;
  final bool isVideoDisabled;
  final bool isBeautyEnabled;
  final bool isHost;
  final VoidCallback onMuteToggle;
  final VoidCallback onVideoToggle;
  final VoidCallback onSwitchCamera;
  final VoidCallback onBeautyToggle;
  final VoidCallback onEndLive;
  final VoidCallback? onInviteGuest;
  final VoidCallback? onManageGuests;
  final VoidCallback? onLiveSettings;

  const LiveStreamControls({
    super.key,
    required this.isMuted,
    required this.isVideoDisabled,
    required this.isBeautyEnabled,
    required this.isHost,
    required this.onMuteToggle,
    required this.onVideoToggle,
    required this.onSwitchCamera,
    required this.onBeautyToggle,
    required this.onEndLive,
    this.onInviteGuest,
    this.onManageGuests,
    this.onLiveSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Contrôles pour le host
          if (isHost) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute
                _buildLiveControlButton(
                  icon: isMuted ? Icons.mic_off : Icons.mic,
                  isActive: !isMuted,
                  onTap: onMuteToggle,
                  color: isMuted ? Colors.red : Colors.white,
                ),
                
                // Vidéo
                _buildLiveControlButton(
                  icon: isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                  isActive: !isVideoDisabled,
                  onTap: onVideoToggle,
                  color: isVideoDisabled ? Colors.red : Colors.white,
                ),
                
                // Changer caméra
                _buildLiveControlButton(
                  icon: Icons.flip_camera_ios,
                  isActive: true,
                  onTap: onSwitchCamera,
                  color: Colors.white,
                ),
                
                // Filtres beauté
                _buildLiveControlButton(
                  icon: Icons.face_retouching_natural,
                  isActive: isBeautyEnabled,
                  onTap: onBeautyToggle,
                  color: isBeautyEnabled ? Colors.pink : Colors.white,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Contrôles de gestion
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Inviter guest
                if (onInviteGuest != null)
                  _buildLiveControlButton(
                    icon: Icons.person_add,
                    isActive: true,
                    onTap: onInviteGuest!,
                    color: Colors.blue,
                    size: 45,
                  ),
                
                // Gérer guests
                if (onManageGuests != null)
                  _buildLiveControlButton(
                    icon: Icons.people,
                    isActive: true,
                    onTap: onManageGuests!,
                    color: Colors.green,
                    size: 45,
                  ),
                
                // Paramètres
                if (onLiveSettings != null)
                  _buildLiveControlButton(
                    icon: Icons.settings,
                    isActive: true,
                    onTap: onLiveSettings!,
                    color: Colors.grey,
                    size: 45,
                  ),
                
                // Terminer live
                _buildLiveControlButton(
                  icon: Icons.stop,
                  isActive: false,
                  onTap: onEndLive,
                  color: Colors.white,
                  backgroundColor: Colors.red,
                  size: 50,
                ),
              ],
            ),
          ] else ...[
            // Contrôles pour les viewers
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLiveControlButton(
                  icon: Icons.close,
                  isActive: false,
                  onTap: onEndLive,
                  color: Colors.white,
                  backgroundColor: Colors.red.withOpacity(0.8),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
    Color? backgroundColor,
    double size = 50,
  }) {
    final bgColor = backgroundColor ?? 
        (isActive ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.5));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}

// ✅ CONTRÔLES RAPIDES POUR APPELS
class QuickCallControls extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerEnabled;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onEndCall;
  final bool isCompact;

  const QuickCallControls({
    super.key,
    required this.isMuted,
    required this.isSpeakerEnabled,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onEndCall,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isCompact ? 40.0 : 50.0;
    
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mute
          _buildQuickButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            color: isMuted ? Colors.red : Colors.white,
            onTap: onMuteToggle,
            size: size,
          ),
          
          SizedBox(width: isCompact ? 8 : 12),
          
          // Haut-parleur
          _buildQuickButton(
            icon: isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
            color: isSpeakerEnabled ? Colors.green : Colors.white,
            onTap: onSpeakerToggle,
            size: size,
          ),
          
          SizedBox(width: isCompact ? 8 : 12),
          
          // Raccrocher
          _buildQuickButton(
            icon: Icons.call_end,
            color: Colors.white,
            backgroundColor: Colors.red,
            onTap: onEndCall,
            size: size,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}

// ✅ CONTRÔLES POUR PICTURE-IN-PICTURE
class PipCallControls extends StatelessWidget {
  final bool isMuted;
  final bool isVideoEnabled;
  final VoidCallback onMuteToggle;
  final VoidCallback? onVideoToggle;
  final VoidCallback onEndCall;
  final VoidCallback onExpand;

  const PipCallControls({
    super.key,
    required this.isMuted,
    required this.isVideoEnabled,
    required this.onMuteToggle,
    this.onVideoToggle,
    required this.onEndCall,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mute
          _buildPipButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            color: isMuted ? Colors.red : Colors.white,
            onTap: onMuteToggle,
          ),
          
          // Vidéo (si disponible)
          if (onVideoToggle != null) ...[
            const SizedBox(width: 8),
            _buildPipButton(
              icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              color: isVideoEnabled ? Colors.white : Colors.red,
              onTap: onVideoToggle!,
            ),
          ],
          
          const SizedBox(width: 8),
          
          // Agrandir
          _buildPipButton(
            icon: Icons.fullscreen,
            color: Colors.white,
            onTap: onExpand,
          ),
          
          const SizedBox(width: 8),
          
          // Raccrocher
          _buildPipButton(
            icon: Icons.call_end,
            color: Colors.white,
            backgroundColor: Colors.red,
            onTap: onEndCall,
          ),
        ],
      ),
    );
  }

  Widget _buildPipButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 16,
        ),
      ),
    );
  }
}