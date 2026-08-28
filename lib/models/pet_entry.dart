/// One logged weight measurement for a [Pet] - mirrors [WeightEntry]'s
/// shape exactly, just keyed by petId instead of userId, and without the
/// body-fat/hydration fields (not something tracked for pets here).
class PetWeightEntry {
  final String? id;
  final String petId;
  final DateTime date;
  final double weightKg;
  final String? notes;
  final DateTime createdAt;

  const PetWeightEntry({
    this.id,
    required this.petId,
    required this.date,
    required this.weightKg,
    this.notes,
    required this.createdAt,
  });

  PetWeightEntry copyWith({
    String? id,
    String? petId,
    DateTime? date,
    double? weightKg,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
  }) {
    return PetWeightEntry(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toInsertMap() {
    return {
      'pet_id': petId,
      'date': _dateOnly(date),
      'weight_kg': weightKg,
      'notes': notes,
    };
  }

  factory PetWeightEntry.fromMap(Map<String, dynamic> map) {
    return PetWeightEntry(
      id: map['id'] as String?,
      petId: map['pet_id'] as String,
      date: DateTime.parse(map['date'] as String),
      weightKg: _toDouble(map['weight_kg'])!,
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
