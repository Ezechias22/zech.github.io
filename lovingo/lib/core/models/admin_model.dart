import 'package:json_annotation/json_annotation.dart';

part 'admin_model.g.dart';

@JsonSerializable()
class AdminModel {
  final String id;
  final String email;
  final String name;
  final String role; // 'admin', 'moderator', 'support'
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isActive;

  const AdminModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
    required this.createdAt,
    required this.lastLogin,
    this.isActive = true,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) => _$AdminModelFromJson(json);
  Map<String, dynamic> toJson() => _$AdminModelToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'permissions': permissions,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLogin': lastLogin.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory AdminModel.fromMap(Map<String, dynamic> map) {
    return AdminModel(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      role: map['role'],
      permissions: List<String>.from(map['permissions'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastLogin: DateTime.fromMillisecondsSinceEpoch(map['lastLogin']),
      isActive: map['isActive'] ?? true,
    );
  }

  AdminModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    List<String>? permissions,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return AdminModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }

  // Permissions helper methods
  bool hasPermission(String permission) {
    return permissions.contains(permission) || role == 'admin';
  }

  bool canModerateUsers() {
    return hasPermission('moderate_users');
  }

  bool canManageReports() {
    return hasPermission('manage_reports');
  }

  bool canAccessAnalytics() {
    return hasPermission('view_analytics');
  }

  bool canManagePayments() {
    return hasPermission('manage_payments');
  }
}

// Permissions par défaut selon les rôles
class AdminPermissions {
  static const List<String> adminPermissions = [
    'moderate_users',
    'manage_reports',
    'view_analytics',
    'manage_payments',
    'manage_admins',
    'system_config',
  ];

  static const List<String> moderatorPermissions = [
    'moderate_users',
    'manage_reports',
    'view_analytics',
  ];

  static const List<String> supportPermissions = [
    'view_analytics',
    'manage_reports',
  ];

  static List<String> getDefaultPermissions(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return adminPermissions;
      case 'moderator':
        return moderatorPermissions;
      case 'support':
        return supportPermissions;
      default:
        return [];
    }
  }
}
