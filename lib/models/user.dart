/// A local account in Suma. There is always at least one `admin` account,
/// pre-provisioned on first launch; every other account is created and
/// managed from within the app (Admin > Usuários).
///
/// [heightCm], [goalWeightKg], [unitPref] and [themePref] are the per-user
/// preferences collected on the one-time onboarding flow ([onboarded] flips
/// to `true` once that flow completes) and editable later from Ajustes.
class AppUser {
  final int? id;
  final String name;
  final String username;
  final String passwordHash;
  final String passwordSalt;
  final String role; // 'admin' or 'member'
  final DateTime createdAt;
  final double? heightCm;
  final double? goalWeightKg;
  final String unitPref; // 'kg' or 'lb'
  final String themePref; // 'system', 'light' or 'dark'
  final bool onboarded;

  const AppUser({
    this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.passwordSalt,
    required this.role,
    required this.createdAt,
    this.heightCm,
    this.goalWeightKg,
    this.unitPref = 'kg',
    this.themePref = 'system',
    this.onboarded = false,
  });

  bool get isAdmin => role == 'admin';

  /// First name only, used for friendly greetings on the dashboard.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  AppUser copyWith({
    int? id,
    String? name,
    String? username,
    String? passwordHash,
    String? passwordSalt,
    String? role,
    DateTime? createdAt,
    double? heightCm,
    bool clearHeight = false,
    double? goalWeightKg,
    bool clearGoal = false,
    String? unitPref,
    String? themePref,
    bool? onboarded,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      goalWeightKg: clearGoal ? null : (goalWeightKg ?? this.goalWeightKg),
      unitPref: unitPref ?? this.unitPref,
      themePref: themePref ?? this.themePref,
      onboarded: onboarded ?? this.onboarded,
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
      'height_cm': heightCm,
      'goal_weight_kg': goalWeightKg,
      'unit_pref': unitPref,
      'theme_pref': themePref,
      'onboarded': onboarded ? 1 : 0,
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
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      goalWeightKg: (map['goal_weight_kg'] as num?)?.toDouble(),
      unitPref: (map['unit_pref'] as String?) ?? 'kg',
      themePref: (map['theme_pref'] as String?) ?? 'system',
      onboarded: ((map['onboarded'] as int?) ?? 0) != 0,
    );
  }
}
