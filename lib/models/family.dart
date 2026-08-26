/// A "rede familiar" (household network) - one row in `public.families`.
class FamilyInfo {
  final String id;
  final String name;
  final String inviteCode;

  const FamilyInfo({required this.id, required this.name, required this.inviteCode});

  factory FamilyInfo.fromMap(Map<String, dynamic> map) {
    return FamilyInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String,
    );
  }
}
