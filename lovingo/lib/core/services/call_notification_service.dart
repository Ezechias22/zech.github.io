// lib/core/services/call_notification_service.dart - VERSION SANS TESTS
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';

// ✅ IMPORTS CORRIGÉS
import '../models/user_model.dart';
import '../models/call_model.dart';
import '../../features/calls/incoming_call_screen.dart';
import '../../features/calls/webrtc_video_call_screen.dart';
import '../../features/calls/webrtc_audio_call_screen.dart';
import '../../main.dart' show navigatorKey;
import 'auth_service.dart';

final callNotificationServiceProvider = Provider<CallNotificationService>((ref) {
  return CallNotificationService(ref);
});

// ✅ HANDLER GLOBAL POUR MESSAGES EN BACKGROUND (requis par Firebase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 Message background handler: ${message.messageId}');
  
  if (message.data['type'] == 'incoming_call') {
    try {
      final callerData = json.decode(message.data['caller_data'] ?? '{}');
      
      debugPrint('📞 Appel entrant en background de: ${callerData['name']}');
      
      // Ici vous pourriez afficher une notification native
      // même quand l'app est fermée avec flutter_local_notifications
      
    } catch (e) {
      debugPrint('❌ Erreur parsing message background: $e');
    }
  }
}

class CallNotificationService {
  final Ref ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  CallNotificationService(this.ref);

  UserModel? get _currentUser => ref.read(authServiceProvider).user;

