import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user account in the SiKasirSahaja system.
///
/// Stored in Firestore under `users/{uid}`. The [role] field determines
/// base access level (`'admin'` or `'kasir'`), while [permissions] grants
/// additional granular access per user (PRD v1.1.0 Section 3 & 8.2).
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String phone;
  final String? photoUrl;
  final String position;
  final List<String> permissions;
  final String? workScheduleId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.phone = '',
    this.photoUrl,
    this.position = '',
    this.permissions = const [],
    this.workScheduleId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// ID alias for uid.
  String get id => uid;

  /// Whether this user has admin/manager privileges.
  bool get isAdmin => role == 'admin';

  /// Whether this user is a cashier.
  bool get isCashier => role == 'kasir';

  /// Checks whether user is admin or holds a specific permission key.
  bool hasPermission(String permissionKey) =>
      isAdmin || permissions.contains(permissionKey);

  /// Creates a [UserModel] from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  /// Creates a [UserModel] from a plain map (e.g. from JSON).
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final rawPerms = map['permissions'];
    final List<String> perms = rawPerms is List
        ? rawPerms.map((e) => e.toString()).toList()
        : const [];

    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'kasir',
      phone: map['phone'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      position:
          map['position'] as String? ??
          ((map['role'] == 'admin') ? 'Administrator' : 'Kasir'),
      permissions: perms,
      workScheduleId: map['workScheduleId'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this model to a map suitable for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'phone': phone.trim(),
      'photoUrl': photoUrl,
      'position': position.trim(),
      'permissions': permissions,
      'workScheduleId': workScheduleId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Returns a copy of this model with selected fields overridden.
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? phone,
    String? photoUrl,
    String? position,
    List<String>? permissions,
    String? workScheduleId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      position: position ?? this.position,
      permissions: permissions ?? this.permissions,
      workScheduleId: workScheduleId ?? this.workScheduleId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, email: $email, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
