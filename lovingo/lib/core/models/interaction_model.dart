class InteractionModel {
  final String id;
  final String userId;
  final String targetUserId;
  final String type; // 'like', 'pass', 'superlike'
  final DateTime timestamp;

  const InteractionModel({
    required this.id,
    required this.userId,
    required this.targetUserId,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'targetUserId': targetUserId,
      'type': type,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory InteractionModel.fromMap(Map<String, dynamic> map) {
    return InteractionModel(
      id: map['id'],
      userId: map['userId'],
      targetUserId: map['targetUserId'],
      type: map['type'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}
