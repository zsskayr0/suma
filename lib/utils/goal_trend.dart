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

/// Fraction (0..1) of the way from [startKg] to [goalWeightKg] that
/// [currentKg] has covered - the same formula behind the dashboard's goal
/// progress bar, shared with the admin "quem está mais perto da meta"
/// ranking so both read the exact same percentage for the same person.
///
/// When start and goal are (nearly) the same weight the ratio is
/// undefined - that's not automatically "100% done", it only means the
/// goal was already met at the moment it was set. Treated as complete only
/// if the current weight is actually still at/near that goal.
double goalProgressFraction({
  required double currentKg,
  required double startKg,
  required double goalWeightKg,
}) {
  final totalDelta = goalWeightKg - startKg;
  final doneDelta = currentKg - startKg;
  final remainingKg = (goalWeightKg - currentKg).abs();
  final reached = remainingKg < 0.05;
  if (totalDelta.abs() < 0.05) return reached ? 1.0 : 0.0;
  return (doneDelta / totalDelta).clamp(0.0, 1.0).toDouble();
}
