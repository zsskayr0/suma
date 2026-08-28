import '../models/entry.dart';

/// All-time min/average/max across every entry on file, plus how long
/// they've been tracking - backs the "Faixa de peso" card and the
/// "Acompanhamento" stat tile.
class WeightRangeStats {
  final double minKg;
  final double avgKg;
  final double maxKg;
  final DateTime since;
  final int count;

  const WeightRangeStats({required this.minKg, required this.avgKg, required this.maxKg, required this.since, required this.count});

  /// Whole months tracked, at least 1 once there's more than a single day
  /// of history (so a 2-week streak doesn't read as "0 meses").
  int get monthsTracked {
    final days = DateTime.now().difference(since).inDays;
    return days < 30 ? (days > 0 ? 1 : 0) : (days / 30).round();
  }
}

/// [entriesDesc] must be sorted newest-first (date DESC).
WeightRangeStats weightRangeStats(List<WeightEntry> entriesDesc) {
  var min = entriesDesc.first.weightKg;
  var max = entriesDesc.first.weightKg;
  var sum = 0.0;
  for (final e in entriesDesc) {
    if (e.weightKg < min) min = e.weightKg;
    if (e.weightKg > max) max = e.weightKg;
    sum += e.weightKg;
  }
  return WeightRangeStats(minKg: min, avgKg: sum / entriesDesc.length, maxKg: max, since: entriesDesc.last.date, count: entriesDesc.length);
}

/// A projected date the goal will be reached at the current pace, plus a
/// "probable" window bracketing it - backs "Previsão da meta". Null when
/// there isn't enough history, the goal's already met, or the recent trend
/// is heading the wrong way (nothing sensible to project in that case).
class GoalPrediction {
  final double dailyRateKg; // negative = losing, positive = gaining
  final DateTime estimatedDate;
  final DateTime earliestDate;
  final DateTime latestDate;

  const GoalPrediction({required this.dailyRateKg, required this.estimatedDate, required this.earliestDate, required this.latestDate});
}

/// [entriesDesc] must be sorted newest-first (date DESC).
GoalPrediction? predictGoalArrival({required List<WeightEntry> entriesDesc, required double goalWeightKg}) {
  if (entriesDesc.length < 2) return null;
  final current = entriesDesc.first;
  final remaining = goalWeightKg - current.weightKg;
  if (remaining.abs() < 0.05) return null; // already there

  // The rate of change (kg/day) over the last [days] - the entry closest to
  // (but not after) that cutoff stands in for "the weight [days] ago".
  double? rateOverDays(int days) {
    final cutoff = current.date.subtract(Duration(days: days));
    WeightEntry? reference;
    for (final e in entriesDesc) {
      if (!e.date.isAfter(cutoff)) {
        reference = e;
        break;
      }
    }
    reference ??= entriesDesc.length > 1 ? entriesDesc.last : null;
    if (reference == null || reference.id == current.id) return null;
    final spanDays = current.date.difference(reference.date).inDays;
    if (spanDays <= 0) return null;
    return (current.weightKg - reference.weightKg) / spanDays;
  }

  // 30 days is the central, "usual pace" estimate; 7 and 90 days (whichever
  // exist) give a faster/slower bound for the probable window - a recent
  // hot streak vs. the longer-term average.
  final midRate = rateOverDays(30) ?? rateOverDays(90) ?? rateOverDays(7);
  if (midRate == null || midRate == 0) return null;
  // Trending the wrong way entirely - nothing sensible to project.
  if ((remaining > 0) != (midRate > 0)) return null;

  DateTime? dateFor(double? rate) {
    if (rate == null || rate == 0) return null;
    if ((remaining > 0) != (rate > 0)) return null;
    final days = remaining / rate;
    if (days <= 0) return null;
    return current.date.add(Duration(days: days.round()));
  }

  final estimated = dateFor(midRate)!;
  final candidates = [dateFor(rateOverDays(7)), dateFor(rateOverDays(90)), estimated].whereType<DateTime>().toList()..sort();

  return GoalPrediction(dailyRateKg: midRate, estimatedDate: estimated, earliestDate: candidates.first, latestDate: candidates.last);
}

/// Average kg/week rate of change over the last [overDays] days (or as much
/// of that window as there's history for) - negative means losing weight.
/// Null without at least two entries spanning some real time.
///
/// [entriesDesc] must be sorted newest-first (date DESC).
double? weeklyRateKg(List<WeightEntry> entriesDesc, {int overDays = 30}) {
  if (entriesDesc.length < 2) return null;
  final current = entriesDesc.first;
  final cutoff = current.date.subtract(Duration(days: overDays));
  WeightEntry? reference;
  for (final e in entriesDesc) {
    if (!e.date.isAfter(cutoff)) {
      reference = e;
      break;
    }
  }
  reference ??= entriesDesc.last;
  if (reference.id == current.id) return null;
  final spanDays = current.date.difference(reference.date).inDays;
  if (spanDays <= 0) return null;
  return (current.weightKg - reference.weightKg) / spanDays * 7;
}

/// The weekly rate that would be needed, starting from the latest entry, to
/// reach [goalWeightKg] within [withinDays] (180 ≈ 6 meses) - the "what pace
/// would it actually take" counterpart to [weeklyRateKg]'s "what pace am I
/// actually at". Positive means needing to gain, negative needing to lose.
/// Null without any entries; 0 if already at the goal.
///
/// [entriesDesc] must be sorted newest-first (date DESC).
double? requiredWeeklyRateKg(List<WeightEntry> entriesDesc, {required double goalWeightKg, int withinDays = 180}) {
  if (entriesDesc.isEmpty) return null;
  final remaining = goalWeightKg - entriesDesc.first.weightKg;
  if (remaining.abs() < 0.05) return 0;
  return remaining / (withinDays / 7);
}
