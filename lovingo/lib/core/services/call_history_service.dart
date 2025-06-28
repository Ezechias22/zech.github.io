// lib/core/services/call_history_service.dart - SERVICE HISTORIQUE D'APPELS WEBRTC - CORRIGÉ
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/webrtc_config.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

// ✅ PROVIDER CORRIGÉ - Injecter Ref pour accéder à l'AuthService
final callHistoryServiceProvider = Provider<CallHistoryService>((ref) {
  return CallHistoryService(ref);
});

// ✅ DÉFINITION DES CONSTANTES MANQUANTES
class CallHistoryFilter {
  static const String all = 'all';
  static const String incoming = 'incoming';
  static const String outgoing = 'outgoing';
  static const String missed = 'missed';
  static const String video = 'video';
  static const String audio = 'audio';
}

// ✅ MODÈLE CALLHISTORYITEM MANQUANT
class CallHistoryItem {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final DateTime timestamp;
  final Duration duration;
  final bool isVideoCall;
  final bool isIncoming;
  final bool isMissed;

  const CallHistoryItem({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.timestamp,
    required this.duration,
    required this.isVideoCall,
    required this.isIncoming,
    required this.isMissed,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'otherUserId': otherUserId,
    'otherUserName': otherUserName,
    'otherUserPhoto': otherUserPhoto,
    'timestamp': Timestamp.fromDate(timestamp),
    'duration': duration.inSeconds,
    'isVideoCall': isVideoCall,
    'isIncoming': isIncoming,
    'isMissed': isMissed,
  };

  factory CallHistoryItem.fromMap(Map<String, dynamic> map) {
    return CallHistoryItem(
      id: map['id'] ?? '',
      otherUserId: map['otherUserId'] ?? '',
      otherUserName: map['otherUserName'] ?? 'Utilisateur inconnu',
      otherUserPhoto: map['otherUserPhoto'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: Duration(seconds: map['duration'] ?? 0),
      isVideoCall: map['isVideoCall'] ?? false,
      isIncoming: map['isIncoming'] ?? false,
      isMissed: map['isMissed'] ?? false,
    );
  }
}

class CallHistoryService {
  final Ref _ref; // ✅ CORRIGÉ : Utiliser Ref au lieu d'AuthService directement
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache de l'historique
  List<CallHistoryEntry>? _cachedHistory;
  
  // Streams controllers
  final StreamController<List<CallHistoryEntry>> _historyController = StreamController.broadcast();
  
  // Getters publics
  Stream<List<CallHistoryEntry>> get historyStream => _historyController.stream;

  CallHistoryService(this._ref); // ✅ CORRIGÉ : Constructeur avec Ref

  // ✅ HELPER POUR OBTENIR L'UTILISATEUR ACTUEL - CORRIGÉ
  UserModel? get _currentUser => _ref.read(authServiceProvider).user;

  // ✅ ENREGISTRER UN APPEL DANS L'HISTORIQUE - CORRIGÉ
  Future<bool> recordCall({
    required String otherUserId,
    required CallType type,
    required Duration duration,
    required bool wasAnswered,
    required bool isIncoming,
    String? channelName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // ✅ CORRIGÉ : Obtenir l'utilisateur actuel via helper
      final currentUser = _currentUser;
      if (currentUser == null) return false;
      
      final callEntry = CallHistoryEntry(
        id: _generateCallId(),
        participantId: currentUser.id,
        otherUserId: otherUserId,
        type: type,
        duration: duration,
        timestamp: DateTime.now(),
        wasAnswered: wasAnswered,
        isIncoming: isIncoming,
        channelName: channelName,
        callQuality: _calculateCallQuality(duration, wasAnswered),
        metadata: metadata ?? {},
      );
      
      // Enregistrer dans Firestore
      await _firestore
          .collection('call_history')
          .doc(callEntry.id)
          .set(callEntry.toMap());
      
      // Mettre à jour le cache local
      _cachedHistory?.insert(0, callEntry);
      _historyController.add(_cachedHistory ?? []);
      
      WebRTCConfig.logInfo('✅ Appel enregistré dans l\'historique: ${callEntry.id}');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur enregistrement appel', e);
      return false;
    }
  }

  // ✅ OBTENIR L'HISTORIQUE DES APPELS - CORRIGÉ
  Future<List<CallHistoryEntry>> getCallHistory({
    int limit = 50,
    CallType? filterType,
    bool? filterAnswered,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // ✅ CORRIGÉ
      final currentUser = _currentUser;
      if (currentUser == null) return [];
      
      Query query = _firestore
          .collection('call_history')
          .where('participantId', isEqualTo: currentUser.id);
      
      // Filtres
      if (filterType != null) {
        query = query.where('type', isEqualTo: filterType.name);
      }
      
      if (filterAnswered != null) {
        query = query.where('wasAnswered', isEqualTo: filterAnswered);
      }
      
      if (fromDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }
      
      if (toDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }
      
      final snapshot = await query
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      final history = snapshot.docs
          .map((doc) => CallHistoryEntry.fromFirestore(doc))
          .toList();
      
      // Enrichir avec les données utilisateur
      final enrichedHistory = await _enrichHistoryWithUserData(history);
      
      // Mettre à jour le cache
      _cachedHistory = enrichedHistory;
      _historyController.add(enrichedHistory);
      
      return enrichedHistory;
    } catch (e) {
      WebRTCConfig.logError('Erreur récupération historique', e);
      return [];
    }
  }

  // ✅ RECHERCHE DANS L'HISTORIQUE
  Stream<List<CallHistoryItem>> searchCallHistory(String query) {
    final currentUser = _currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('call_history')
        .where('participantId', isEqualTo: currentUser.id)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _convertToCallHistoryItem(doc))
            .where((item) => item.otherUserName.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }

  // ✅ FILTRER L'HISTORIQUE
  Stream<List<CallHistoryItem>> filterCallHistory(String filter) {
    final currentUser = _currentUser;
    if (currentUser == null) return Stream.value([]);

    Query query = _firestore
        .collection('call_history')
        .where('participantId', isEqualTo: currentUser.id);
    
    switch (filter) {
      case CallHistoryFilter.incoming:
        query = query.where('isIncoming', isEqualTo: true);
        break;
      case CallHistoryFilter.outgoing:
        query = query.where('isIncoming', isEqualTo: false);
        break;
      case CallHistoryFilter.missed:
        query = query.where('wasAnswered', isEqualTo: false)
                     .where('isIncoming', isEqualTo: true);
        break;
      case CallHistoryFilter.video:
        query = query.where('type', isEqualTo: CallType.video.name);
        break;
      case CallHistoryFilter.audio:
        query = query.where('type', isEqualTo: CallType.audio.name);
        break;
    }
    
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => _convertToCallHistoryItem(doc))
        .toList());
  }

