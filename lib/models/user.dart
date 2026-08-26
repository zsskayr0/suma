/// A local account in Suma. There is always at least one `admin` account,
/// pre-provisioned on first launch; every other account is created and
/// managed from within the app (Admin > Usuários).
class AppUser {
  final int? id;
  final String name;
  final String username;
  final String passwordHash;
  final String passwordSalt;
  final String role; // 'admin' or 'member'
  final DateTime createdAt;

  const AppUser({
    this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.passwordSalt,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  AppUser copyWith({
    int? id,
    String? name,
    String? username,
    String? passwordHash,
    String? passwordSalt,
    String? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: map['id'] as int?,
      name: map['name'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      passwordSalt: map['password_salt'] as String,
      role: map['role'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
