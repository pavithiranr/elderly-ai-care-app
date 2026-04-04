enum UserRole { elderly, caregiver }

class UserModel {
  final String id;
  final String name;
  final UserRole role;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  UserModel copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'avatarUrl': avatarUrl,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        role: UserRole.values.byName(json['role'] as String),
        avatarUrl: json['avatarUrl'] as String?,
      );
}
