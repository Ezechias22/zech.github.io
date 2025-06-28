// lib/features/calls/live_controls.dart
import 'package:flutter/material.dart';

class LiveControls extends StatelessWidget {
  final bool isHost;
  final bool isMuted;
  final bool isCameraOff;
  final bool isFrontCamera;
  final bool isBeautyFilterEnabled;
  final bool isChatVisible;
  final int viewerCount;
  final VoidCallback onMute;
  final VoidCallback onCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onBeautyFilter;
  final VoidCallback onSendHearts;
  final VoidCallback onShowGiftSelection;
  final VoidCallback onToggleChat;
  final VoidCallback onShowViewersList;
  final VoidCallback onEndLive;

  const LiveControls({
    super.key,
    required this.isHost,
    required this.isMuted,
    required this.isCameraOff,
    required this.isFrontCamera,
    required this.isBeautyFilterEnabled,
    required this.isChatVisible,
    required this.viewerCount,
    required this.onMute,
    required this.onCamera,
    required this.onSwitchCamera,
    required this.onBeautyFilter,
    required this.onSendHearts,
    required this.onShowGiftSelection,
    required this.onToggleChat,
    required this.onShowViewersList,
    required this.onEndLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(); // Replace with actual controls UI
  }
}