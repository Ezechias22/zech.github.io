import 'package:json_annotation/json_annotation.dart';

part 'transaction_model.g.dart';

@JsonSerializable()
class TransactionModel {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime timestamp;
  final TransactionStatus status;
  final Map<String, dynamic>? metadata;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.status,
    this.metadata,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) => _$TransactionModelFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionModelToJson(this);
  
  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}

enum TransactionType {
  @JsonValue('credit')
  credit,
  @JsonValue('debit')
  debit,
  @JsonValue('recharge')
  recharge,
  @JsonValue('withdrawal')
  withdrawal,
}

enum TransactionStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
}