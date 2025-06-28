// lib/features/calls/providers/call_provider.dart - CORRIGÉ POUR NOTIFICATIONS PUSH
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../config/webrtc_config.dart' as config; // ✅ IMPORT CORRIGÉ
import '../../../core/models/call_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/webrtc_call_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/utils/global_keys.dart'; // ✅ IMPORT CORRIGÉ
import '../webrtc_audio_call_screen.dart';
import '../webrtc_video_call_screen.dart';
import '../incoming_call_screen.dart';

// ✅ PROVIDER PRINCIPAL POUR LES APPELS
final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier(
    ref.read(webrtcCallServiceProvider),
    ref,
  );
});

// ✅ PROVIDER POUR LES APPELS ENTRANTS
final incomingCallProvider = StreamProvider<Call?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('calls')
      .where('receiverId', isEqualTo: currentUser.id)
      .where('status', whereIn: ['calling', 'ringing'])
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    
    final doc = snapshot.docs.first;
    return Call.fromMap({...doc.data(), 'id': doc.id});
  });
});

// ✅ PROVIDER POUR L'HISTORIQUE DES APPELS
final callHistoryProvider = StreamProvider<List<CallLog>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('call_logs')
      .where('participantId', isEqualTo: currentUser.id)
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return CallLog.fromJson({...doc.data(), 'id': doc.id});
    }).toList();
  });
});

// ✅ ÉTAT DES APPELS
class CallState {
  final Call? currentCall;
  final bool isInCall;
  final bool isInitiating;
  final String? error;
  final List<String> activeRooms;
  final Map<String, UserModel> callParticipants;

  const CallState({
    this.currentCall,
    this.isInCall = false,
    this.isInitiating = false,
    this.error,
    this.activeRooms = const [],
    this.callParticipants = const {},
  });

  CallState copyWith({
    Call? currentCall,
    bool? isInCall,
    bool? isInitiating,
    String? error,
    List<String>? activeRooms,
    Map<String, UserModel>? callParticipants,
  }) {
    return CallState(
      currentCall: currentCall ?? this.currentCall,
      isInCall: isInCall ?? this.isInCall,
      isInitiating: isInitiating ?? this.isInitiating,
      error: error ?? this.error,
      activeRooms: activeRooms ?? this.activeRooms,
      callParticipants: callParticipants ?? this.callParticipants,
    );
  }
}

// ✅ NOTIFIER POUR GÉRER LES APPELS
class CallNotifier extends StateNotifier<CallState> {
  final WebRTCCallService _webrtcService;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  StreamSubscription? _incomingCallSubscription;
  Timer? _callTimeoutTimer;

  CallNotifier(this._webrtcService, this._ref) : super(const CallState()) {
    _initializeIncomingCallListener();
  }

