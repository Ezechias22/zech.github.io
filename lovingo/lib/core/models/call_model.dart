// lib/core/models/call_model.dart - MODÈLE D'APPEL COMPLET POUR WEBRTC - CORRIGÉ
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'call_model.g.dart';

// ✅ MODÈLE D'APPEL PRINCIPAL - CORRIGÉ
@JsonSerializable()
class Call {
  final String id;
  final String callerId;
  final String receiverId;
  final String channelName;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool hasVideo;
  @JsonKey(name: 'duration') // ✅ AJOUTÉ : mapping explicite pour .g.dart
  final int? durationSeconds; // ✅ AJOUTÉ : propriété duration en secondes
  final Map<String, dynamic>? metadata;

  const Call({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.channelName,
    required this.type,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.hasVideo = false,
    this.durationSeconds, // ✅ AJOUTÉ
    this.metadata,
  });

  // ✅ MÉTHODES DE SÉRIALISATION
  factory Call.fromJson(Map<String, dynamic> json) => _$CallFromJson(json);
  Map<String, dynamic> toJson() => _$CallToJson(this);

  // ✅ COMPATIBILITÉ AVEC FIRESTORE
  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      id: map['id'] ?? '',
      callerId: map['callerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      channelName: map['channelName'] ?? '',
      type: CallType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CallType.audio,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CallStatus.initiated,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      hasVideo: map['hasVideo'] ?? false,
      durationSeconds: map['duration'], // ✅ AJOUTÉ
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'receiverId': receiverId,
      'channelName': channelName,
      'type': type.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'hasVideo': hasVideo,
      'duration': durationSeconds, // ✅ AJOUTÉ
      'metadata': metadata,
    };
  }

  // ✅ MÉTHODES UTILITAIRES
  Duration get duration {
    if (durationSeconds != null) {
      return Duration(seconds: durationSeconds!);
    }
    if (startedAt != null && endedAt != null) {
      return endedAt!.difference(startedAt!);
    }
    return Duration.zero;
  }

  bool get isActive => status == CallStatus.answered;
  bool get isEnded => status == CallStatus.ended;
  bool get isVideoCall => hasVideo || type == CallType.video;

  // ✅ COPYWITH POUR MISES À JOUR IMMUTABLES
  Call copyWith({
    String? id,
    String? callerId,
    String? receiverId,
    String? channelName,
    CallType? type,
    CallStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? hasVideo,
    int? durationSeconds,
    Map<String, dynamic>? metadata,
  }) {
    return Call(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      channelName: channelName ?? this.channelName,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      hasVideo: hasVideo ?? this.hasVideo,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Call(id: $id, callerId: $callerId, receiverId: $receiverId, type: $type, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Call && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ✅ ENUM POUR LES TYPES D'APPEL
enum CallType {
  @JsonValue('audio')
  audio,
  @JsonValue('video')
  video;

  String get displayName {
    switch (this) {
      case CallType.audio:
        return 'Appel audio';
      case CallType.video:
        return 'Appel vidéo';
    }
  }

  bool get isVideo => this == CallType.video;
  bool get isAudio => this == CallType.audio;

  IconData get icon {
    switch (this) {
      case CallType.audio:
        return Icons.call;
      case CallType.video:
        return Icons.videocam;
    }
  }
}

// ✅ ENUM POUR LES STATUTS D'APPEL - AVEC CALLING AJOUTÉ
enum CallStatus {
  initiated,
  calling,      // ✅ AJOUTÉ : valeur manquante
  ringing,
  answered,
  ended,
  declined,
  missed,
  failed;

  String get displayName {
    switch (this) {
      case CallStatus.initiated:
        return 'Initié';
      case CallStatus.calling:
        return 'Appel en cours';  // ✅ AJOUTÉ
      case CallStatus.ringing:
        return 'Sonnerie';
      case CallStatus.answered:
        return 'En cours';
      case CallStatus.ended:
        return 'Terminé';
      case CallStatus.declined:
        return 'Refusé';
      case CallStatus.missed:
        return 'Raté';
      case CallStatus.failed:
        return 'Échoué';
    }
  }

  bool get isActive => [CallStatus.calling, CallStatus.answered].contains(this);  // ✅ MODIFIÉ
  bool get isCompleted => [CallStatus.ended, CallStatus.declined, CallStatus.missed, CallStatus.failed].contains(this);
}

// ✅ MODÈLE CALLROOM AJOUTÉ (manquait dans le fichier original)
@JsonSerializable()
class CallRoom {
  final String id;
  final String hostId;
  final List<String> participants;
  final CallType type;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? settings;

  const CallRoom({
    required this.id,
    required this.hostId,
    required this.participants,
    required this.type,
    this.isActive = true,
    required this.createdAt,
    this.settings,
  });

  factory CallRoom.fromJson(Map<String, dynamic> json) => _$CallRoomFromJson(json);
  Map<String, dynamic> toJson() => _$CallRoomToJson(this);

  factory CallRoom.fromMap(Map<String, dynamic> map) {
    return CallRoom(
      id: map['id'] ?? '',
      hostId: map['hostId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      type: CallType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CallType.audio,
      ),
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostId': hostId,
      'participants': participants,
      'type': type.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'settings': settings,
    };
  }
}

// ✅ MODÈLE POUR LES PARTICIPANTS D'APPEL - CORRIGÉ
@JsonSerializable()
class CallParticipant {
  final String userId;
  final String name;
  final String? photoUrl;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isSpeaking;
  @JsonKey(name: 'isJoined') // ✅ AJOUTÉ : propriété manquante
  final bool isJoined;
  @JsonKey(name: 'isMuted') // ✅ AJOUTÉ : propriété manquante
  final bool isMuted;

  const CallParticipant({
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.joinedAt,
    this.leftAt,
    this.isVideoEnabled = true,
    this.isAudioEnabled = true,
    this.isSpeaking = false,
    this.isJoined = true, // ✅ AJOUTÉ
    this.isMuted = false, // ✅ AJOUTÉ
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) => _$CallParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$CallParticipantToJson(this);

  bool get isActive => leftAt == null && isJoined;
  Duration get duration => (leftAt ?? DateTime.now()).difference(joinedAt);

  CallParticipant copyWith({
    String? userId,
    String? name,
    String? photoUrl,
    DateTime? joinedAt,
    DateTime? leftAt,
    bool? isVideoEnabled,
    bool? isAudioEnabled,
    bool? isSpeaking,
    bool? isJoined,
    bool? isMuted,
  }) {
    return CallParticipant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isJoined: isJoined ?? this.isJoined,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

// ✅ MODÈLE POUR L'HISTORIQUE DES APPELS
@JsonSerializable()
class CallLog {
  final String id;
  final String callId;
  final String participantId;
  final String otherUserId;
  final CallType type;
  final Duration duration;
  final DateTime timestamp;
  final bool wasAnswered;
  final bool isIncoming;

  const CallLog({
    required this.id,
    required this.callId,
    required this.participantId,
    required this.otherUserId,
    required this.type,
    required this.duration,
    required this.timestamp,
    required this.wasAnswered,
    required this.isIncoming,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) => _$CallLogFromJson(json);
  Map<String, dynamic> toJson() => _$CallLogToJson(this);

  factory CallLog.fromMap(Map<String, dynamic> map) {
    return CallLog(
      id: map['id'] ?? '',
      callId: map['callId'] ?? '',
      participantId: map['participantId'] ?? '',
      otherUserId: map['otherUserId'] ?? '',
      type: CallType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CallType.audio,
      ),
      duration: Duration(seconds: map['duration'] ?? 0),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      wasAnswered: map['wasAnswered'] ?? false,
      isIncoming: map['isIncoming'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callId': callId,
      'participantId': participantId,
      'otherUserId': otherUserId,
      'type': type.name,
      'duration': duration.inSeconds,
      'timestamp': Timestamp.fromDate(timestamp),
      'wasAnswered': wasAnswered,
      'isIncoming': isIncoming,
    };
  }

  String get durationString {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get statusDescription {
    if (!wasAnswered) {
      return isIncoming ? 'Appel raté' : 'Pas de réponse';
    }
    return isIncoming ? 'Appel entrant' : 'Appel sortant';
  }

  @override
  String toString() {
    return 'CallLog(id: $id, type: $type, duration: $durationString, wasAnswered: $wasAnswered)';
  }
}

// ✅ EXTENSIONS UTILES
extension CallExtensions on Call {
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}

// ✅ ÉTATS DE CONNEXION WEBRTC
enum WebRTCConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
  closed,
}

// ✅ TYPES D'APPEL WEBRTC
enum WebRTCCallType {
  audio,
  video,
}