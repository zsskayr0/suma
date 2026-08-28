import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/bmi.dart';
import '../utils/goal_trend.dart';
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
  // Bumped by HomeScreen each time this tab becomes active again - replays
  // the chart's reveal animation and the stat tiles' rolling-number
  // count-up, instead of them just sitting at their already-settled values
  // (IndexedStack keeps this screen's state alive across tab switches, so
  // without this nothing would naturally replay on a revisit).
  final Object revealToken;

  const DashboardScreen({super.key, required this.onViewHistory, required this.revealToken});

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
        title: Row(
          children: [
            UserAvatar(avatarUrl: user.avatarUrl, name: user.name, radius: 18, isAdmin: user.isAdmin),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Olá, ${user.firstName} 👋',
                style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 23),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      // The "+" to register a weight is universal now - the floating pill
      // nav's raised center button (mobile) / the rail's button (desktop) -
      // so there's no per-screen add affordance here anymore.
      body: entries.isEmpty
          ? const _EmptyDashboard()
          : ResponsiveBody(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= Responsive.desktop;
                  final heroColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(
                        latest: latest!,
                        previous: entries.length > 1 ? entries[1] : null,
                        unitPref: user.unitPref,
                        goalWeightKg: user.goalWeightKg,
                        goalType: user.goalType,
                      ),
                      const SizedBox(height: 10),
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
                            const SizedBox(height: 6),
                            WeightLineChart(
                              series: [ChartSeries(label: user.name, color: Theme.of(context).colorScheme.primary, entries: last30)],
                              unitPref: user.unitPref,
                              goalWeightKg: user.goalWeightKg,
                              revealToken: revealToken,
                            ),
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
                        const SizedBox(height: 10),
                        _GoalCard(
                          entries: entries,
                          goalWeightKg: user.goalWeightKg!,
                          goalType: user.goalType,
                          unitPref: user.unitPref,
                        ),
                      ],
                      // Right below the goal, not at the top of the page -
                      // the streak is a companion to "how's the goal going",
                      // not the first thing you see.
                      const SizedBox(height: 10),
                      _WeighInStreakCard(entries: entries),
                    ],
                  );

                  // KeyedSubtree forces a fresh mount on every revealToken
                  // change - cheap here (no data fetching, just presentation)
                  // and it's what makes each StatTile's rolling-number
                  // count-up (which only animates from 0 on first mount)
                  // replay every time this tab becomes active again.
                  final statGrid = KeyedSubtree(
                    key: ValueKey('stats_$revealToken'),
                    child: StatGrid(
                    children: [
                      _deltaTile(context, entries: entries, days: 7, unitPref: user.unitPref, goalWeightKg: user.goalWeightKg, goalType: user.goalType),
                      _deltaTile(context, entries: entries, days: 30, unitPref: user.unitPref, goalWeightKg: user.goalWeightKg, goalType: user.goalType),
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
                    ),
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
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: sideColumn),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        statGrid,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heroColumn,
                      const SizedBox(height: 10),
                      sideColumn,
                      const SizedBox(height: 10),
                      statGrid,
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _deltaTile(
    BuildContext context, {
    required List<WeightEntry> entries,
    required int days,
    required String unitPref,
    required double? goalWeightKg,
    required String goalType,
  }) {
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
    final positive = goalTrendPositive(fromKg: reference.weightKg, toKg: latest.weightKg, goalWeightKg: goalWeightKg, goalType: goalType);
    return StatTile(
      icon: losing ? Icons.trending_down_rounded : (deltaKg == 0 ? Icons.trending_flat_rounded : Icons.trending_up_rounded),
      color: Theme.of(context).colorScheme.primary,
      label: 'Variação em $days dias',
      value: '$sign${delta.toStringAsFixed(1)} ${Units.label(unitPref)}',
      trendPositive: positive,
    );
  }
}

const _weekdayLettersMonFirst = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