  // ✅ INITIALISER L'ÉCOUTE DES APPELS ENTRANTS
  void _initializeIncomingCallListener() {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    _incomingCallSubscription = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUser.id)
        .where('status', whereIn: ['initiated', 'ringing'])
        .snapshots()
        .listen(_handleIncomingCall);
  }

  // ✅ GÉRER LES APPELS ENTRANTS
  void _handleIncomingCall(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final call = Call.fromMap({...change.doc.data() as Map<String, dynamic>, 'id': change.doc.id});
        _showIncomingCallScreen(call);
      }
    }
  }

  // ✅ INITIER UN APPEL AUDIO - CORRIGÉ POUR NOTIFICATIONS PUSH
  Future<bool> initiateAudioCall({
    required UserModel otherUser,
    required BuildContext context,
  }) async {
    try {
      state = state.copyWith(isInitiating: true, error: null);

      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      config.WebRTCConfig.logInfo('🚀 Initiation appel audio vers ${otherUser.name}');

      // ✅ ÉTAPE 1 : INITIALISER LE SERVICE WEBRTC
      final initialized = await _webrtcService.initialize(userId: currentUser.id);
      if (!initialized) {
        throw Exception('Impossible d\'initialiser WebRTC');
      }

      // ✅ ÉTAPE 2 : INITIER L'APPEL VIA LE SERVICE WEBRTC (AVEC NOTIFICATION PUSH)
      final success = await _webrtcService.initiateCall(
        targetUserId: otherUser.id,
        callerName: currentUser.name,
        callType: config.WebRTCCallType.audio, // ✅ UTILISE CONFIG.WebRTCCallType
        callerUser: currentUser, // ✅ PARAMÈTRE CRUCIAL POUR LES NOTIFICATIONS PUSH
      );

      if (!success) {
        throw Exception('Échec de l\'initiation de l\'appel WebRTC');
      }

      config.WebRTCConfig.logInfo('✅ Appel audio initié avec notification push');

      // ✅ ÉTAPE 3 : GÉNÉRER UN CHANNEL NAME ET NAVIGUER
      final callId = _uuid.v4();
      final channelName = 'audio_${currentUser.id}_${otherUser.id}_$callId';

      // Naviguer vers l'écran d'appel audio
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebRTCAudioCallScreen(
              otherUser: otherUser,
              channelName: channelName,
              isIncoming: false,
            ),
          ),
        );
      }

      state = state.copyWith(isInitiating: false);
      return true;
    } catch (e) {
      config.WebRTCConfig.logError('Erreur initier appel audio', e);
      state = state.copyWith(
        isInitiating: false,
        error: 'Impossible d\'initier l\'appel audio: $e',
      );
      return false;
    }
  }

  // ✅ INITIER UN APPEL VIDÉO - CORRIGÉ POUR NOTIFICATIONS PUSH
  Future<bool> initiateVideoCall({
    required UserModel otherUser,
    required BuildContext context,
  }) async {
    try {
      state = state.copyWith(isInitiating: true, error: null);

      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      config.WebRTCConfig.logInfo('🚀 Initiation appel vidéo vers ${otherUser.name}');

      // ✅ ÉTAPE 1 : INITIALISER LE SERVICE WEBRTC
      final initialized = await _webrtcService.initialize(userId: currentUser.id);
      if (!initialized) {
        throw Exception('Impossible d\'initialiser WebRTC');
      }

      // ✅ ÉTAPE 2 : INITIER L'APPEL VIA LE SERVICE WEBRTC (AVEC NOTIFICATION PUSH)
      final success = await _webrtcService.initiateCall(
        targetUserId: otherUser.id,
        callerName: currentUser.name,
        callType: config.WebRTCCallType.video, // ✅ UTILISE CONFIG.WebRTCCallType
        callerUser: currentUser, // ✅ PARAMÈTRE CRUCIAL POUR LES NOTIFICATIONS PUSH
      );

      if (!success) {
        throw Exception('Échec de l\'initiation de l\'appel WebRTC');
      }

      config.WebRTCConfig.logInfo('✅ Appel vidéo initié avec notification push');

      // ✅ ÉTAPE 3 : GÉNÉRER UN CHANNEL NAME ET NAVIGUER
      final callId = _uuid.v4();
      final channelName = 'video_${currentUser.id}_${otherUser.id}_$callId';

      // Naviguer vers l'écran d'appel vidéo
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebRTCVideoCallScreen(
              otherUser: otherUser,
              channelName: channelName,
              isIncoming: false,
            ),
          ),
        );
      }

      state = state.copyWith(isInitiating: false);
      return true;
    } catch (e) {
      config.WebRTCConfig.logError('Erreur initier appel vidéo', e);
      state = state.copyWith(
        isInitiating: false,
        error: 'Impossible d\'initier l\'appel vidéo: $e',
      );
      return false;
    }
  }

  // ✅ AFFICHER L'ÉCRAN D'APPEL ENTRANT
  void _showIncomingCallScreen(Call call) async {
    try {
      // Récupérer les infos de l'appelant
      final callerDoc = await _firestore.collection('users').doc(call.callerId).get();
      if (!callerDoc.exists) return;

      final caller = UserModel.fromMap(callerDoc.data()!, callerDoc.id);

      // Jouer la sonnerie
      await AudioService.instance.playRingtone();

      // Mettre à jour le statut à "ringing"
      await _updateCallStatus(call.id, CallStatus.ringing);

      // Démarrer timer d'auto-refus (30 secondes)
      _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
        _declineCall(call.id);
      });

      // Navigation vers l'écran d'appel entrant
      final context = NavigationUtils.context;
      if (context != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IncomingCallScreen(
              call: call,
              caller: caller,
              onAccept: () => _acceptCall(call, caller, context),
              onDecline: () => _declineCall(call.id),
            ),
          ),
        );
      }
    } catch (e) {
      config.WebRTCConfig.logError('Erreur affichage appel entrant', e);
    }
  }

  // ✅ ACCEPTER UN APPEL
  Future<void> _acceptCall(Call call, UserModel caller, BuildContext context) async {
    try {
      _callTimeoutTimer?.cancel();
      await AudioService.instance.stopRingtone();
      await AudioService.instance.playCallAcceptSound();

      // ✅ ACCEPTER L'APPEL VIA LE SERVICE WEBRTC
      final success = await _webrtcService.acceptIncomingCall(
        roomId: call.channelName,
        callType: call.hasVideo ? config.WebRTCCallType.video : config.WebRTCCallType.audio,
      );

      if (!success) {
        throw Exception('Échec de l\'acceptation de l\'appel WebRTC');
      }

      // Mettre à jour le statut
      await _updateCallStatus(call.id, CallStatus.answered);

      // Naviguer vers l'écran d'appel approprié
      if (context.mounted) {
        Navigator.pop(context); // Fermer l'écran d'appel entrant

        if (call.hasVideo) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebRTCVideoCallScreen(
                otherUser: caller,
                channelName: call.channelName,
                isIncoming: true,
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebRTCAudioCallScreen(
                otherUser: caller,
                channelName: call.channelName,
                isIncoming: true,
              ),
            ),
          );
        }

        // Marquer l'appel comme terminé
        await _updateCallStatus(call.id, CallStatus.ended);
      }
    } catch (e) {
      config.WebRTCConfig.logError('Erreur accepter appel', e);
    }
  }

  // ✅ REFUSER UN APPEL
  Future<void> _declineCall(String callId) async {
    try {
      _callTimeoutTimer?.cancel();
      await AudioService.instance.stopRingtone();
      await AudioService.instance.playCallDeclineSound();

      // ✅ REFUSER L'APPEL VIA LE SERVICE WEBRTC
      await _webrtcService.declineIncomingCall(roomId: callId);

      await _updateCallStatus(callId, CallStatus.declined);

      // Fermer l'écran d'appel entrant si ouvert
      final context = NavigationUtils.context;
      if (context != null && context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      config.WebRTCConfig.logError('Erreur refuser appel', e);
    }
  }

  // ✅ METTRE À JOUR LE STATUT D'UN APPEL
  Future<void> _updateCallStatus(String callId, CallStatus status) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
      };

      if (status == CallStatus.answered) {
        updateData['startedAt'] = FieldValue.serverTimestamp();
      } else if (status == CallStatus.ended) {
        updateData['endedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('calls').doc(callId).update(updateData);

      // Créer un log d'appel si terminé
      if (status == CallStatus.ended || status == CallStatus.declined || status == CallStatus.missed) {
        await _createCallLog(callId);
      }
    } catch (e) {
      config.WebRTCConfig.logError('Erreur mise à jour statut appel', e);
    }
  }

  // ✅ CRÉER UN LOG D'APPEL
  Future<void> _createCallLog(String callId) async {
    try {
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) return;

      final call = Call.fromMap({...callDoc.data()!, 'id': callDoc.id});
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) return;

      // Calculer la durée
      Duration duration = Duration.zero;
      if (call.startedAt != null && call.endedAt != null) {
        duration = call.endedAt!.difference(call.startedAt!);
      }

      // Déterminer l'autre utilisateur et le type d'appel
      final isIncoming = call.receiverId == currentUser.id;
      final otherUserId = isIncoming ? call.callerId : call.receiverId;
      final wasAnswered = call.status == CallStatus.ended;

      final callLog = CallLog(
        id: _uuid.v4(),
        callId: callId,
        participantId: currentUser.id,
        otherUserId: otherUserId,
        type: call.type,
        duration: duration,
        timestamp: call.createdAt,
        wasAnswered: wasAnswered,
        isIncoming: isIncoming,
      );

      await _firestore.collection('call_logs').add(callLog.toJson());
    } catch (e) {
      config.WebRTCConfig.logError('Erreur création log appel', e);
    }
  }

  // ✅ OBTENIR L'HISTORIQUE DES APPELS
  Stream<List<CallLog>> getCallHistory() {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('call_logs')
        .where('participantId', isEqualTo: currentUser.id)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CallLog.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    });
  }

  // ✅ RAPPELER UN CONTACT
  Future<bool> redialCall({
    required String otherUserId,
    required bool isVideoCall,
    required BuildContext context,
  }) async {
    try {
      // Récupérer les infos de l'autre utilisateur
      final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
      if (!otherUserDoc.exists) {
        throw Exception('Utilisateur introuvable');
      }

      final otherUser = UserModel.fromMap(otherUserDoc.data()!, otherUserDoc.id);

      // Initier l'appel approprié
      if (isVideoCall) {
        return await initiateVideoCall(otherUser: otherUser, context: context);
      } else {
        return await initiateAudioCall(otherUser: otherUser, context: context);
      }
    } catch (e) {
      config.WebRTCConfig.logError('Erreur rappel', e);
      state = state.copyWith(error: 'Impossible de rappeler: $e');
      return false;
    }
  }

  // ✅ VÉRIFIER SI UN UTILISATEUR EST EN APPEL
  Future<bool> isUserInCall(String userId) async {
    try {
      final activeCalls = await _firestore
          .collection('calls')
          .where('status', isEqualTo: 'answered')
          .get();

      for (final doc in activeCalls.docs) {
        final call = Call.fromMap({...doc.data(), 'id': doc.id});
        if (call.callerId == userId || call.receiverId == userId) {
          return true;
        }
      }

      return false;
    } catch (e) {
      config.WebRTCConfig.logError('Erreur vérification utilisateur en appel', e);
      return false;
    }
  }

  // ✅ NETTOYER LES ANCIENS APPELS
  Future<void> cleanupOldCalls() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(hours: 1));
      final oldCalls = await _firestore
          .collection('calls')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .where('status', whereIn: ['initiated', 'ringing'])
          .get();

      final batch = _firestore.batch();
      for (final doc in oldCalls.docs) {
        batch.update(doc.reference, {'status': 'missed'});
      }

      await batch.commit();
    } catch (e) {
      config.WebRTCConfig.logError('Erreur nettoyage anciens appels', e);
    }
  }

  // ✅ EFFACER L'ERREUR
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _callTimeoutTimer?.cancel();
    super.dispose();
  }
}

