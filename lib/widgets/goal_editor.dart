import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/bmi.dart';
import '../utils/units.dart';
import 'suma_widgets.dart';

/// Shared "meta de peso" editor used by both the onboarding wizard and
/// Ajustes: on/off switch, emagrecer/ganhar peso direction, the target
/// weight itself, a reference "peso ideal" range for the person's height,
/// and a preview of how their BMI would change at that target.
class GoalEditor extends StatelessWidget {
  final bool hasGoal;
  final ValueChanged<bool> onHasGoalChanged;
  final String goalType; // 'lose' or 'gain'
  final ValueChanged<String> onGoalTypeChanged;
  final double goalWeightKg;
  final ValueChanged<double> onGoalWeightChanged;
  final double? currentWeightKg;
  final double? heightCm;
  final String unitPref;

  const GoalEditor({
    super.key,
    required this.hasGoal,
    required this.onHasGoalChanged,
    required this.goalType,
    required this.onGoalTypeChanged,
    required this.goalWeightKg,
    required this.onGoalWeightChanged,
    required this.currentWeightKg,
    required this.heightCm,
    required this.unitPref,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weightStep = unitPref == 'lb' ? Units.lbToKg(0.5) : 0.1;
    final idealRange = Bmi.idealWeightRangeKg(heightCm);
    final currentBmi = Bmi.calculate(weightKg: currentWeightKg, heightCm: heightCm);
    final goalBmi = Bmi.calculate(weightKg: goalWeightKg, heightCm: heightCm);
    final mismatch = hasGoal &&
        currentWeightKg != null &&
        ((goalType == 'lose' && goalWeightKg > currentWeightKg!) || (goalType == 'gain' && goalWeightKg < currentWeightKg!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SumaCard(
          child: Row(
            children: [
              Expanded(child: Text('Definir meta de peso', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
              Switch(value: hasGoal, onChanged: onHasGoalChanged),
            ],
          ),
        ),
        if (hasGoal) ...[
          const SizedBox(height: 12),
          PillSwitcher<String>(
            values: const ['lose', 'gain'],
            labels: const ['Emagrecer', 'Ganhar peso'],
            selected: goalType,
            onChanged: onGoalTypeChanged,
          ),
          const SizedBox(height: 12),
          StepperField(
            label: 'Peso desejado',
            value: Units.displayValue(goalWeightKg, unitPref),
            unit: Units.label(unitPref),
            step: weightStep,
            min: Units.displayValue(20, unitPref),
            max: Units.displayValue(300, unitPref),
            onChanged: (v) => onGoalWeightChanged(Units.toKg(v, unitPref)),
          ),
          if (mismatch) ...[
            const SizedBox(height: 8),
            Text(
              goalType == 'lose'
                  ? 'Esse peso é maior que o atual - isso seria ganhar peso, não emagrecer.'
                  : 'Esse peso é menor que o atual - isso seria emagrecer, não ganhar peso.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.negative),
            ),
          ],
          if (idealRange != null) ...[
            const SizedBox(height: 12),
            Text(
              'Peso ideal para sua altura: ${Units.format(idealRange.$1, unitPref)} - ${Units.formatWithUnit(idealRange.$2, unitPref)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (currentBmi != null && goalBmi != null) ...[
            const SizedBox(height: 12),
            _BmiTransitionCard(currentBmi: currentBmi, goalBmi: goalBmi),
          ],
        ],
      ],
    );
  }
}

class _BmiTransitionCard extends StatelessWidget {
  final double currentBmi;
  final double goalBmi;
  const _BmiTransitionCard({required this.currentBmi, required this.goalBmi});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decreasing = goalBmi < currentBmi - 0.05;
    final increasing = goalBmi > currentBmi + 0.05;
    final arrowIcon = decreasing ? Icons.trending_down_rounded : (increasing ? Icons.trending_up_rounded : Icons.trending_flat_rounded);

    return SumaCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMC atual', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                Text(currentBmi.toStringAsFixed(1), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Bmi.color(currentBmi))),
              ],
            ),
          ),
          Icon(arrowIcon, color: scheme.onSurfaceVariant, size: 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('IMC na meta', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                Text(goalBmi.toStringAsFixed(1), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Bmi.color(goalBmi))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
