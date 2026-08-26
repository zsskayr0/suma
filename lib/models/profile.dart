/// A person using Suma - one row in `public.profiles`, 1:1 with a Supabase
/// Auth user. Replaces the old locally-hashed `AppUser`: identity/password
/// now live entirely in Supabase Auth, this only holds the app-specific
/// profile (preferences collected on first-run onboarding + family
/// membership).
class Profile {
  final String id; // matches auth.users.id / Supabase session user id
  final String? email; // from the auth session, not stored in this table
  final String? familyId;
  final String name;
  final String role; // 'admin' or 'member'
  final double? heightCm;
  final double? goalWeightKg;
  final String unitPref; // 'kg' or 'lb'
  final String themePref; // 'system', 'light' or 'dark'
  final bool onboarded;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.email,
    this.familyId,
    required this.name,
    this.role = 'admin',
    this.heightCm,
    this.goalWeightKg,
    this.unitPref = 'kg',
    this.themePref = 'system',
    this.onboarded = false,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get inFamily => familyId != null;
  String get firstName => name.trim().isEmpty ? name : name.trim().split(RegExp(r'\s+')).first;

  Profile copyWith({
    String? email,
    String? familyId,
    bool clearFamily = false,
    String? name,
    String? role,
    double? heightCm,
    bool clearHeight = false,
    double? goalWeightKg,
    bool clearGoal = false,
    String? unitPref,
    String? themePref,
    bool? onboarded,
  }) {
    return Profile(
      id: id,
      email: email ?? this.email,
      familyId: clearFamily ? null : (familyId ?? this.familyId),
      name: name ?? this.name,
      role: role ?? this.role,
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      goalWeightKg: clearGoal ? null : (goalWeightKg ?? this.goalWeightKg),
      unitPref: unitPref ?? this.unitPref,
      themePref: themePref ?? this.themePref,
      onboarded: onboarded ?? this.onboarded,
      createdAt: createdAt,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map, {String? email}) {
    return Profile(
      id: map['id'] as String,
      email: email,
      familyId: map['family_id'] as String?,
      name: map['name'] as String? ?? 'Usuário',
      role: map['role'] as String? ?? 'admin',
      heightCm: _toDouble(map['height_cm']),
      goalWeightKg: _toDouble(map['goal_weight_kg']),
      unitPref: map['unit_pref'] as String? ?? 'kg',
      themePref: map['theme_pref'] as String? ?? 'system',
      onboarded: map['onboarded'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
    );
  }

  /// PostgREST serializes Postgres `numeric` columns as JSON strings (to
  /// avoid floating-point precision loss), so values may arrive as either a
  /// number or a string depending on the column type - handle both.
  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