// ✅ EXTENSION UTILE POUR LES APPELS
extension CallStateExtension on CallState {
  bool get hasActiveCall => currentCall != null && isInCall;
  bool get canMakeCall => !isInCall && !isInitiating;
  bool get hasError => error != null;
}

// ✅ PROVIDER POUR LES STATS D'APPELS
final callStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return {};

  final callLogs = await FirebaseFirestore.instance
      .collection('call_logs')
      .where('participantId', isEqualTo: currentUser.id)
      .get();

  final totalCalls = callLogs.docs.length;
  final answeredCalls = callLogs.docs.where((doc) => doc.data()['wasAnswered'] == true).length;
  final videoCalls = callLogs.docs.where((doc) => doc.data()['type'] == 'video').length;
  final totalDuration = callLogs.docs.fold<int>(0, (total, doc) => total + (doc.data()['duration'] as int? ?? 0));

  return {
    'totalCalls': totalCalls,
    'answeredCalls': answeredCalls,
    'missedCalls': totalCalls - answeredCalls,
    'videoCalls': videoCalls,
    'audioCalls': totalCalls - videoCalls,
    'totalDurationMinutes': (totalDuration / 60).round(),
    'averageDurationMinutes': totalCalls > 0 ? (totalDuration / totalCalls / 60).round() : 0,
  };
});

// ✅ PROVIDER POUR LES APPELS ACTIFS
final activeCallsProvider = StreamProvider<List<Call>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('calls')
      .where('status', isEqualTo: 'answered')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => Call.fromMap({...doc.data(), 'id': doc.id}))
        .where((call) => call.callerId == currentUser.id || call.receiverId == currentUser.id)
        .toList();
  });
});