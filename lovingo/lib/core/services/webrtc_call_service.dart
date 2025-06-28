// lib/core/services/webrtc_call_service.dart - IMPORTS CORRIGÉS
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ IMPORTS CLARIFIÉS POUR ÉVITER LES CONFLITS
import '../../config/webrtc_config.dart' as config;
import '../models/call_model.dart' hide WebRTCConnectionState, WebRTCCallType; // ✅ Cache les types dupliqués
import '../models/user_model.dart';
import 'signaling_service.dart';
import 'call_notification_service.dart';

final webrtcCallServiceProvider = Provider<WebRTCCallService>((ref) {
  return WebRTCCallService(
    ref.read(signalingServiceProvider),
    ref.read(callNotificationServiceProvider),
  );
});

class WebRTCCallService {
  final SignalingService _signalingService;
  final CallNotificationService _notificationService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // WebRTC Core
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // État de la connexion - ✅ UTILISE CONFIG.WebRTCConnectionState
  bool _isInitialized = false;
  bool _isConnected = false;
  config.WebRTCConnectionState _connectionState = config.WebRTCConnectionState.disconnected;
  
  // État d'appel
  String? _currentUserId;
  bool _isInCall = false;
  
  // Callbacks - ✅ UTILISE CONFIG.WebRTCConnectionState
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(config.WebRTCConnectionState)? onConnectionStateChanged;
  Function(String)? onError;
  Function(Map<String, dynamic>)? onIncomingCall;
  
  // Streams controllers
  final StreamController<MediaStream> _localStreamController = StreamController.broadcast();
  final StreamController<MediaStream> _remoteStreamController = StreamController.broadcast();
  final StreamController<config.WebRTCConnectionState> _connectionStateController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _incomingCallController = StreamController.broadcast();
  
  // Getters
  Stream<MediaStream> get localStreamStream => _localStreamController.stream;
  Stream<MediaStream> get remoteStreamStream => _remoteStreamController.stream;
  Stream<config.WebRTCConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get incomingCallStream => _incomingCallController.stream;
  
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isInCall => _isInCall;
  config.WebRTCConnectionState get connectionState => _connectionState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCPeerConnection? get peerConnection => _peerConnection;

  WebRTCCallService(this._signalingService, this._notificationService) {
    _initializeSignalingListeners();
  }

  /// Initialiser le service WebRTC
  Future<bool> initialize({required String userId}) async {
    try {
      if (_isInitialized) {
        config.WebRTCConfig.logInfo('WebRTC déjà initialisé');
        return true;
      }
      
      config.WebRTCConfig.logInfo('Initialisation WebRTC...');
      config.WebRTCConfig.validateConfig();
      
      _currentUserId = userId;
      
      // Initialiser le service de notifications aussi
      await _notificationService.initialize();
      
      // Se connecter au serveur signaling
      final connected = await _signalingService.connect(userId);
      if (!connected) {
        config.WebRTCConfig.logError('Impossible de se connecter au signaling server');
        return false;
      }
      
      _isInitialized = true;
      config.WebRTCConfig.logInfo('✅ WebRTC initialisé avec succès');
      return true;
    } catch (e) {
      config.WebRTCConfig.logError('Erreur initialisation WebRTC', e);
      return false;
    }
  }

