import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/bmi.dart';
import '../utils/responsive.dart';
import '../utils/units.dart';
import '../widgets/suma_widgets.dart';
import '../widgets/weight_line_chart.dart';
import 'entry_form_sheet.dart';

/// "Hoje" tab: a real dashboard instead of a bare list - current weight,
/// live BMI, a 30-day trend chart and quick stats. Anything older than 30
/// days lives in the Histórico tab (reachable via [onViewHistory]).
class DashboardScreen extends StatelessWidget {
  final VoidCallback onViewHistory;

  const DashboardScreen({super.key, required this.onViewHistory});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentProfile!;
    final entries = appState.entries; // date DESC, id DESC
    final latest = entries.isNotEmpty ? entries.first : null;
    final bmi = Bmi.calculate(weightKg: latest?.weightKg, heightCm: user.heightCm);

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final last30 = entries.where((e) => !e.date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${user.firstName} 👋'),
        actions: [
          IconButton(
            tooltip: 'Novo registro',
            onPressed: () => EntryFormSheet.show(context),
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: entries.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => EntryFormSheet.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Registrar peso'),
            ),
      body: entries.isEmpty
          ? const _EmptyDashboard()
          : ResponsiveBody(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= Responsive.desktop;
                  final heroColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(latest: latest!, previous: entries.length > 1 ? entries[1] : null, unitPref: user.unitPref),
                      const SizedBox(height: 14),
                      SumaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Últimos 30 dias', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                ),
                                TextButton(onPressed: onViewHistory, child: const Text('Ver histórico')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            WeightLineChart(entries: last30, unitPref: user.unitPref, goalWeightKg: user.goalWeightKg, lineColor: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    ],
                  );

                  final sideColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BmiCard(bmi: bmi, heightMissing: user.heightCm == null),
                      if (user.goalWeightKg != null) ...[
                        const SizedBox(height: 14),
                        _GoalCard(entries: entries, goalWeightKg: user.goalWeightKg!, unitPref: user.unitPref),
                      ],
                    ],
                  );

                  final statGrid = StatGrid(
                    children: [
                      _deltaTile(context, entries: entries, days: 7, unitPref: user.unitPref),
                      _deltaTile(context, entries: entries, days: 30, unitPref: user.unitPref),
                      StatTile(
                        icon: Icons.pie_chart_outline,
                        color: AppColors.fatAccent,
                        label: 'Gordura corporal',
                        value: latest.bodyFatPct != null ? '${latest.bodyFatPct!.toStringAsFixed(1)}%' : '—',
                      ),
                      StatTile(
                        icon: Icons.water_drop_outlined,
                        color: AppColors.hydrationAccent,
                        label: 'Hidratação',
                        value: latest.hydrationPct != null ? '${latest.hydrationPct!.toStringAsFixed(1)}%' : '—',
                      ),
                    ],
                  );

                  if (wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: heroColumn),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: sideColumn),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        statGrid,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heroColumn,
                      const SizedBox(height: 14),
                      sideColumn,
                      const SizedBox(height: 14),
                      statGrid,
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _deltaTile(BuildContext context, {required List<WeightEntry> entries, required int days, required String unitPref}) {
    final latest = entries.first;
    final cutoff = latest.date.subtract(Duration(days: days));
    WeightEntry? reference;
    for (final e in entries) {
      if (!e.date.isAfter(cutoff)) {
        reference = e;
        break;
      }
    }
    reference ??= entries.length > 1 ? entries.last : null;

    if (reference == null || reference.id == latest.id) {
      return StatTile(icon: Icons.timeline_outlined, color: Theme.of(context).colorScheme.primary, label: '$days dias', value: '—');
    }
    final deltaKg = latest.weightKg - reference.weightKg;
    final delta = Units.displayValue(deltaKg.abs(), unitPref);
    final losing = deltaKg < 0;
    final sign = deltaKg == 0 ? '' : (losing ? '-' : '+');
    return StatTile(
      icon: losing ? Icons.trending_down_rounded : (deltaKg == 0 ? Icons.trending_flat_rounded : Icons.trending_up_rounded),
      color: Theme.of(context).colorScheme.primary,
      label: 'Variação em $days dias',
      value: '$sign${delta.toStringAsFixed(1)} ${Units.label(unitPref)}',
      trendPositive: deltaKg == 0 ? null : losing,
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_weight_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text('Nenhum registro ainda', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Toque no botão abaixo para registrar seu primeiro peso.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => EntryFormSheet.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo registro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final WeightEntry latest;
  final WeightEntry? previous;
  final String unitPref;

  const _HeroCard({required this.latest, required this.previous, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previousEntry = previous;
    final deltaPill = previousEntry == null ? null : _buildDeltaPill(context, latest.weightKg - previousEntry.weightKg);

    return SumaCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Peso atual', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: Units.format(latest.weightKg, unitPref), style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                    TextSpan(text: ' ${Units.label(unitPref)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (deltaPill != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: deltaPill),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Atualizado em ${DateFormat('dd/MM/yyyy').format(latest.date)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaPill(BuildContext context, double deltaKg) {
    final scheme = Theme.of(context).colorScheme;
    if (deltaKg == 0) {
      return Pill(text: '0 ${Units.label(unitPref)}', color: scheme.outline, icon: Icons.trending_flat_rounded);
    }
    final losing = deltaKg < 0;
    final sign = losing ? '-' : '+';
    return Pill(
      text: '$sign${Units.displayValue(deltaKg.abs(), unitPref).toStringAsFixed(1)} ${Units.label(unitPref)}',
      color: losing ? AppColors.positive : AppColors.negative,
      icon: losing ? Icons.trending_down_rounded : Icons.trending_up_rounded,
    );
  }
}

class _BmiCard extends StatelessWidget {
  final double? bmi;
  final bool heightMissing;
  const _BmiCard({required this.bmi, required this.heightMissing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (bmi == null) {
      return SumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IMC', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              heightMissing ? 'Cadastre sua altura em Ajustes para calcular.' : 'Registre um peso para calcular.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    final color = Bmi.color(bmi!);
    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('IMC (tempo real)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
              Pill(text: Bmi.category(bmi!), color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(bmi!.toStringAsFixed(1), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final List<WeightEntry> entries; // date DESC
  final double goalWeightKg;
  final String unitPref;

  const _GoalCard({required this.entries, required this.goalWeightKg, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = entries.first.weightKg;
    final start = entries.last.weightKg;
    final totalDelta = goalWeightKg - start;
    final doneDelta = current - start;
    final progress = totalDelta == 0 ? 1.0 : (doneDelta / totalDelta).clamp(0.0, 1.0).toDouble();
    final remainingKg = (goalWeightKg - current).abs();
    final reached = remainingKg < 0.05;

    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppColors.goalAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Meta: ${Units.formatWithUnit(goalWeightKg, unitPref)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),
          GoalProgressBar(progress: progress, color: AppColors.goalAccent),
          const SizedBox(height: 8),
          Text(
            reached ? 'Meta alcançada! 🎉' : 'Faltam ${Units.displayValue(remainingKg, unitPref).toStringAsFixed(1)} ${Units.label(unitPref)} · ${(progress * 100).toStringAsFixed(0)}% concluído',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
