/// A single weight-tracking measurement for one user on one day.
class WeightEntry {
  final int? id;
  final int userId;
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
    int? id,
    int? userId,
    DateTime? date,
    double? weightKg,
    double? bodyFatPct,
    double? hydrationPct,
    String? notes,
    DateTime? createdAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPct: bodyFatPct ?? this.bodyFatPct,
      hydrationPct: hydrationPct ?? this.hydrationPct,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': _dateOnly(date),
      'weight_kg': weightKg,
      'body_fat_pct': bodyFatPct,
      'hydration_pct': hydrationPct,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WeightEntry.fromMap(Map<String, Object?> map) {
    return WeightEntry(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      date: DateTime.parse(map['date'] as String),
      weightKg: (map['weight_kg'] as num).toDouble(),
      bodyFatPct: (map['body_fat_pct'] as num?)?.toDouble(),
      hydrationPct: (map['hydration_pct'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
