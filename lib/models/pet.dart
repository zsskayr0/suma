/// A pet sub-profile, owned by exactly one [Profile] - up to 3 per owner
/// (enforced both client-side and by a trigger in
/// supabase/010_pets.sql). Its own weight history ([PetWeightEntry]) is
/// entirely separate from its owner's - the two never mix.
class Pet {
  final String? id; // null for a not-yet-inserted pet
  final String ownerId;
  final String name;
  final DateTime? birthDate;
  final String species;
  final String? breed;
  final DateTime createdAt;

  const Pet({
    this.id,
    required this.ownerId,
    required this.name,
    this.birthDate,
    required this.species,
    this.breed,
    required this.createdAt,
  });

  Pet copyWith({
    String? name,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? species,
    String? breed,
    bool clearBreed = false,
  }) {
    return Pet(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      species: species ?? this.species,
      breed: clearBreed ? null : (breed ?? this.breed),
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toInsertMap() {
    return {
      'owner_id': ownerId,
      'name': name,
      'birth_date': birthDate == null ? null : _dateOnly(birthDate!),
      'species': species,
      'breed': breed,
    };
  }

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      birthDate: map['birth_date'] != null ? DateTime.parse(map['birth_date'] as String) : null,
      species: map['species'] as String,
      breed: map['breed'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
    );
  }

  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