  /// 🚀 INITIER UN APPEL AVEC NOTIFICATION PUSH - ✅ TYPES CLARIFIÉS
  Future<bool> initiateCall({
    required String targetUserId,
    required String callerName,
    required config.WebRTCCallType callType, // ✅ UTILISE CONFIG.WebRTCCallType
    required UserModel callerUser,
  }) async {
    try {
      if (!_isInitialized) {
        config.WebRTCConfig.logError('WebRTC non initialisé');
        return false;
      }

      if (_isInCall) {
        config.WebRTCConfig.logError('Déjà en appel');
        return false;
      }

      // Générer ID de room unique
      final roomId = 'channel_${_currentUserId}_${targetUserId}_${DateTime.now().millisecondsSinceEpoch}';
      
      config.WebRTCConfig.logInfo('📞 Initiation appel vers $targetUserId');
      config.WebRTCConfig.logInfo('   Room ID: $roomId');
      config.WebRTCConfig.logInfo('   Type: $callType');

      // ✅ ÉTAPE 1 : CRÉER L'APPEL DANS FIRESTORE
      final call = Call(
        id: roomId,
        callerId: _currentUserId!,
        receiverId: targetUserId,
        channelName: roomId,
        type: callType == config.WebRTCCallType.video ? CallType.video : CallType.audio, // ✅ CONVERSION DE TYPE
        status: CallStatus.ringing,
        createdAt: DateTime.now(),
        hasVideo: callType == config.WebRTCCallType.video,
        metadata: {
          'callerName': callerName,
          'isIncoming': false,
        },
      );

      await _firestore.collection('calls').doc(roomId).set(call.toMap());

      // ✅ ÉTAPE 2 : ENVOYER NOTIFICATION PUSH (LE PLUS IMPORTANT)
      await _notificationService.sendCallNotification(
        receiverId: targetUserId,
        call: call,
        caller: callerUser,
      );

      // ✅ ÉTAPE 3 : ENVOYER AUSSI VIA WEBSOCKET (pour les apps ouvertes)
      try {
        await _signalingService.sendCustomMessage(
          type: 'initiateCall',
          data: {
            'targetUserId': targetUserId,
            'callerName': callerName,
            'callType': callType.name,
            'roomId': roomId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
      } catch (e) {
        // WebSocket peut échouer, mais c'est OK si la notification push marche
        config.WebRTCConfig.logInfo('WebSocket échoué, notification push envoyée: $e');
      }

      config.WebRTCConfig.logInfo('✅ Appel initié avec notification push');
      return true;
      
    } catch (e) {
      config.WebRTCConfig.logError('Erreur initiation appel', e);
      return false;
    }
  }

  /// Accepter un appel entrant - ✅ TYPES CLARIFIÉS
  Future<bool> acceptIncomingCall({
    required String roomId,
    required config.WebRTCCallType callType, // ✅ UTILISE CONFIG.WebRTCCallType
  }) async {
    try {
      config.WebRTCConfig.logInfo('✅ Acceptation appel entrant - Room: $roomId');
      
      // Mettre à jour le statut dans Firestore
      await _firestore.collection('calls').doc(roomId).update({
        'status': CallStatus.answered.name,
        'startedAt': FieldValue.serverTimestamp(),
      });
      
      // Démarrer l'appel normalement
      final success = await startCall(
        roomId: roomId,
        userId: _currentUserId!,
        callType: callType,
        metadata: {'isIncomingCall': true},
      );
      
      if (success) {
        _isInCall = true;
        config.WebRTCConfig.logInfo('✅ Appel entrant accepté avec succès');
      }
      
      return success;
    } catch (e) {
      config.WebRTCConfig.logError('Erreur acceptation appel entrant', e);
      return false;
    }
  }

  /// Refuser un appel entrant
  Future<void> declineIncomingCall({required String roomId}) async {
    try {
      config.WebRTCConfig.logInfo('❌ Refus appel entrant - Room: $roomId');
      
      // Mettre à jour le statut dans Firestore
      await _firestore.collection('calls').doc(roomId).update({
        'status': CallStatus.declined.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      
      config.WebRTCConfig.logInfo('✅ Notification de refus envoyée');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur refus appel entrant', e);
    }
  }

  /// Démarrer un appel - ✅ TYPES CLARIFIÉS
  Future<bool> startCall({
    required String roomId,
    required String userId,
    required config.WebRTCCallType callType, // ✅ UTILISE CONFIG.WebRTCCallType
    Map<String, dynamic>? metadata,
  }) async {
    try {
      config.WebRTCConfig.logInfo('Démarrage appel: $roomId ($callType)');
      
      // 1. Initialiser si nécessaire
      if (!_isInitialized) {
        final initialized = await initialize(userId: userId);
        if (!initialized) return false;
      }
      
      // 2. Créer la peer connection
      await _createPeerConnection();
      
      // 3. Obtenir les médias locaux
      final hasLocalStream = await _getUserMedia(callType);
      if (!hasLocalStream) {
        config.WebRTCConfig.logError('Impossible d\'obtenir les médias locaux');
        return false;
      }
      
      // 4. Rejoindre la room
      final joined = await _signalingService.joinRoom(
        roomId: roomId,
        callType: callType,
        metadata: metadata,
      );
      
      if (!joined) {
        config.WebRTCConfig.logError('Impossible de rejoindre la room');
        return false;
      }
      
      // 5. Enregistrer dans Firestore
      await _createFirestoreCallRoom(roomId, userId, callType);
      
      _isInCall = true;
      _updateConnectionState(config.WebRTCConnectionState.connecting);
      return true;
    } catch (e) {
      config.WebRTCConfig.logError('Erreur démarrage appel', e);
      return false;
    }
  }

  /// Terminer un appel
  Future<void> endCall({String? roomId, String? userId}) async {
    try {
      config.WebRTCConfig.logInfo('Fin d\'appel');
      
      // 1. Mettre à jour Firestore
      if (roomId != null) {
        await _firestore.collection('calls').doc(roomId).update({
          'status': CallStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 2. Quitter la room signaling
      await _signalingService.leaveRoom();
      
      // 3. Fermer la peer connection
      await _closePeerConnection();
      
      // 4. Arrêter les streams
      await _stopLocalStream();
      
      // 5. Mettre à jour Firestore room
      if (roomId != null && userId != null) {
        await _updateFirestoreCallRoom(roomId, userId, false);
      }
      
      _isInCall = false;
      _updateConnectionState(config.WebRTCConnectionState.disconnected);
    } catch (e) {
      config.WebRTCConfig.logError('Erreur fin d\'appel', e);
    }
  }

  // ✅ ÉCOUTER LES APPELS ENTRANTS VIA FIRESTORE
  void _initializeSignalingListeners() {
    // Écouter les messages de signaling
    _signalingService.messageStream.listen((message) {
      _handleSignalingMessage(message);
    });
    
    // Écouter les événements de signaling
    _signalingService.eventStream.listen((event) {
      _handleSignalingEvent(event);
    });
    
    // ✅ ÉCOUTER LES APPELS ENTRANTS VIA FIRESTORE
    _listenToIncomingCalls();
  }

  // ✅ ÉCOUTER LES APPELS ENTRANTS VIA FIRESTORE
  void _listenToIncomingCalls() {
    if (_currentUserId == null) return;
    
    _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final call = Call.fromMap(change.doc.data()!);
          _handleIncomingCallFromFirestore(call);
        }
      }
    });
  }

  // ✅ GÉRER APPEL ENTRANT DEPUIS FIRESTORE
  void _handleIncomingCallFromFirestore(Call call) async {
    config.WebRTCConfig.logInfo('📞 Appel entrant reçu: ${call.id}');
    
    // Récupérer les informations de l'appelant
    final callerDoc = await _firestore.collection('users').doc(call.callerId).get();
    if (!callerDoc.exists) return;
    
    final caller = UserModel.fromMap(callerDoc.data()!, callerDoc.id);
    
    final callData = {
      'callId': call.id,
      'callerId': call.callerId,
      'callerName': caller.name,
      'roomId': call.channelName,
      'callType': call.type.name,
      'hasVideo': call.hasVideo,
      'timestamp': call.createdAt.millisecondsSinceEpoch,
    };
    
    // Notifier via stream et callback
    _incomingCallController.add(callData);
    onIncomingCall?.call(callData);
  }

  /// Créer la peer connection
  Future<void> _createPeerConnection() async {
    try {
      config.WebRTCConfig.logInfo('Création de la peer connection...');
      
      _peerConnection = await createPeerConnection(config.WebRTCConfig.rtcConfiguration);
      
      // Écouter les événements
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        config.WebRTCConfig.logInfo('Nouveau candidat ICE généré');
        
        // Envoyer via signaling - attendre que les autres participants soient connectés
        if (_signalingService.currentRoomId != null) {
          _signalingService.sendIceCandidate(
            targetUserId: 'room', // Broadcast dans la room
            candidate: candidate.toMap(),
          );
        }
      };
      
      _peerConnection!.onAddStream = (MediaStream stream) {
        config.WebRTCConfig.logInfo('Stream distant reçu');
        _remoteStream = stream;
        _remoteStreamController.add(stream);
        onRemoteStream?.call(stream);
      };
      
      _peerConnection!.onRemoveStream = (MediaStream stream) {
        config.WebRTCConfig.logInfo('Stream distant supprimé');
        _remoteStream = null;
      };
      
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        config.WebRTCConfig.logInfo('État peer connection: $state');
        
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _isConnected = true;
            _updateConnectionState(config.WebRTCConnectionState.connected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            _updateConnectionState(config.WebRTCConnectionState.connecting);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _isConnected = false;
            _updateConnectionState(config.WebRTCConnectionState.disconnected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _updateConnectionState(config.WebRTCConnectionState.failed);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _updateConnectionState(config.WebRTCConnectionState.closed);
            break;
          default:
            break;
        }
      };
      
      config.WebRTCConfig.logInfo('✅ Peer connection créée');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur création peer connection', e);
      rethrow;
    }
  }

  /// Obtenir les médias utilisateur
  Future<bool> _getUserMedia(config.WebRTCCallType callType) async {
    try {
      config.WebRTCConfig.logInfo('Demande des médias utilisateur...');
      
      final constraints = config.WebRTCConfig.getConfigForCallType(callType);
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      if (_localStream != null) {
        // Ajouter à la peer connection
        _peerConnection!.addStream(_localStream!);
        
        // Notifier les listeners
        _localStreamController.add(_localStream!);
        onLocalStream?.call(_localStream!);
        
        config.WebRTCConfig.logInfo('✅ Médias utilisateur obtenus');
        return true;
      }
      
      return false;
    } catch (e) {
      config.WebRTCConfig.logError('Erreur obtention médias', e);
      return false;
    }
  }

  /// Gérer les messages de signaling
  Future<void> _handleSignalingMessage(SignalingMessage message) async {
    try {
      switch (message.type) {
        case SignalingMessageType.offer:
          await _handleOffer(message);
          break;
        case SignalingMessageType.answer:
          await _handleAnswer(message);
          break;
        case SignalingMessageType.iceCandidate:
          await _handleIceCandidate(message);
          break;
        default:
          config.WebRTCConfig.logInfo('Message signaling non géré: ${message.type}');
      }
    } catch (e) {
      config.WebRTCConfig.logError('Erreur traitement message signaling', e);
    }
  }

  /// Gérer les événements de signaling
  void _handleSignalingEvent(SignalingEvent event) {
    switch (event.type) {
      case SignalingEventType.userJoined:
        config.WebRTCConfig.logInfo('Utilisateur rejoint: ${event.data}');
        _createOffer();
        break;
      case SignalingEventType.userLeft:
        config.WebRTCConfig.logInfo('Utilisateur parti: ${event.data}');
        break;
      case SignalingEventType.error:
        config.WebRTCConfig.logError('Erreur signaling: ${event.data}');
        onError?.call(event.data.toString());
        break;
      default:
        break;
    }
  }

  /// Créer une offre SDP
  Future<void> _createOffer() async {
    try {
      if (_peerConnection == null) return;
      
      config.WebRTCConfig.logInfo('Création de l\'offre SDP...');
      
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      await _signalingService.sendOffer(
        targetUserId: 'room', // Broadcast dans la room
        sdp: offer.toMap(),
      );
      
      config.WebRTCConfig.logInfo('✅ Offre SDP créée et envoyée');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur création offre', e);
    }
  }

  /// Gérer une offre SDP reçue
  Future<void> _handleOffer(SignalingMessage message) async {
    try {
      if (_peerConnection == null) return;
      
      config.WebRTCConfig.logInfo('Offre SDP reçue de ${message.from}');
      
      final offer = RTCSessionDescription(
        message.data['sdp']['sdp'],
        message.data['sdp']['type'],
      );
      
      await _peerConnection!.setRemoteDescription(offer);
      
      // Créer une réponse
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      await _signalingService.sendAnswer(
        targetUserId: message.from,
        sdp: answer.toMap(),
      );
      
      config.WebRTCConfig.logInfo('✅ Réponse SDP créée et envoyée');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur traitement offre', e);
    }
  }

  /// Gérer une réponse SDP reçue
  Future<void> _handleAnswer(SignalingMessage message) async {
    try {
      if (_peerConnection == null) return;
      
      config.WebRTCConfig.logInfo('Réponse SDP reçue de ${message.from}');
      
      final answer = RTCSessionDescription(
        message.data['sdp']['sdp'],
        message.data['sdp']['type'],
      );
      
      await _peerConnection!.setRemoteDescription(answer);
      config.WebRTCConfig.logInfo('✅ Réponse SDP appliquée');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur traitement réponse', e);
    }
  }

  /// Gérer un candidat ICE reçu
  Future<void> _handleIceCandidate(SignalingMessage message) async {
    try {
      if (_peerConnection == null) return;
      
      config.WebRTCConfig.logInfo('Candidat ICE reçu de ${message.from}');
      
      final candidateData = message.data['candidate'];
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      
      await _peerConnection!.addCandidate(candidate);
      config.WebRTCConfig.logInfo('✅ Candidat ICE ajouté');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur traitement candidat ICE', e);
    }
  }

  // Contrôles audio/vidéo
  Future<void> muteAudio(bool muted) async {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !muted;
      });
      config.WebRTCConfig.logInfo('Audio ${muted ? 'coupé' : 'activé'}');
    }
  }

  Future<void> muteVideo(bool muted) async {
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = !muted;
      });
      config.WebRTCConfig.logInfo('Vidéo ${muted ? 'coupée' : 'activée'}');
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
        config.WebRTCConfig.logInfo('Caméra commutée');
      }
    }
  }

  Future<void> enableSpeakerphone(bool enabled) async {
    if (_localStream != null) {
      await Helper.setSpeakerphoneOn(enabled);
      config.WebRTCConfig.logInfo('Haut-parleur ${enabled ? 'activé' : 'désactivé'}');
    }
  }

  // Gestion Firestore
  Future<void> _createFirestoreCallRoom(String roomId, String userId, config.WebRTCCallType callType) async {
    try {
      await _firestore.collection('call_rooms').doc(roomId).set({
        'participants': [userId],
        'callType': callType.name,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'createdBy': userId,
        'technology': 'webrtc',
      }, SetOptions(merge: true));
      
      config.WebRTCConfig.logInfo('✅ Room Firestore créée: $roomId');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur création room Firestore', e);
    }
  }

  Future<void> _updateFirestoreCallRoom(String roomId, String userId, bool isActive) async {
    try {
      if (isActive) {
        await _firestore.collection('call_rooms').doc(roomId).update({
          'participants': FieldValue.arrayUnion([userId]),
          'lastJoinedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('call_rooms').doc(roomId).update({
          'participants': FieldValue.arrayRemove([userId]),
          'lastLeftAt': FieldValue.serverTimestamp(),
        });
        
        // Vérifier si la room est vide
        final doc = await _firestore.collection('call_rooms').doc(roomId).get();
        if (doc.exists) {
          final participants = List<String>.from(doc.data()?['participants'] ?? []);
          if (participants.isEmpty) {
            await _firestore.collection('call_rooms').doc(roomId).update({
              'isActive': false,
              'endedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      config.WebRTCConfig.logError('Erreur mise à jour room Firestore', e);
    }
  }

  // Méthodes utilitaires
  void _updateConnectionState(config.WebRTCConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(_connectionState);
      onConnectionStateChanged?.call(_connectionState);
    }
  }

  Future<void> _stopLocalStream() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      _localStream = null;
    }
  }

  Future<void> _closePeerConnection() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
  }

  // Stream des participants
  Stream<List<String>> getCallParticipants(String roomId) {
    return _firestore
        .collection('call_rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return List<String>.from(doc.data()?['participants'] ?? []);
      }
      return <String>[];
    });
  }

  // Enregistrer la durée d'appel
  Future<void> recordCallDuration({
    required String otherUserId,
    required Duration duration,
    required bool isVideoCall,
  }) async {
    try {
      await _firestore.collection('call_logs').add({
        'otherUserId': otherUserId,
        'duration': duration.inSeconds,
        'isVideoCall': isVideoCall,
        'technology': 'webrtc',
        'timestamp': FieldValue.serverTimestamp(),
      });
      config.WebRTCConfig.logInfo('✅ Durée d\'appel enregistrée: ${duration.inMinutes}min');
    } catch (e) {
      config.WebRTCConfig.logError('Erreur enregistrement durée', e);
    }
  }

  // Nettoyage
  void dispose() {
    endCall();
    _localStreamController.close();
    _remoteStreamController.close();
    _connectionStateController.close();
    _incomingCallController.close();
    _signalingService.dispose();
  }
}