  // ✅ SUPPRIMER UN LOG D'APPEL
  Future<void> deleteCallLog(String callId) async {
    try {
      await _firestore.collection('call_history').doc(callId).delete();
      _cachedHistory?.removeWhere((entry) => entry.id == callId);
      if (_cachedHistory != null) {
        _historyController.add(_cachedHistory!);
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur suppression call log', e);
    }
  }

  // ✅ MÉTHODE DE CONVERSION
  CallHistoryItem _convertToCallHistoryItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallHistoryItem(
      id: doc.id,
      otherUserId: data['otherUserId'] ?? '',
      otherUserName: data['otherUserName'] ?? 'Utilisateur inconnu',
      otherUserPhoto: data['otherUserPhoto'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: Duration(seconds: data['duration'] ?? 0),
      isVideoCall: data['type'] == CallType.video.name,
      isIncoming: data['isIncoming'] ?? false,
      isMissed: !(data['wasAnswered'] ?? false) && (data['isIncoming'] ?? false),
    );
  }

  // ✅ OBTENIR LES STATISTIQUES D'APPELS - CORRIGÉ
  Future<CallStats> getCallStats({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // ✅ CORRIGÉ
      final currentUser = _currentUser;
      if (currentUser == null) {
        return CallStats.empty();
      }
      
      Query query = _firestore
          .collection('call_history')
          .where('participantId', isEqualTo: currentUser.id);
      
      if (fromDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }
      
      if (toDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }
      
      final snapshot = await query.get();
      
      int totalCalls = 0;
      int answeredCalls = 0;
      int missedCalls = 0;
      int incomingCalls = 0;
      int outgoingCalls = 0;
      int audioCalls = 0;
      int videoCalls = 0;
      Duration totalDuration = Duration.zero;
      Duration longestCall = Duration.zero;
      
      final Map<String, int> contactCounts = {};
      
      for (final doc in snapshot.docs) {
        final entry = CallHistoryEntry.fromFirestore(doc);
        
        totalCalls++;
        
        if (entry.wasAnswered) {
          answeredCalls++;
          totalDuration += entry.duration;
          
          if (entry.duration > longestCall) {
            longestCall = entry.duration;
          }
        } else {
          missedCalls++;
        }
        
        if (entry.isIncoming) {
          incomingCalls++;
        } else {
          outgoingCalls++;
        }
        
        // ✅ CORRIGÉ : Utiliser CallType
        if (entry.type == CallType.audio) {
          audioCalls++;
        } else {
          videoCalls++;
        }
        
        // Compter les appels par contact
        contactCounts[entry.otherUserId] = (contactCounts[entry.otherUserId] ?? 0) + 1;
      }
      
      // Calculer la durée moyenne
      final avgDuration = answeredCalls > 0 
          ? Duration(milliseconds: totalDuration.inMilliseconds ~/ answeredCalls)
          : Duration.zero;
      
      // Trouver le contact le plus appelé
      String? topContact;
      int maxCalls = 0;
      contactCounts.forEach((userId, callCount) {
        if (callCount > maxCalls) {
          maxCalls = callCount;
          topContact = userId;
        }
      });
      
      return CallStats(
        totalCalls: totalCalls,
        answeredCalls: answeredCalls,
        missedCalls: missedCalls,
        incomingCalls: incomingCalls,
        outgoingCalls: outgoingCalls,
        audioCalls: audioCalls,
        videoCalls: videoCalls,
        totalDuration: totalDuration,
        averageDuration: avgDuration,
        longestCall: longestCall,
        topContactId: topContact,
        topContactCallCount: maxCalls,
        answerRate: totalCalls > 0 ? (answeredCalls / totalCalls) : 0.0,
      );
    } catch (e) {
      WebRTCConfig.logError('Erreur calcul statistiques', e);
      return CallStats.empty();
    }
  }

  // ✅ SUPPRIMER UN APPEL DE L'HISTORIQUE
  Future<bool> deleteCallFromHistory(String callId) async {
    try {
      await _firestore.collection('call_history').doc(callId).delete();
      
      // Mettre à jour le cache
      _cachedHistory?.removeWhere((entry) => entry.id == callId);
      if (_cachedHistory != null) {
        _historyController.add(_cachedHistory!);
      }
      
      WebRTCConfig.logInfo('✅ Appel supprimé de l\'historique: $callId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur suppression appel', e);
      return false;
    }
  }

  // ✅ SUPPRIMER TOUT L'HISTORIQUE
  Future<bool> clearAllHistory() async {
    try {
      // ✅ CORRIGÉ
      final currentUser = _currentUser;
      if (currentUser == null) return false;
      
      // Récupérer tous les appels de l'utilisateur
      final snapshot = await _firestore
          .collection('call_history')
          .where('participantId', isEqualTo: currentUser.id)
          .get();
      
      // Supprimer par batch
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Vider le cache
      _cachedHistory = [];
      _historyController.add([]);
      
      WebRTCConfig.logInfo('✅ Historique d\'appels vidé');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur vidage historique', e);
      return false;
    }
  }

  // ✅ MARQUER UN APPEL COMME VU
  Future<void> markCallAsSeen(String callId) async {
    try {
      await _firestore.collection('call_history').doc(callId).update({
        'seen': true,
        'seenAt': FieldValue.serverTimestamp(),
      });
      
      // Mettre à jour le cache
      if (_cachedHistory != null) {
        final index = _cachedHistory!.indexWhere((entry) => entry.id == callId);
        if (index != -1) {
          // Créer une nouvelle instance avec seen = true
          _cachedHistory![index] = _cachedHistory![index].copyWith(seen: true);
          _historyController.add(_cachedHistory!);
        }
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur marquage appel vu', e);
    }
  }

  // ✅ OBTENIR LES APPELS RATÉS NON VUS
  Future<List<CallHistoryEntry>> getMissedCalls() async {
    try {
      // ✅ CORRIGÉ
      final currentUser = _currentUser;
      if (currentUser == null) return [];
      
      final snapshot = await _firestore
          .collection('call_history')
          .where('participantId', isEqualTo: currentUser.id)
          .where('wasAnswered', isEqualTo: false)
          .where('isIncoming', isEqualTo: true)
          .where('seen', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      final missedCalls = snapshot.docs
          .map((doc) => CallHistoryEntry.fromFirestore(doc))
          .toList();
      
      return await _enrichHistoryWithUserData(missedCalls);
    } catch (e) {
      WebRTCConfig.logError('Erreur récupération appels ratés', e);
      return [];
    }
  }

  // ✅ ENRICHIR L'HISTORIQUE AVEC LES DONNÉES UTILISATEUR
  Future<List<CallHistoryEntry>> _enrichHistoryWithUserData(
    List<CallHistoryEntry> history,
  ) async {
    try {
      // Récupérer les IDs uniques des autres utilisateurs
      final otherUserIds = history
          .map((entry) => entry.otherUserId)
          .toSet()
          .toList();
      
      if (otherUserIds.isEmpty) return history;
      
      // Récupérer les données utilisateur
      final userSnapshots = await Future.wait(
        otherUserIds.map((userId) => 
          _firestore.collection('users').doc(userId).get()
        ),
      );
      
      // Créer un map des données utilisateur
      final userDataMap = <String, UserModel>{};
      for (int i = 0; i < otherUserIds.length; i++) {
        final snapshot = userSnapshots[i];
        if (snapshot.exists) {
          userDataMap[otherUserIds[i]] = UserModel.fromMap(
            snapshot.data()!,
            snapshot.id,
          );
        }
      }
      
      // Enrichir les entrées d'historique
      return history.map((entry) {
        final userData = userDataMap[entry.otherUserId];
        return entry.copyWith(otherUserData: userData);
      }).toList();
    } catch (e) {
      WebRTCConfig.logError('Erreur enrichissement données utilisateur', e);
      return history;
    }
  }

  // ✅ CALCULER LA QUALITÉ D'APPEL
  CallQuality _calculateCallQuality(Duration duration, bool wasAnswered) {
    if (!wasAnswered) return CallQuality.failed;
    
    if (duration.inSeconds < 10) {
      return CallQuality.poor;
    } else if (duration.inSeconds < 60) {
      return CallQuality.fair;
    } else if (duration.inMinutes < 10) {
      return CallQuality.good;
    } else {
      return CallQuality.excellent;
    }
  }

  // ✅ GÉNÉRER UN ID D'APPEL
  String _generateCallId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'call_${timestamp}_$random';
  }

  // ✅ NETTOYAGE
  void dispose() {
    _historyController.close();
  }
}

// ✅ MODÈLE D'ENTRÉE D'HISTORIQUE - CORRIGÉ
class CallHistoryEntry {
  final String id;
  final String participantId;
  final String otherUserId;
  final CallType type; // ✅ CORRIGÉ
  final Duration duration;
  final DateTime timestamp;
  final bool wasAnswered;
  final bool isIncoming;
  final String? channelName;
  final CallQuality callQuality;
  final Map<String, dynamic> metadata;
  final UserModel? otherUserData;
  final bool seen;
  final DateTime? seenAt;

  const CallHistoryEntry({
    required this.id,
    required this.participantId,
    required this.otherUserId,
    required this.type,
    required this.duration,
    required this.timestamp,
    required this.wasAnswered,
    required this.isIncoming,
    this.channelName,
    required this.callQuality,
    required this.metadata,
    this.otherUserData,
    this.seen = false,
    this.seenAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'participantId': participantId,
    'otherUserId': otherUserId,
    'type': type.name,
    'duration': duration.inSeconds,
    'timestamp': Timestamp.fromDate(timestamp),
    'wasAnswered': wasAnswered,
    'isIncoming': isIncoming,
    'channelName': channelName,
    'callQuality': callQuality.name,
    'metadata': metadata,
    'seen': seen,
    'seenAt': seenAt != null ? Timestamp.fromDate(seenAt!) : null,
  };

  factory CallHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallHistoryEntry(
      id: doc.id,
      participantId: data['participantId'] ?? '',
      otherUserId: data['otherUserId'] ?? '',
      type: CallType.values.firstWhere( // ✅ CORRIGÉ
        (e) => e.name == data['type'],
        orElse: () => CallType.audio,
      ),
      duration: Duration(seconds: data['duration'] ?? 0),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      wasAnswered: data['wasAnswered'] ?? false,
      isIncoming: data['isIncoming'] ?? false,
      channelName: data['channelName'],
      callQuality: CallQuality.values.firstWhere(
        (e) => e.name == data['callQuality'],
        orElse: () => CallQuality.unknown,
      ),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      seen: data['seen'] ?? false,
      seenAt: (data['seenAt'] as Timestamp?)?.toDate(),
    );
  }

  get durationString => null;

  CallHistoryEntry copyWith({
    String? id,
    String? participantId,
    String? otherUserId,
    CallType? type, // ✅ CORRIGÉ
    Duration? duration,
    DateTime? timestamp,
    bool? wasAnswered,
    bool? isIncoming,
    String? channelName,
    CallQuality? callQuality,
    Map<String, dynamic>? metadata,
    UserModel? otherUserData,
    bool? seen,
    DateTime? seenAt,
  }) {
    return CallHistoryEntry(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      otherUserId: otherUserId ?? this.otherUserId,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      wasAnswered: wasAnswered ?? this.wasAnswered,
      isIncoming: isIncoming ?? this.isIncoming,
      channelName: channelName ?? this.channelName,
      callQuality: callQuality ?? this.callQuality,
      metadata: metadata ?? this.metadata,
      otherUserData: otherUserData ?? this.otherUserData,
      seen: seen ?? this.seen,
      seenAt: seenAt ?? this.seenAt,
    );
  }
}

// ✅ MODÈLE DE STATISTIQUES D'APPELS
class CallStats {
  final int totalCalls;
  final int answeredCalls;
  final int missedCalls;
  final int incomingCalls;
  final int outgoingCalls;
  final int audioCalls;
  final int videoCalls;
  final Duration totalDuration;
  final Duration averageDuration;
  final Duration longestCall;
  final String? topContactId;
  final int topContactCallCount;
  final double answerRate;

  const CallStats({
    required this.totalCalls,
    required this.answeredCalls,
    required this.missedCalls,
    required this.incomingCalls,
    required this.outgoingCalls,
    required this.audioCalls,
    required this.videoCalls,
    required this.totalDuration,
    required this.averageDuration,
    required this.longestCall,
    this.topContactId,
    required this.topContactCallCount,
    required this.answerRate,
  });

  factory CallStats.empty() => const CallStats(
    totalCalls: 0,
    answeredCalls: 0,
    missedCalls: 0,
    incomingCalls: 0,
    outgoingCalls: 0,
    audioCalls: 0,
    videoCalls: 0,
    totalDuration: Duration.zero,
    averageDuration: Duration.zero,
    longestCall: Duration.zero,
    topContactId: null,
    topContactCallCount: 0,
    answerRate: 0.0,
  );
}

// ✅ ENUM QUALITÉ D'APPEL
enum CallQuality {
  excellent,
  good,
  fair,
  poor,
  failed,
  unknown,
}

// ✅ EXTENSIONS - CORRIGÉES
extension CallQualityExtension on CallQuality {
  String get displayName {
    switch (this) {
      case CallQuality.excellent:
        return 'Excellente';
      case CallQuality.good:
        return 'Bonne';
      case CallQuality.fair:
        return 'Correcte';
      case CallQuality.poor:
        return 'Médiocre';
      case CallQuality.failed:
        return 'Échec';
      case CallQuality.unknown:
        return 'Inconnue';
    }
  }

  Color get color {
    switch (this) {
      case CallQuality.excellent:
        return Colors.green;
      case CallQuality.good:
        return Colors.lightGreen;
      case CallQuality.fair:
        return Colors.orange;
      case CallQuality.poor:
        return Colors.deepOrange;
      case CallQuality.failed:
        return Colors.red;
      case CallQuality.unknown:
        return Colors.grey;
    }
  }

  // ✅ CORRIGÉ : Utiliser des icônes qui existent
  IconData get icon {
    switch (this) {
      case CallQuality.excellent:
        return Icons.signal_cellular_4_bar;
      case CallQuality.good:
        return Icons.signal_cellular_alt;
      case CallQuality.fair:
        return Icons.signal_cellular_alt_1_bar;
      case CallQuality.poor:
        return Icons.signal_cellular_alt_2_bar;
      case CallQuality.failed:
        return Icons.signal_cellular_0_bar;
      case CallQuality.unknown:
        return Icons.signal_cellular_null;
    }
  }
}