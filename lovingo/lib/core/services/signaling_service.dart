// lib/core/services/signaling_service.dart - SERVICE DE SIGNALING WEBRTC - CORRIGÉ ET MIS À JOUR
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/webrtc_config.dart';

final signalingServiceProvider = Provider<SignalingService>((ref) {
  return SignalingService();
});

class SignalingService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _currentUserId;
  String? _currentRoomId;
  
  // Streams pour les événements
  final StreamController<SignalingMessage> _messageController = StreamController.broadcast();
  final StreamController<SignalingEvent> _eventController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();
  
  // Getters pour les streams
  Stream<SignalingMessage> get messageStream => _messageController.stream;
  Stream<SignalingEvent> get eventStream => _eventController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  
  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;

  // ✅ CONNEXION AU SERVEUR DE SIGNALING
  Future<bool> connect(String userId) async {
    try {
      if (_isConnected) {
        WebRTCConfig.logInfo('Déjà connecté au signaling server');
        return true;
      }

      _currentUserId = userId;
      WebRTCConfig.logInfo('Connexion au signaling server...');
      
      // Connexion WebSocket avec authentification
      final uri = Uri.parse('${WebRTCConfig.signalingServerUrl}?userId=$userId');
      _channel = WebSocketChannel.connect(uri);
      
      // Écouter les messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );
      
      // Attendre la confirmation de connexion (timeout 10s)
      final completer = Completer<bool>();
      Timer? timeoutTimer;
      
      late StreamSubscription subscription;
      subscription = eventStream.listen((event) {
        if (event.type == SignalingEventType.connected) {
          timeoutTimer?.cancel();
          subscription.cancel();
          completer.complete(true);
        } else if (event.type == SignalingEventType.error) {
          timeoutTimer?.cancel();
          subscription.cancel();
          completer.complete(false);
        }
      });
      
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
      
      return await completer.future;
    } catch (e) {
      WebRTCConfig.logError('Erreur connexion signaling', e);
      return false;
    }
  }

  // ✅ REJOINDRE UNE ROOM (APPEL 1-TO-1 OU LIVE) - CORRIGÉ
  Future<bool> joinRoom({
    required String roomId,
    required WebRTCCallType callType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (!_isConnected) {
        WebRTCConfig.logError('Pas connecté au signaling server');
        return false;
      }

      _currentRoomId = roomId;
      
      // 🚨 CORRECTION CRITIQUE : Ajouter roomId dans data
      final message = SignalingMessage(
        type: SignalingMessageType.joinRoom,
        from: _currentUserId!,
        to: roomId,
        data: {
          'roomId': roomId,                // ✅ AJOUT CRITIQUE - MANQUAIT !
          'callType': callType.name,       // ✅ OK
          'metadata': metadata ?? {},      // ✅ OK
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      
      sendMessage(message);
      
      // 🚨 AJOUT : Logs de debug pour vérifier le message envoyé
      WebRTCConfig.logInfo('📤 Message joinRoom envoyé:');
      WebRTCConfig.logInfo('   Room ID: $roomId');
      WebRTCConfig.logInfo('   Call Type: ${callType.name}');
      WebRTCConfig.logInfo('   Data: ${message.data}');
      
      WebRTCConfig.logInfo('Demande de rejoindre room: $roomId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur rejoindre room', e);
      return false;
    }
  }

  // ✅ QUITTER UNE ROOM
  Future<void> leaveRoom() async {
    try {
      if (_currentRoomId != null && _isConnected) {
        final message = SignalingMessage(
          type: SignalingMessageType.leaveRoom,
          from: _currentUserId!,
          to: _currentRoomId!,
          data: {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
        
        sendMessage(message);
        WebRTCConfig.logInfo('Quitter room: $_currentRoomId');
      }
      
      _currentRoomId = null;
    } catch (e) {
      WebRTCConfig.logError('Erreur quitter room', e);
    }
  }

  // ✅ ENVOYER UNE OFFRE SDP
  Future<void> sendOffer({
    required String targetUserId,
    required Map<String, dynamic> sdp,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.offer,
      from: _currentUserId!,
      to: targetUserId,
      data: {'sdp': sdp},
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Offre SDP envoyée à $targetUserId');
  }

  // ✅ ENVOYER UNE RÉPONSE SDP
  Future<void> sendAnswer({
    required String targetUserId,
    required Map<String, dynamic> sdp,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.answer,
      from: _currentUserId!,
      to: targetUserId,
      data: {'sdp': sdp},
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Réponse SDP envoyée à $targetUserId');
  }

  // ✅ ENVOYER UN CANDIDAT ICE
  Future<void> sendIceCandidate({
    required String targetUserId,
    required Map<String, dynamic> candidate,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.iceCandidate,
      from: _currentUserId!,
      to: targetUserId,
      data: {'candidate': candidate},
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Candidat ICE envoyé à $targetUserId');
  }

  // 🚨 NOUVEAU : INITIER UN APPEL
  Future<void> initiateCall({
    required String targetUserId,
    required WebRTCCallType callType,
    Map<String, dynamic>? metadata,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.initiateCall,
      from: _currentUserId!,
      to: targetUserId,
      data: {
        'callType': callType.name,
        'metadata': metadata ?? {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Initiation d\'appel vers $targetUserId');
  }

  // 🚨 NOUVEAU : ACCEPTER UN APPEL
  Future<void> acceptCall({
    required String callerId,
    Map<String, dynamic>? metadata,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.callAccepted,
      from: _currentUserId!,
      to: callerId,
      data: {
        'metadata': metadata ?? {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Appel accepté de $callerId');
  }

  // 🚨 NOUVEAU : REFUSER UN APPEL
  Future<void> declineCall({
    required String callerId,
    String? reason,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.callDeclined,
      from: _currentUserId!,
      to: callerId,
      data: {
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Appel refusé de $callerId');
  }

  // ✅ ENVOYER UN MESSAGE DE CONTRÔLE LIVE
  Future<void> sendLiveControlMessage({
    required String roomId,
    required LiveControlType controlType,
    Map<String, dynamic>? data,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.liveControl,
      from: _currentUserId!,
      to: roomId,
      data: {
        'controlType': controlType.name,
        'data': data ?? {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Message live control envoyé: ${controlType.name}');
  }

  // ✅ ENVOYER UN CADEAU VIRTUEL
  Future<void> sendVirtualGift({
    required String roomId,
    required String giftId,
    required int quantity,
    String? targetUserId,
  }) async {
    final message = SignalingMessage(
      type: SignalingMessageType.virtualGift,
      from: _currentUserId!,
      to: roomId,
      data: {
        'giftId': giftId,
        'quantity': quantity,
        'targetUserId': targetUserId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    sendMessage(message);
    WebRTCConfig.logInfo('Cadeau virtuel envoyé: $giftId x$quantity');
  }

  // ✅ ENVOYER UN MESSAGE DE CHAT LIVE
  Future<void> sendLiveChat({
    required String roomId,
    required String message,
  }) async {
    final signalingMessage = SignalingMessage(
      type: SignalingMessageType.liveChat,
      from: _currentUserId!,
      to: roomId,
      data: {
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    sendMessage(signalingMessage);
  }

  // ✅ ENVOYER UN HEARTBEAT
  void sendHeartbeat() {
    if (_isConnected) {
      final message = SignalingMessage(
        type: SignalingMessageType.heartbeat,
        from: _currentUserId!,
        to: 'server',
        data: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'roomId': _currentRoomId,
        },
      );
      
      sendMessage(message);
    }
  }

  // 🚨 NOUVEAU : ENVOYER UN MESSAGE PERSONNALISÉ
  Future<bool> sendCustomMessage({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (!_isConnected || _channel == null) {
        return false;
      }
      
      final message = {
        'type': type,
        'from': _currentUserId ?? 'unknown',
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      _channel!.sink.add(jsonEncode(message));
      WebRTCConfig.logInfo('Message personnalisé envoyé: $type');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur envoi message personnalisé', e);
      return false;
    }
  }

  // ✅ GESTION DES MESSAGES ENTRANTS - MIS À JOUR
  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> json = jsonDecode(data);
      final message = SignalingMessage.fromJson(json);
      
      WebRTCConfig.logInfo('Message reçu: ${message.type.name} de ${message.from}');
      
      // Traiter les événements spéciaux
      switch (message.type) {
        case SignalingMessageType.connected:
          _isConnected = true;
          _connectionController.add(true);
          _eventController.add(SignalingEvent(
            type: SignalingEventType.connected,
            data: message.data,
          ));
          break;
          
        case SignalingMessageType.roomJoined:
          _eventController.add(SignalingEvent(
            type: SignalingEventType.roomJoined,
            data: message.data,
          ));
          break;
          
        case SignalingMessageType.userJoined:
          _eventController.add(SignalingEvent(
            type: SignalingEventType.userJoined,
            data: message.data,
          ));
          break;
          
        case SignalingMessageType.userLeft:
          _eventController.add(SignalingEvent(
            type: SignalingEventType.userLeft,
            data: message.data,
          ));
          break;
          
        // 🚨 NOUVEAU : Gestion des appels entrants
        case SignalingMessageType.incomingCall:
          _eventController.add(SignalingEvent(
            type: SignalingEventType.incomingCall,
            data: message.data,
          ));
          break;
          
        // 🚨 NOUVEAU : Gestion des réponses d'appel
        case SignalingMessageType.callInitiated:
        case SignalingMessageType.callDeclined:
        case SignalingMessageType.callAccepted:
          // Transmettre directement aux listeners
          _messageController.add(message);
          break;
          
        case SignalingMessageType.error:
          _eventController.add(SignalingEvent(
            type: SignalingEventType.error,
            data: message.data,
          ));
          break;
          
        default:
          // Transmettre le message aux listeners
          _messageController.add(message);
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur traitement message', e);
    }
  }

  // ✅ GESTION DES ERREURS - AMÉLIORÉE POUR DEBUG
  void _handleError(dynamic error) {
    WebRTCConfig.logError('Erreur WebSocket', error);
    // 🚨 DEBUG : Afficher l'erreur détaillée
    WebRTCConfig.logError('🚨 ERREUR SIGNALING DÉTAILLÉE: $error');
    WebRTCConfig.logError('🔗 URL tentée: ${WebRTCConfig.signalingServerUrl}');
    
    _isConnected = false;
    _connectionController.add(false);
    _eventController.add(SignalingEvent(
      type: SignalingEventType.error,
      data: {'error': error.toString()},
    ));
  }

  // ✅ GESTION DE LA DÉCONNEXION
  void _handleDisconnection() {
    WebRTCConfig.logInfo('Déconnexion du signaling server');
    _isConnected = false;
    _currentRoomId = null;
    _connectionController.add(false);
    _eventController.add(SignalingEvent(
      type: SignalingEventType.disconnected,
      data: {},
    ));
  }

  // 🚨 MIS À JOUR : MÉTHODE MAINTENANT PUBLIQUE
  void sendMessage(SignalingMessage message) {
    if (_channel != null && _isConnected) {
      final json = jsonEncode(message.toJson());
      _channel!.sink.add(json);
    }
  }

  // ✅ DÉCONNEXION
  Future<void> disconnect() async {
    try {
      await leaveRoom();
      
      if (_channel != null) {
        await _channel!.sink.close();
        _channel = null;
      }
      
      _isConnected = false;
      _currentUserId = null;
      _currentRoomId = null;
      
      WebRTCConfig.logInfo('Déconnecté du signaling server');
    } catch (e) {
      WebRTCConfig.logError('Erreur déconnexion', e);
    }
  }

  // ✅ NETTOYAGE
  void dispose() {
    disconnect();
    _messageController.close();
    _eventController.close();
    _connectionController.close();
  }
}

// ✅ MODÈLE DE MESSAGE DE SIGNALING
class SignalingMessage {
  final SignalingMessageType type;
  final String from;
  final String to;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SignalingMessage({
    required this.type,
    required this.from,
    required this.to,
    required this.data,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'from': from,
    'to': to,
    'data': data,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: SignalingMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SignalingMessageType.unknown,
      ),
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

// ✅ MODÈLE D'ÉVÉNEMENT DE SIGNALING
class SignalingEvent {
  final SignalingEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SignalingEvent({
    required this.type,
    required this.data,
  }) : timestamp = DateTime.now();
}

// 🚨 MIS À JOUR : TYPES DE MESSAGES DE SIGNALING
enum SignalingMessageType {
  // Connexion
  connected,
  disconnected,
  heartbeat,
  
  // Room management
  joinRoom,
  leaveRoom,
  roomJoined,
  roomLeft,
  userJoined,
  userLeft,
  
  // WebRTC signaling
  offer,
  answer,
  iceCandidate,
  
  // 🚨 NOUVEAUX : Gestion des appels
  initiateCall,     // Pour initier un appel
  incomingCall,     // Pour recevoir un appel entrant
  callInitiated,    // Confirmation d'initiation
  callDeclined,     // Appel refusé
  callAccepted,     // Appel accepté
  
  // Live streaming
  liveControl,
  liveChat,
  virtualGift,
  liveStats,
  
  // Erreurs
  error,
  unknown,
}

// 🚨 MIS À JOUR : TYPES D'ÉVÉNEMENTS DE SIGNALING
enum SignalingEventType {
  connected,
  disconnected,
  roomJoined,
  userJoined,
  userLeft,
  incomingCall,     // 🚨 NOUVEAU : Pour les appels entrants
  error,
}

// ✅ TYPES DE CONTRÔLE LIVE
enum LiveControlType {
  startLive,
  endLive,
  inviteGuest,
  acceptInvite,
  declineInvite,
  removeGuest,
  muteGuest,
  unmuteGuest,
  promoteGuest,
  demoteGuest,
  changeLiveSettings,
}