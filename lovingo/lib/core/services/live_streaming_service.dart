// lib/core/services/live_streaming_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/webrtc_config.dart';
import '../models/live_models.dart';

final liveStreamingServiceProvider = Provider<LiveStreamingService>((ref) {
  return LiveStreamingService();
});

class LiveStreamingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // État du live
  bool _isLive = false;
  bool _isHost = false;
  String? _currentLiveId;
  LiveRoom? _currentRoom;
  
  // Streams et participants
  MediaStream? _hostStream;
  final Map<String, MediaStream> _guestStreams = {};
  final Map<String, RTCPeerConnection> _guestConnections = {};
  final List<LiveGuest> _guests = [];
  final List<LiveViewer> _viewers = [];
  
  // Statistiques live
  int _viewerCount = 0;
  int _heartCount = 0;
  int _giftCount = 0;
  Duration _liveDuration = Duration.zero;
  DateTime? _liveStartTime;
  
  // Timers
  Timer? _statsTimer;
  Timer? _durationTimer;
  
  // Streams controllers
  final StreamController<LiveRoom> _roomController = StreamController<LiveRoom>.broadcast();
  final StreamController<List<LiveGuest>> _guestsController = StreamController<List<LiveGuest>>.broadcast();
  final StreamController<List<LiveViewer>> _viewersController = StreamController<List<LiveViewer>>.broadcast();
  final StreamController<LiveStats> _statsController = StreamController<LiveStats>.broadcast();
  final StreamController<LiveMessage> _messagesController = StreamController<LiveMessage>.broadcast();
  final StreamController<VirtualGift> _giftsController = StreamController<VirtualGift>.broadcast();
  
  // Getters publics
  Stream<LiveRoom> get roomStream => _roomController.stream;
  Stream<List<LiveGuest>> get guestsStream => _guestsController.stream;
  Stream<List<LiveViewer>> get viewersStream => _viewersController.stream;
  Stream<LiveStats> get statsStream => _statsController.stream;
  Stream<LiveMessage> get messagesStream => _messagesController.stream;
  Stream<VirtualGift> get giftsStream => _giftsController.stream;
  
  bool get isLive => _isLive;
  bool get isHost => _isHost;
  String? get currentLiveId => _currentLiveId;
  LiveRoom? get currentRoom => _currentRoom;
  int get viewerCount => _viewerCount;
  int get guestCount => _guests.length;
  MediaStream? get hostStream => _hostStream;
  Map<String, MediaStream> get guestStreams => Map.unmodifiable(_guestStreams);

  Future<bool> startLive({
    required String hostId,
    required String title,
    String? description,
    List<String>? tags,
    Map<String, dynamic>? settings,
  }) async {
    try {
      if (!await _checkPermissions()) {
        WebRTCConfig.logError('Permissions non accordées', 'Camera/microphone');
        return false;
      }

      _currentLiveId = 'live_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      _isHost = true;
      _liveStartTime = DateTime.now();
      
      _hostStream = await navigator.mediaDevices.getUserMedia(
        WebRTCConfig.getLiveStreamConstraints(videoQuality: 'high', audio: true)
      );
      
      if (_hostStream == null) {
        WebRTCConfig.logError('Impossible d\'obtenir les médias du host', null);
        return false;
      }
      
      await _createLiveRoom(hostId, title, description, tags, settings);
      _startTimers();
      
      _isLive = true;
      WebRTCConfig.logInfo('Live démarré: $_currentLiveId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur démarrage live', e);
      return false;
    }
  }

  Future<bool> joinLiveAsViewer({
    required String liveId,
    required String viewerId,
  }) async {
    try {
      _currentLiveId = liveId;
      _isHost = false;
      
      final liveDoc = await _firestore.collection('live_rooms').doc(liveId).get();
      if (!liveDoc.exists || !(liveDoc.data()?['isActive'] ?? false)) {
        WebRTCConfig.logError('Live inexistant ou inactif', liveId);
        return false;
      }
      
      _currentRoom = LiveRoom.fromFirestore(liveDoc);
      await _addViewer(viewerId);
      
      _isLive = true;
      WebRTCConfig.logInfo('Viewer a rejoint le live: $liveId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur rejoindre live viewer', e);
      return false;
    }
  }

  Future<bool> inviteGuest({
    required String guestId,
    String? message,
  }) async {
    try {
      if (!_isHost) {
        WebRTCConfig.logError('Seul le host peut inviter', guestId);
        return false;
      }
      
      if (_guests.length >= WebRTCConfig.maxGuestsInLive) {
        WebRTCConfig.logError('Limite de guests atteinte', _guests.length);
        return false;
      }
      
      await _firestore.collection('live_invitations').add({
        'liveId': _currentLiveId,
        'hostId': _currentRoom?.hostId,
        'guestId': guestId,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      WebRTCConfig.logInfo('Invitation envoyée à: $guestId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur invitation guest', e);
      return false;
    }
  }

  Future<bool> acceptGuestInvitation({
    required String invitationId,
    required String guestId,
  }) async {
    try {
      final guestStream = await navigator.mediaDevices.getUserMedia(
        WebRTCConfig.getLiveStreamConstraints(videoQuality: 'medium', audio: true)
      );
      
      if (guestStream == null) {
  WebRTCConfig.logError('Médias guest non disponibles', guestId);
  return false;
}
      
      final peerConnection = await createPeerConnection(WebRTCConfig.rtcConfiguration);
      peerConnection.addStream(guestStream);
      
      _guestConnections[guestId] = peerConnection;
      _guestStreams[guestId] = guestStream;
      
      peerConnection.onAddStream = (stream) {
        _guestStreams[guestId] = stream;
        _guestsController.add(_guests);
      };
      
      await _firestore.collection('live_invitations').doc(invitationId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      await _addGuest(guestId);
      WebRTCConfig.logInfo('Guest a rejoint: $guestId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur acceptation guest', e);
      return false;
    }
  }

  Future<void> removeGuest(String guestId) async {
    try {
      if (!_isHost) return;
      
      final connection = _guestConnections[guestId];
      if (connection != null) await connection.close();
      
      final stream = _guestStreams[guestId];
      if (stream != null) stream.getTracks().forEach((track) => track.stop());
      
      _guests.removeWhere((guest) => guest.userId == guestId);
      _guestsController.add(_guests);
      
      if (_currentLiveId != null) {
        await _firestore.collection('live_rooms').doc(_currentLiveId!).update({
          'guests': _guests.map((g) => g.toMap()).toList(),
          'guestCount': _guests.length,
        });
      }
      WebRTCConfig.logInfo('Guest supprimé: $guestId');
    } catch (e) {
      WebRTCConfig.logError('Erreur suppression guest', e);
    }
  }

  Future<void> sendLiveMessage({
    required String message,
    required String senderId,
    String? senderName,
  }) async {
    try {
      final liveMessage = LiveMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        senderName: senderName ?? 'Utilisateur',
        message: message,
        timestamp: DateTime.now(),
        type: LiveMessageType.chat,
      );
      
      await _firestore.collection('live_messages').add(liveMessage.toMap());
      _messagesController.add(liveMessage);
      _simulateIncomingMessages();
    } catch (e) {
      WebRTCConfig.logError('Erreur envoi message live', e);
    }
  }

  Future<void> sendVirtualGift({
    required String giftId,
    required int quantity,
    required String senderId,
    String? senderName,
    String? targetUserId,
  }) async {
    try {
      final gift = VirtualGift(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        giftId: giftId,
        quantity: quantity,
        senderId: senderId,
        senderName: senderName ?? 'Utilisateur',
        targetUserId: targetUserId,
        timestamp: DateTime.now(),
        liveId: _currentLiveId!, value: 0,
      );
      
      await _firestore.collection('virtual_gifts').add(gift.toMap());
      _giftCount += quantity;
      _heartCount += quantity;
      _giftsController.add(gift);
      WebRTCConfig.logInfo('Cadeau envoyé: $giftId x$quantity');
    } catch (e) {
      WebRTCConfig.logError('Erreur envoi cadeau', e);
    }
  }

  Future<void> endLive() async {
    try {
      _stopTimers();
      
      for (final connection in _guestConnections.values) {
        await connection.close();
      }
      _guestConnections.clear();
      
      _hostStream?.getTracks().forEach((track) => track.stop());
      for (final stream in _guestStreams.values) {
        stream.getTracks().forEach((track) => track.stop());
      }
      _guestStreams.clear();
      
      if (_currentLiveId != null) {
        final endTime = DateTime.now();
        final duration = _liveStartTime != null 
            ? endTime.difference(_liveStartTime!).inSeconds 
            : 0;
            
        await _firestore.collection('live_rooms').doc(_currentLiveId!).update({
          'isActive': false,
          'endedAt': FieldValue.serverTimestamp(),
          'finalStats': {
            'duration': duration,
            'maxViewers': _viewerCount,
            'totalHearts': _heartCount,
            'totalGifts': _giftCount,
            'guestCount': _guests.length,
          },
        });
      }
      
      _resetState();
      WebRTCConfig.logInfo('Live terminé');
    } catch (e) {
      WebRTCConfig.logError('Erreur fin live', e);
    }
  }

  // Méthodes privées
  Future<bool> _checkPermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<void> _createLiveRoom(
    String hostId,
    String title,
    String? description,
    List<String>? tags,
    Map<String, dynamic>? settings,
  ) async {
    _currentRoom = LiveRoom(
      id: _currentLiveId!,
      hostId: hostId,
      title: title,
      description: description,
      tags: tags ?? [],
      isActive: true,
      createdAt: DateTime.now(),
      settings: settings ?? {},
      viewerCount: 0,
      guestCount: 0,
      heartCount: 0,
      giftCount: 0,
    );
    
    await _firestore.collection('live_rooms').doc(_currentLiveId!).set({
      ..._currentRoom!.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _roomController.add(_currentRoom!);
  }

  Future<void> _addViewer(String viewerId) async {
    _viewerCount++;
    _viewers.add(LiveViewer(
      userId: viewerId,
      joinedAt: DateTime.now(),
    ));
    
    if (_currentLiveId != null) {
      await _firestore.collection('live_rooms').doc(_currentLiveId!).update({
        'viewerCount': _viewerCount,
      });
    }
    _viewersController.add(_viewers);
  }

  Future<void> _addGuest(String guestId) async {
    _guests.add(LiveGuest(
      userId: guestId,
      joinedAt: DateTime.now(),
      isMuted: false,
      isVideoEnabled: true,
    ));
    
    if (_currentLiveId != null) {
      await _firestore.collection('live_rooms').doc(_currentLiveId!).update({
        'guests': _guests.map((g) => g.toMap()).toList(),
        'guestCount': _guests.length,
      });
    }
    _guestsController.add(_guests);
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateStats();
    });
    
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_liveStartTime != null) {
        _liveDuration = DateTime.now().difference(_liveStartTime!);
      }
    });
  }

  void _stopTimers() {
    _statsTimer?.cancel();
    _durationTimer?.cancel();
  }

  void _updateStats() {
    final stats = LiveStats(
      viewerCount: _viewerCount,
      guestCount: _guests.length,
      heartCount: _heartCount,
      giftCount: _giftCount,
      duration: _liveDuration,
    );
    _statsController.add(stats);
  }

  void _simulateIncomingMessages() {
    final mockMessages = [
      'Super live ! ❤️',
      'Continuez comme ça ! 🎉',
      'J\'adore cette chanson 🎵',
      'Merci pour ce moment 🙏',
    ];
    
    Timer(Duration(seconds: 2 + Random().nextInt(3)), () {
      if (_isLive && Random().nextBool()) {
        final message = LiveMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: 'user_${Random().nextInt(100)}',
          senderName: 'Viewer${Random().nextInt(100)}',
          message: mockMessages[Random().nextInt(mockMessages.length)],
          timestamp: DateTime.now(),
          type: LiveMessageType.chat,
        );
        _messagesController.add(message);
      }
    });
  }

  void _resetState() {
    _isLive = false;
    _isHost = false;
    _currentLiveId = null;
    _currentRoom = null;
    _hostStream = null;
    _guests.clear();
    _viewers.clear();
    _viewerCount = 0;
    _heartCount = 0;
    _giftCount = 0;
    _liveDuration = Duration.zero;
    _liveStartTime = null;
  }

  void dispose() {
    endLive();
    _roomController.close();
    _guestsController.close();
    _viewersController.close();
    _statsController.close();
    _messagesController.close();
    _giftsController.close();
  }
}