  /// ✅ INITIALISER FCM DE BASE (SANS UTILISATEUR CONNECTÉ)
  Future<void> initializeBasicFCM() async {
    try {
      debugPrint('🔔 Initialisation FCM de base...');
      
      // Demander permissions de base
      await _requestNotificationPermissions();
      
      // Configurer les handlers
      _setupMessageHandlers();
      
      // Obtenir le token (mais pas l'enregistrer encore)
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('✅ Token FCM obtenu: ${token.substring(0, 20)}...');
      } else {
        debugPrint('❌ Impossible d\'obtenir le token FCM');
      }
      
      debugPrint('✅ FCM de base initialisé');
    } catch (e) {
      debugPrint('❌ Erreur initialisation FCM de base: $e');
    }
  }

  /// ✅ INITIALISER LE SERVICE COMPLET (APRÈS CONNEXION)
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initialisation service notifications complet...');
      
      // Vérifier qu'un utilisateur est connecté
      if (_currentUser == null) {
        debugPrint('❌ Pas d\'utilisateur connecté pour l\'initialisation complète');
        return;
      }
      
      debugPrint('👤 Initialisation pour: ${_currentUser!.name}');
      
      // Réinitialiser les permissions si nécessaire
      await _requestNotificationPermissions();
      
      // S'abonner aux appels entrants
      await _subscribeToIncomingCalls();
      
      // ✅ ENREGISTRER AUTOMATIQUEMENT LE TOKEN FCM
      await updateUserFCMToken();
      
      debugPrint('✅ Service notifications complet initialisé pour ${_currentUser!.name}');
    } catch (e) {
      debugPrint('❌ Erreur initialisation complète: $e');
    }
  }

  /// ✅ DEMANDER PERMISSIONS DE NOTIFICATIONS
  Future<void> _requestNotificationPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permissions notifications accordées');
      } else {
        debugPrint('❌ Permissions notifications refusées');
      }
    } catch (e) {
      debugPrint('❌ Erreur demande permissions: $e');
    }
  }

  /// ✅ CONFIGURER LES HANDLERS DE MESSAGES FIREBASE
  void _setupMessageHandlers() {
    try {
      // Messages en foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Messages quand l'app est en background mais pas fermée
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      debugPrint('✅ Handlers Firebase Messaging configurés');
    } catch (e) {
      debugPrint('❌ Erreur configuration handlers: $e');
    }
  }

  /// ✅ HANDLER POUR MESSAGES EN FOREGROUND
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 Message foreground reçu: ${message.data}');
    
    if (message.data['type'] == 'incoming_call') {
      _showIncomingCallOverlay(message.data);
    }
  }

  /// ✅ HANDLER POUR MESSAGES EN BACKGROUND
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📱 Message background reçu: ${message.data}');
    
    if (message.data['type'] == 'incoming_call') {
      _navigateToIncomingCall(message.data);
    }
  }

  /// ✅ S'ABONNER AUX APPELS ENTRANTS VIA FIRESTORE
  Future<void> _subscribeToIncomingCalls() async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      debugPrint('⚠ Pas d\'utilisateur connecté pour l\'écoute d\'appels');
      return;
    }

    try {
      debugPrint('👂 Écoute des appels entrants pour: ${currentUser.id}');
      
      _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: currentUser.id)
          .where('status', whereIn: ['initiated', 'ringing', 'calling'])
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final call = Call.fromMap({...change.doc.data()!, 'id': change.doc.id});
            debugPrint('📞 Appel entrant détecté: ${call.id} de ${call.callerId}');
            _handleIncomingCallFromFirestore(call);
          }
        }
      });
      
      debugPrint('✅ Écoute Firestore activée');
    } catch (e) {
      debugPrint('❌ Erreur activation écoute Firestore: $e');
    }
  }

  /// ✅ GÉRER APPEL ENTRANT DEPUIS FIRESTORE
  void _handleIncomingCallFromFirestore(Call call) async {
    try {
      debugPrint('📞 Traitement appel entrant: ${call.id}');
      
      // Récupérer les infos de l'appelant
      final callerDoc = await _firestore.collection('users').doc(call.callerId).get();
      if (!callerDoc.exists) {
        debugPrint('❌ Utilisateur appelant non trouvé: ${call.callerId}');
        return;
      }
      
      final caller = UserModel.fromMap(callerDoc.data()!, callerDoc.id);
      debugPrint('✅ Appelant trouvé: ${caller.name}');
      
      // Mettre à jour le statut à "ringing" si nécessaire
      if (call.status == CallStatus.initiated || call.status.toString() == 'calling') {
        await _firestore.collection('calls').doc(call.id).update({
          'status': CallStatus.ringing.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('📱 Statut mis à jour: ${call.status} → ringing');
      }
      
      // Afficher l'écran d'appel entrant
      _showIncomingCallScreen(call, caller);
      
    } catch (e) {
      debugPrint('❌ Erreur traitement appel entrant: $e');
    }
  }

  /// ✅ AFFICHER OVERLAY D'APPEL ENTRANT
  void _showIncomingCallOverlay(Map<String, dynamic> data) {
    _navigateToIncomingCall(data);
  }

  /// ✅ NAVIGUER VERS L'ÉCRAN D'APPEL ENTRANT
  void _navigateToIncomingCall(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('❌ Pas de contexte de navigation disponible');
      return;
    }

    try {
      final callData = json.decode(data['call_data'] ?? '{}');
      final callerData = json.decode(data['caller_data'] ?? '{}');
      
      final call = Call.fromMap(callData);
      final caller = UserModel.fromCallData(callerData);
      
      _showIncomingCallScreen(call, caller);
    } catch (e) {
      debugPrint('❌ Erreur parsing données appel: $e');
    }
  }

  /// ✅ AFFICHER L'ÉCRAN D'APPEL ENTRANT
  void _showIncomingCallScreen(Call call, UserModel caller) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('❌ Pas de contexte pour afficher l\'écran d\'appel');
      return;
    }

    try {
      debugPrint('🎬 Affichage écran appel entrant de: ${caller.name}');
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            call: call,
            caller: caller,
            onAccept: () => _acceptCall(call, caller),
            onDecline: () => _declineCall(call),
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur affichage écran appel: $e');
    }
  }

  /// ✅ ACCEPTER L'APPEL
  void _acceptCall(Call call, UserModel caller) async {
    try {
      debugPrint('✅ Acceptation de l\'appel: ${call.id}');
      
      // Mettre à jour le statut dans Firestore
      await _firestore.collection('calls').doc(call.id).update({
        'status': CallStatus.answered.name,
        'startedAt': FieldValue.serverTimestamp(),
      });

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        debugPrint('❌ Contexte non disponible pour navigation');
        return;
      }

      // Naviguer vers l'écran d'appel approprié
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => call.hasVideo || call.type == CallType.video
              ? WebRTCVideoCallScreen(
                  otherUser: caller,
                  channelName: call.channelName,
                  isIncoming: true,
                )
              : WebRTCAudioCallScreen(
                  otherUser: caller,
                  channelName: call.channelName,
                  isIncoming: true,
                ),
        ),
      );
      
      debugPrint('✅ Navigation vers écran d\'appel effectuée');
    } catch (e) {
      debugPrint('❌ Erreur acceptation appel: $e');
    }
  }

  /// ✅ REFUSER L'APPEL
  void _declineCall(Call call) async {
    try {
      debugPrint('❌ Refus de l\'appel: ${call.id}');
      
      // Mettre à jour le statut dans Firestore
      await _firestore.collection('calls').doc(call.id).update({
        'status': CallStatus.declined.name,
        'endedAt': FieldValue.serverTimestamp(),
      });

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pop();
      }
      
      debugPrint('✅ Appel refusé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur refus appel: $e');
    }
  }

  /// ✅ ENVOYER NOTIFICATION D'APPEL - VERSION FIREBASE FUNCTIONS
  Future<void> sendCallNotification({
    required String receiverId,
    required Call call,
    required UserModel caller,
  }) async {
    try {
      debugPrint('📤 Envoi notification via Firebase Functions...');
      debugPrint('   Destinataire: $receiverId');
      debugPrint('   Appelant: ${caller.name}');
      debugPrint('   Type: ${call.type.name}');
      
      // ✅ UTILISER FIREBASE FUNCTIONS AU LIEU D'UN BACKEND
      final callable = _functions.httpsCallable('sendCallNotification');
      
      final result = await callable.call({
        'receiverId': receiverId,
        'callData': call.toMap(),
        'callerData': caller.toCallData(),
      });
      
      if (result.data['success'] == true) {
        debugPrint('✅ Notification envoyée via Functions: ${result.data['messageId']}');
        
        // Mettre à jour le statut dans Firestore
        await _firestore.collection('calls').doc(call.id).update({
          'notificationSent': true,
          'notificationSentAt': FieldValue.serverTimestamp(),
          'notificationMessageId': result.data['messageId'],
        });
      } else {
        debugPrint('❌ Erreur Functions: ${result.data}');
        throw Exception('Erreur Firebase Functions: ${result.data}');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur envoi notification Functions: $e');
      
      // ✅ FALLBACK : Enregistrer l'échec pour retry
      try {
        await _firestore.collection('notification_failures').add({
          'receiverId': receiverId,
          'callId': call.id,
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
          'retryCount': 0,
          'method': 'firebase_functions',
        });
      } catch (logError) {
        debugPrint('❌ Erreur enregistrement échec: $logError');
      }
      
      rethrow;
    }
  }

  /// ✅ METTRE À JOUR LE TOKEN FCM DE L'UTILISATEUR
  Future<void> updateUserFCMToken() async {
    try {
      final currentUser = _currentUser;
      if (currentUser == null) {
        debugPrint('⚠ Pas d\'utilisateur connecté pour mettre à jour le token');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(currentUser.id).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'deviceInfo': {
            'platform': 'flutter',
            'lastUpdate': FieldValue.serverTimestamp(),
          }
        });
        
        debugPrint('✅ Token FCM mis à jour pour ${currentUser.name}: ${token.substring(0, 20)}...');
      } else {
        debugPrint('❌ Impossible d\'obtenir le token FCM');
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour token FCM: $e');
    }
  }

  /// ✅ SUPPRIMER LE TOKEN FCM LORS DE LA DÉCONNEXION
  Future<void> clearUserFCMToken() async {
    try {
      final currentUser = _currentUser;
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser.id).update({
        'fcmToken': FieldValue.delete(),
        'lastTokenClear': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Token FCM supprimé pour ${currentUser.name}');
    } catch (e) {
      debugPrint('❌ Erreur suppression token FCM: $e');
    }
  }

  /// ✅ VÉRIFIER L'ÉTAT DU SYSTÈME DE NOTIFICATIONS
  Future<Map<String, dynamic>> checkNotificationSystemHealth() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'user_authenticated': _currentUser != null,
      'user_id': _currentUser?.id,
    };

    try {
      // 1. Vérifier permissions
      final settings = await _messaging.getNotificationSettings();
      results['permissions'] = {
        'status': settings.authorizationStatus.name,
        'alert': settings.alert.name,
        'sound': settings.sound.name,
        'badge': settings.badge.name,
      };

      // 2. Vérifier token FCM
      final token = await _messaging.getToken();
      results['fcm_token'] = {
        'exists': token != null,
        'length': token?.length ?? 0,
        'preview': token != null ? '${token.substring(0, 20)}...' : null,
      };

      // 3. Vérifier token en Firestore
      if (_currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(_currentUser!.id).get();
        final firestoreToken = userDoc.data()?['fcmToken'] as String?;
        results['firestore_token'] = {
          'exists': firestoreToken != null,
          'matches_current': firestoreToken == token,
          'preview': firestoreToken != null ? '${firestoreToken.substring(0, 20)}...' : null,
        };
      }

      // 4. Tester Firebase Functions
      try {
        final callable = _functions.httpsCallable('testCallNotification');
        final functionResult = await callable.call();
        results['firebase_functions'] = {
          'accessible': true,
          'test_success': functionResult.data['success'] == true,
          'test_message': functionResult.data['message'],
        };
      } catch (e) {
        results['firebase_functions'] = {
          'accessible': false,
          'error': e.toString(),
        };
      }

      results['overall_health'] = _calculateOverallHealth(results);
      
    } catch (e) {
      results['error'] = e.toString();
      results['overall_health'] = 'error';
    }

    return results;
  }

  /// ✅ CALCULER L'ÉTAT GLOBAL DU SYSTÈME
  String _calculateOverallHealth(Map<String, dynamic> results) {
    final hasPermissions = results['permissions']?['status'] == 'authorized';
    final hasToken = results['fcm_token']?['exists'] == true;
    final tokenMatches = results['firestore_token']?['matches_current'] == true;
    final functionsWork = results['firebase_functions']?['accessible'] == true;

    if (hasPermissions && hasToken && tokenMatches && functionsWork) {
      return 'excellent';
    } else if (hasPermissions && hasToken && functionsWork) {
      return 'good';
    } else if (hasPermissions && hasToken) {
      return 'partial';
    } else {
      return 'poor';
    }
  }

  /// ✅ NETTOYAGE
  void dispose() {
    debugPrint('🧹 CallNotificationService dispose');
  }
}