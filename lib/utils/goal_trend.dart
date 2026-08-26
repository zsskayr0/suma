/// Whether a weight change from [fromKg] to [toKg] moves someone closer to
/// their goal (used to color variação indicators green/red - not simply by
/// "went up" vs "went down", since that depends on whether they're trying to
/// lose or gain). Returns null when there's no signal either way (no change).
///
/// With a specific [goalWeightKg] on file, "closer" means the distance to
/// that exact number shrank. Without one, it falls back to [goalType]
/// alone: losing weight is positive progress for 'lose', gaining is positive
/// for 'gain'.
bool? goalTrendPositive({
  required double fromKg,
  required double toKg,
  double? goalWeightKg,
  required String goalType,
}) {
  if (fromKg == toKg) return null;
  if (goalWeightKg != null) {
    final before = (goalWeightKg - fromKg).abs();
    final after = (goalWeightKg - toKg).abs();
    if (after == before) return null;
    return after < before;
  }
  final losing = toKg < fromKg;
  return goalType == 'gain' ? !losing : losing;
}
