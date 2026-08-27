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
  final String? avatarUrl;
  final String role; // 'admin' or 'member'
  final double? heightCm;
  final double? goalWeightKg;
  final String goalType; // 'lose' or 'gain'
  final double? goalStartWeightKg; // snapshot of current weight when the goal was last set
  final String unitPref; // 'kg' or 'lb'
  final String themePref; // 'system', 'light' or 'dark'
  final bool onboarded;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.email,
    this.familyId,
    required this.name,
    this.avatarUrl,
    this.role = 'admin',
    this.heightCm,
    this.goalWeightKg,
    this.goalType = 'lose',
    this.goalStartWeightKg,
    this.unitPref = 'kg',
    this.themePref = 'system',
    this.onboarded = false,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get inFamily => familyId != null;
  bool get goalIsLose => goalType == 'lose';
  String get firstName => name.trim().isEmpty ? name : name.trim().split(RegExp(r'\s+')).first;

  /// Everything after the first word of [name] - empty if there's only one
  /// word. Suma stores a single "name" column (kept for backward
  /// compatibility with the sign-up flow and family listings), so
  /// first/last name are just a split/join over it rather than separate
  /// columns.
  String get lastName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length <= 1 ? '' : parts.skip(1).join(' ');
  }

  Profile copyWith({
    String? email,
    String? familyId,
    bool clearFamily = false,
    String? name,
    String? avatarUrl,
    bool clearAvatar = false,
    String? role,
    double? heightCm,
    bool clearHeight = false,
    double? goalWeightKg,
    bool clearGoal = false,
    String? goalType,
    double? goalStartWeightKg,
    String? unitPref,
    String? themePref,
    bool? onboarded,
  }) {
    return Profile(
      id: id,
      email: email ?? this.email,
      familyId: clearFamily ? null : (familyId ?? this.familyId),
      name: name ?? this.name,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      role: role ?? this.role,
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      goalWeightKg: clearGoal ? null : (goalWeightKg ?? this.goalWeightKg),
      goalType: clearGoal ? this.goalType : (goalType ?? this.goalType),
      goalStartWeightKg: clearGoal ? null : (goalStartWeightKg ?? this.goalStartWeightKg),
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
      avatarUrl: map['avatar_url'] as String?,
      role: map['role'] as String? ?? 'admin',
      heightCm: _toDouble(map['height_cm']),
      goalWeightKg: _toDouble(map['goal_weight_kg']),
      goalType: map['goal_type'] as String? ?? 'lose',
      goalStartWeightKg: _toDouble(map['goal_start_weight_kg']),
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
