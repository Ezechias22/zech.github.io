// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Call _$CallFromJson(Map<String, dynamic> json) => Call(
      id: json['id'] as String,
      callerId: json['callerId'] as String,
      receiverId: json['receiverId'] as String,
      channelName: json['channelName'] as String,
      type: $enumDecode(_$CallTypeEnumMap, json['type']),
      status: $enumDecode(_$CallStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      hasVideo: json['hasVideo'] as bool? ?? false,
      durationSeconds: (json['duration'] as num?)?.toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CallToJson(Call instance) => <String, dynamic>{
      'id': instance.id,
      'callerId': instance.callerId,
      'receiverId': instance.receiverId,
      'channelName': instance.channelName,
      'type': _$CallTypeEnumMap[instance.type]!,
      'status': _$CallStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'startedAt': instance.startedAt?.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'hasVideo': instance.hasVideo,
      'duration': instance.durationSeconds,
      'metadata': instance.metadata,
    };

const _$CallTypeEnumMap = {
  CallType.audio: 'audio',
  CallType.video: 'video',
};

const _$CallStatusEnumMap = {
  CallStatus.initiated: 'initiated',
  CallStatus.calling: 'calling',
  CallStatus.ringing: 'ringing',
  CallStatus.answered: 'answered',
  CallStatus.ended: 'ended',
  CallStatus.declined: 'declined',
  CallStatus.missed: 'missed',
  CallStatus.failed: 'failed',
};

CallRoom _$CallRoomFromJson(Map<String, dynamic> json) => CallRoom(
      id: json['id'] as String,
      hostId: json['hostId'] as String,
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      type: $enumDecode(_$CallTypeEnumMap, json['type']),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settings: json['settings'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CallRoomToJson(CallRoom instance) => <String, dynamic>{
      'id': instance.id,
      'hostId': instance.hostId,
      'participants': instance.participants,
      'type': _$CallTypeEnumMap[instance.type]!,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'settings': instance.settings,
    };

CallParticipant _$CallParticipantFromJson(Map<String, dynamic> json) =>
    CallParticipant(
      userId: json['userId'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      leftAt: json['leftAt'] == null
          ? null
          : DateTime.parse(json['leftAt'] as String),
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? true,
      isAudioEnabled: json['isAudioEnabled'] as bool? ?? true,
      isSpeaking: json['isSpeaking'] as bool? ?? false,
      isJoined: json['isJoined'] as bool? ?? true,
      isMuted: json['isMuted'] as bool? ?? false,
    );

Map<String, dynamic> _$CallParticipantToJson(CallParticipant instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'name': instance.name,
      'photoUrl': instance.photoUrl,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'leftAt': instance.leftAt?.toIso8601String(),
      'isVideoEnabled': instance.isVideoEnabled,
      'isAudioEnabled': instance.isAudioEnabled,
      'isSpeaking': instance.isSpeaking,
      'isJoined': instance.isJoined,
      'isMuted': instance.isMuted,
    };

CallLog _$CallLogFromJson(Map<String, dynamic> json) => CallLog(
      id: json['id'] as String,
      callId: json['callId'] as String,
      participantId: json['participantId'] as String,
      otherUserId: json['otherUserId'] as String,
      type: $enumDecode(_$CallTypeEnumMap, json['type']),
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      timestamp: DateTime.parse(json['timestamp'] as String),
      wasAnswered: json['wasAnswered'] as bool,
      isIncoming: json['isIncoming'] as bool,
    );

Map<String, dynamic> _$CallLogToJson(CallLog instance) => <String, dynamic>{
      'id': instance.id,
      'callId': instance.callId,
      'participantId': instance.participantId,
      'otherUserId': instance.otherUserId,
      'type': _$CallTypeEnumMap[instance.type]!,
      'duration': instance.duration.inMicroseconds,
      'timestamp': instance.timestamp.toIso8601String(),
      'wasAnswered': instance.wasAnswered,
      'isIncoming': instance.isIncoming,
    };
