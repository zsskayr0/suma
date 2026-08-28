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
import '../utils/weight_insights.dart';
import '../widgets/suma_widgets.dart';
import '../widgets/weight_line_chart.dart';
import 'bmi_screen.dart';
import 'entry_form_sheet.dart';

const _monthAbbr = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

// Numeric dd/MM/yyyy is used everywhere else in the app specifically to
// avoid needing intl's locale data initialized (see DateFormat calls
// elsewhere) - this one spells the month out ("17 de dez. de 2025"), so it
// uses its own small manual lookup instead of DateFormat's locale-aware
// MMM, same reasoning as the day-letter arrays already scattered around the
// app (_weekdayLettersMonFirst here, _monthNames in Histórico, ...).
String _longDate(DateTime d) => '${d.day} de ${_monthAbbr[d.month - 1]}. de ${d.year}';

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

    // "Faixa de peso" and "Variação total" look at the last year, not the
    // whole history - years-old weights (right after starting, say) would
    // otherwise dominate the min/max/delta forever, even long after they
    // stopped being relevant.
    final yearCutoff = DateTime.now().subtract(const Duration(days: 365));
    final yearEntries = entries.where((e) => !e.date.isBefore(DateTime(yearCutoff.year, yearCutoff.month, yearCutoff.day))).toList();
    final rangeStats = yearEntries.isNotEmpty ? weightRangeStats(yearEntries) : null;
    final prediction = (entries.length > 1 && user.goalWeightKg != null) ? predictGoalArrival(entriesDesc: entries, goalWeightKg: user.goalWeightKg!) : null;

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
                      _BmiCard(
                        bmi: bmi,
                        heightMissing: user.heightCm == null,
                        onTap: bmi == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BmiScreen())),
                      ),
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

                  // "Faixa de peso" (all-time min/média/máximo + a couple
                  // more stat tiles) and "Insights" (7-day trend + goal
                  // arrival prediction) - both need at least 2 entries to
                  // say anything real, same bar History's own summary row
                  // uses.
                  final extraSections = yearEntries.length > 1 && rangeStats != null
                      ? [
                          const SizedBox(height: 22),
                          const SectionLabel('Geral'),
                          _WeightRangeCard(stats: rangeStats, currentKg: entries.first.weightKg, goalWeightKg: user.goalWeightKg, unitPref: user.unitPref),
                          const SizedBox(height: 14),
                          KeyedSubtree(
                            key: ValueKey('range_stats_$revealToken'),
                            child: _RangeStatGrid(entries: yearEntries, stats: rangeStats, unitPref: user.unitPref, goalWeightKg: user.goalWeightKg, goalType: user.goalType),
                          ),
                          const SizedBox(height: 22),
                          const SectionLabel('Insights'),
                          _TrendInsightCard(entries: entries, unitPref: user.unitPref, goalWeightKg: user.goalWeightKg, goalType: user.goalType),
                          const SizedBox(height: 10),
                          _PaceCard(entries: entries, unitPref: user.unitPref, goalType: user.goalType),
                          if (prediction != null) ...[
                            const SizedBox(height: 10),
                            _GoalPredictionCard(prediction: prediction, goalWeightKg: user.goalWeightKg!, unitPref: user.unitPref),
                          ],
                          if (user.goalWeightKg != null) ...[
                            const SizedBox(height: 10),
                            _RequiredPaceCard(entries: entries, goalWeightKg: user.goalWeightKg!, unitPref: user.unitPref),
                          ],
                        ]
                      : const <Widget>[];

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
                        ...extraSections,
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
                      ...extraSections,
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
  final VoidCallback? onTap;
  const _BmiCard({required this.bmi, required this.heightMissing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (bmi == null) {
      return SumaCard(
        onTap: onTap,
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
      onTap: onTap,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(bmi!.toStringAsFixed(1), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
              if (onTap != null) ...[
                const Spacer(),
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// "Faixa de peso" - the all-time min/média/máximo, with a horizontal bar
/// visualizing where the current weight sits between the two extremes (and,
/// with a goal on file, a tick marking where the goal sits too).
class _WeightRangeCard extends StatelessWidget {
  final WeightRangeStats stats;
  final double currentKg;
  final double? goalWeightKg;
  final String unitPref;
  const _WeightRangeCard({required this.stats, required this.currentKg, required this.goalWeightKg, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Faixa de peso', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Desde ${_longDate(stats.since)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          _RangeBar(minKg: stats.minKg, maxKg: stats.maxKg, currentKg: currentKg, goalWeightKg: goalWeightKg),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _RangeLabel(label: 'Mais baixo', value: Units.formatWithUnit(stats.minKg, unitPref), color: AppColors.positive, align: CrossAxisAlignment.start)),
              Expanded(child: _RangeLabel(label: 'Média', value: Units.formatWithUnit(stats.avgKg, unitPref), color: scheme.onSurface, align: CrossAxisAlignment.center)),
              Expanded(child: _RangeLabel(label: 'Mais alto', value: Units.formatWithUnit(stats.maxKg, unitPref), color: AppColors.negative, align: CrossAxisAlignment.end)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final CrossAxisAlignment align;
  const _RangeLabel({required this.label, required this.value, required this.color, required this.align});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _RangeBar extends StatelessWidget {
  final double minKg;
  final double maxKg;
  final double currentKg;
  final double? goalWeightKg;
  const _RangeBar({required this.minKg, required this.maxKg, required this.currentKg, required this.goalWeightKg});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final span = (maxKg - minKg).abs() < 0.05 ? 1.0 : maxKg - minKg;
    final currentFraction = ((currentKg - minKg) / span).clamp(0.0, 1.0);
    final goalFraction = goalWeightKg == null ? null : ((goalWeightKg! - minKg) / span).clamp(0.0, 1.0);

    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 6, decoration: BoxDecoration(color: scheme.outlineVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(100))),
              if (goalFraction != null)
                Positioned(
                  left: (goalFraction * width - 1).clamp(0.0, width - 2),
                  child: Container(width: 2, height: 16, decoration: BoxDecoration(color: AppColors.goalAccent, borderRadius: BorderRadius.circular(2))),
                ),
              Positioned(
                left: (currentFraction * width - 8).clamp(0.0, width - 16),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary, border: Border.all(color: Theme.of(context).cardTheme.color ?? scheme.surface, width: 3)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RangeStatGrid extends StatelessWidget {
  final List<WeightEntry> entries; // date DESC, last year only
  final WeightRangeStats stats;
  final String unitPref;
  final double? goalWeightKg;
  final String goalType;
  const _RangeStatGrid({required this.entries, required this.stats, required this.unitPref, required this.goalWeightKg, required this.goalType});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalDeltaKg = entries.first.weightKg - entries.last.weightKg;
    final totalTrend = goalTrendPositive(fromKg: entries.last.weightKg, toKg: entries.first.weightKg, goalWeightKg: goalWeightKg, goalType: goalType);
    final sign = totalDeltaKg == 0 ? '' : (totalDeltaKg < 0 ? '-' : '+');

    return StatGrid(
      children: [
        StatTile(
          icon: totalDeltaKg <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          color: scheme.primary,
          label: 'Variação total',
          value: '$sign${Units.displayValue(totalDeltaKg.abs(), unitPref).toStringAsFixed(1)} ${Units.label(unitPref)}',
          trendPositive: totalTrend,
        ),
        StatTile(icon: Icons.calendar_month_outlined, color: scheme.primary, label: 'Acompanhamento', value: '${stats.monthsTracked} meses'),
      ],
    );
  }
}

/// "Sua tendência de 7 dias" - same delta math as the 7-day StatTile above,
/// just with a status Pill instead of just a colored value.
class _TrendInsightCard extends StatelessWidget {
  final List<WeightEntry> entries; // date DESC
  final String unitPref;
  final double? goalWeightKg;
  final String goalType;
  const _TrendInsightCard({required this.entries, required this.unitPref, required this.goalWeightKg, required this.goalType});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = entries.first;
    final cutoff = latest.date.subtract(const Duration(days: 7));
    WeightEntry? reference;
    for (final e in entries) {
      if (!e.date.isAfter(cutoff)) {
        reference = e;
        break;
      }
    }
    reference ??= entries.length > 1 ? entries.last : null;
    if (reference == null || reference.id == latest.id) return const SizedBox.shrink();

    final deltaKg = latest.weightKg - reference.weightKg;
    final sign = deltaKg == 0 ? '' : (deltaKg < 0 ? '-' : '+');
    final statusLabel = deltaKg.abs() < 0.05 ? 'Estável' : (deltaKg < 0 ? 'Em queda' : 'Em alta');
    final positive = goalTrendPositive(fromKg: reference.weightKg, toKg: latest.weightKg, goalWeightKg: goalWeightKg, goalType: goalType);
    final statusColor = positive == null ? scheme.onSurfaceVariant : (positive ? AppColors.positive : AppColors.negative);

    return SumaCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(deltaKg <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$sign${Units.displayValue(deltaKg.abs(), unitPref).toStringAsFixed(1)} ${Units.label(unitPref)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('Sua tendência de 7 dias', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Pill(text: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}

/// "Seu ritmo médio" - the last-30-days weekly rate (kg/semana), regardless
/// of whether there's a goal on file - just "how fast is this actually
/// moving lately".
class _PaceCard extends StatelessWidget {
  final List<WeightEntry> entries; // date DESC
  final String unitPref;
  final String goalType;
  const _PaceCard({required this.entries, required this.unitPref, required this.goalType});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = weeklyRateKg(entries);
    if (rate == null) return const SizedBox.shrink();
    final sign = rate.abs() < 0.05 ? '' : (rate < 0 ? '-' : '+');
    // Deliberately not passing goalWeightKg through - this asks "is a rate
    // of *this sign* generally good for a goal of *this type*", not "is 0kg
    // -> rate kg closer to the actual goal number", which wouldn't mean
    // anything sensible here.
    final positive = rate.abs() < 0.05 ? null : goalTrendPositive(fromKg: 0, toKg: rate, goalType: goalType);

    return SumaCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.speed_rounded, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sign${Units.displayValue(rate.abs(), unitPref).toStringAsFixed(2)} ${Units.label(unitPref)}/semana',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: positive == null ? null : (positive ? AppColors.positive : AppColors.negative),
                      ),
                ),
                Text('Seu ritmo médio (últimos 30 dias)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Pra bater a meta em até 6 meses" - the pace that would actually take,
/// compared against the pace from [_PaceCard] so it's obvious whether the
/// current rhythm is already enough or falling short.
class _RequiredPaceCard extends StatelessWidget {
  final List<WeightEntry> entries; // date DESC
  final double goalWeightKg;
  final String unitPref;
  const _RequiredPaceCard({required this.entries, required this.goalWeightKg, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final required = requiredWeeklyRateKg(entries, goalWeightKg: goalWeightKg);
    if (required == null) return const SizedBox.shrink();
    if (required.abs() < 0.05) {
      return SumaCard(
        child: Row(
          children: [
            Icon(Icons.celebration_outlined, color: AppColors.positive, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Você já está na meta! 🎉', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
          ],
        ),
      );
    }
    final verb = required < 0 ? 'perder' : 'ganhar';
    final requiredLabel = '${Units.displayValue(required.abs(), unitPref).toStringAsFixed(2)} ${Units.label(unitPref)}/semana';

    final actualRate = weeklyRateKg(entries);
    // "Enough" means moving the same direction as required, at least as
    // fast - actualRate/required share sign only when both point the same
    // way the goal actually needs.
    final onTrackFor6Months = actualRate != null && (actualRate / required) >= 1.0 && (actualRate < 0) == (required < 0);

    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch_outlined, color: scheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Pra bater a meta em até 6 meses', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 10),
          Text('Seria necessário $verb cerca de $requiredLabel.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (actualRate != null) ...[
            const SizedBox(height: 6),
            Text(
              onTrackFor6Months ? 'Seu ritmo atual já é suficiente para isso. 🎉' : 'Seu ritmo atual está mais lento que isso - no passo de hoje, deve levar mais que 6 meses.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onTrackFor6Months ? AppColors.positive : AppColors.negative, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Previsão da meta" - when the goal will likely be reached at the current
/// pace, with a probable arrival window instead of a single falsely-precise
/// date (see predictGoalArrival).
class _GoalPredictionCard extends StatelessWidget {
  final GoalPrediction prediction;
  final double goalWeightKg;
  final String unitPref;
  const _GoalPredictionCard({required this.prediction, required this.goalWeightKg, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: AppColors.goalAccent, size: 18),
              const SizedBox(width: 8),
              Text('Previsão da meta', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Nesse ritmo, você atingirá ${Units.formatWithUnit(goalWeightKg, unitPref)} por volta de ${_longDate(prediction.estimatedDate)}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text('~${_longDate(prediction.estimatedDate)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Chegada provável entre ${_longDate(prediction.earliestDate)} e ${_longDate(prediction.latestDate)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
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
