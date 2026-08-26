/// A single weight-tracking measurement for one user on one day. Backed by
/// `public.weight_entries` in Supabase - `id`/`userId` are uuids (Postgres
/// `uuid`/Supabase Auth user id), not local auto-increment integers.
class WeightEntry {
  final String? id;
  final String userId;
  final DateTime date; // day granularity (time component ignored)
  final double weightKg;
  final double? bodyFatPct;
  final double? hydrationPct;
  final String? notes;
  final DateTime createdAt;

  const WeightEntry({
    this.id,
    required this.userId,
    required this.date,
    required this.weightKg,
    this.bodyFatPct,
    this.hydrationPct,
    this.notes,
    required this.createdAt,
  });

  WeightEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? weightKg,
    double? bodyFatPct,
    bool clearBodyFat = false,
    double? hydrationPct,
    bool clearHydration = false,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPct: clearBodyFat ? null : (bodyFatPct ?? this.bodyFatPct),
      hydrationPct: clearHydration ? null : (hydrationPct ?? this.hydrationPct),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Row to send on insert/update - `id`/`created_at` are left out (the
  /// database assigns them via column defaults).
  Map<String, Object?> toInsertMap() {
    return {
      'user_id': userId,
      'date': _dateOnly(date),
      'weight_kg': weightKg,
      'body_fat_pct': bodyFatPct,
      'hydration_pct': hydrationPct,
      'notes': notes,
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      date: DateTime.parse(map['date'] as String),
      weightKg: _toDouble(map['weight_kg'])!,
      bodyFatPct: _toDouble(map['body_fat_pct']),
      hydrationPct: _toDouble(map['hydration_pct']),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
    );
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