/// "Sequência de pesagem" - a Duolingo-style weekly streak strip: one column
/// per day of the current week (Monday first), a flame for days with a
/// weight entry logged, a dashed empty circle for days without one (whether
/// that's a day not reached yet or one that got missed - the app can't tell
/// those apart, and visually they read the same either way). The current
/// consecutive-day streak (counting back from today) is called out above it.
class _WeighInStreakCard extends StatelessWidget {
  final List<WeightEntry> entries; // date DESC
  const _WeighInStreakCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final loggedDays = entries.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet();
    // Monday of the current week - DateTime.weekday is already 1=Mon..7=Sun,
    // so this lines up directly with _weekdayLettersMonFirst's order.
    final monday = todayOnly.subtract(Duration(days: todayOnly.weekday - 1));
    final weekDays = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];

    var streak = 0;
    for (var d = todayOnly; loggedDays.contains(d); d = d.subtract(const Duration(days: 1))) {
      streak++;
    }

    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('Essa semana', padding: EdgeInsets.zero),
              const Spacer(),
              if (streak > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 4),
                    Text(
                      streak == 1 ? '1 dia seguido' : '$streak dias seguidos',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _StreakDay(
                  label: _weekdayLettersMonFirst[i],
                  logged: loggedDays.contains(weekDays[i]),
                  isToday: weekDays[i] == todayOnly,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakDay extends StatelessWidget {
  final String label;
  final bool logged;
  final bool isToday;
  const _StreakDay({required this.label, required this.logged, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.3,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 28,
          height: 28,
          child: logged
              ? const Center(child: Text('🔥', style: TextStyle(fontSize: 22)))
              : CustomPaint(painter: _DashedCirclePainter(color: scheme.outlineVariant.withValues(alpha: 0.7))),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const dashCount = 10;
    const gapFraction = 0.45; // fraction of each segment left as a gap
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * math.pi;
      final sweep = (2 * math.pi / dashCount) * (1 - gapFraction);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => oldDelegate.color != color;
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
            Icon(Icons.monitor_weight, size: 64, color: scheme.outline),
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
  final double? goalWeightKg;
  final String goalType;

  const _HeroCard({required this.latest, required this.previous, required this.unitPref, required this.goalWeightKg, required this.goalType});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previousEntry = previous;
    final deltaPill = previousEntry == null ? null : _buildDeltaPill(context, previousEntry.weightKg, latest.weightKg);

    return SumaCard(
      padding: const EdgeInsets.all(20),
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

  Widget _buildDeltaPill(BuildContext context, double fromKg, double toKg) {
    final scheme = Theme.of(context).colorScheme;
    final deltaKg = toKg - fromKg;
    if (deltaKg == 0) {
      return Pill(text: '0 ${Units.label(unitPref)}', color: scheme.outline, icon: Icons.trending_flat_rounded);
    }
    final losing = deltaKg < 0;
    final sign = losing ? '-' : '+';
    final positive = goalTrendPositive(fromKg: fromKg, toKg: toKg, goalWeightKg: goalWeightKg, goalType: goalType);
    return Pill(
      text: '$sign${Units.displayValue(deltaKg.abs(), unitPref).toStringAsFixed(1)} ${Units.label(unitPref)}',
      color: positive == false ? AppColors.negative : AppColors.positive,
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
  final String goalType; // 'lose' or 'gain'
  final String unitPref;

  const _GoalCard({
    required this.entries,
    required this.goalWeightKg,
    required this.goalType,
    required this.unitPref,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = entries.first.weightKg;
    // Progress is always measured against the weight from exactly a year
    // ago (falling back to the oldest entry on file for anyone without a
    // full year of history yet) - a rolling window, not a fixed snapshot
    // from whenever the goal happened to be set.
    final start = goalBaselineWeightKg(entries);
    final remainingKg = (goalWeightKg - current).abs();
    final reached = remainingKg < 0.05;
    final progress = goalProgressFraction(currentKg: current, startKg: start, goalWeightKg: goalWeightKg);
    final verb = goalType == 'lose' ? 'emagrecer' : 'ganhar peso';

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
            reached ? 'Meta alcançada! 🎉' : 'Faltam ${Units.displayValue(remainingKg, unitPref).toStringAsFixed(1)} ${Units.label(unitPref)} para $verb · ${(progress * 100).toStringAsFixed(0)}% concluído',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
