import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/bmi.dart';
import '../utils/height_units.dart';
import '../utils/units.dart';
import '../widgets/suma_widgets.dart';

const _gaugeMin = 13.5;
const _gaugeMax = 42.0;

/// "IMC" detail screen, opened from the dashboard's IMC card - a gauge
/// showing exactly where the current BMI sits among the WHO bands, the
/// numbers behind it (altura/peso/faixa normal/desvio), and the full
/// category breakdown.
class BmiScreen extends StatelessWidget {
  const BmiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentProfile!;
    final entries = appState.entries;
    final latest = entries.isNotEmpty ? entries.first : null;
    final bmi = Bmi.calculate(weightKg: latest?.weightKg, heightCm: user.heightCm);
    final idealRange = Bmi.idealWeightRangeKg(user.heightCm);

    double? deviationKg;
    if (latest != null && idealRange != null) {
      if (latest.weightKg < idealRange.$1) {
        deviationKg = latest.weightKg - idealRange.$1;
      } else if (latest.weightKg > idealRange.$2) {
        deviationKg = latest.weightKg - idealRange.$2;
      } else {
        deviationKg = 0;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('IMC')),
      body: bmi == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  user.heightCm == null ? 'Cadastre sua altura em Ajustes para calcular seu IMC.' : 'Registre um peso para calcular seu IMC.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Resultado'),
                  SumaCard(
                    child: Column(
                      children: [
                        _BmiGauge(bmi: bmi),
                        const SizedBox(height: 8),
                        Pill(text: Bmi.category(bmi), color: Bmi.color(bmi)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SumaCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.height_rounded, label: 'Altura', value: HeightUnits.formatWithUnit(user.heightCm!, appState.heightUnitPref)),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _InfoRow(icon: Icons.monitor_weight_outlined, label: 'Peso', value: Units.formatWithUnit(latest!.weightKg, user.unitPref)),
                        if (idealRange != null) ...[
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _InfoRow(icon: Icons.adjust_rounded, label: 'Faixa normal', value: '${Units.format(idealRange.$1, user.unitPref)} - ${Units.formatWithUnit(idealRange.$2, user.unitPref)}'),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _InfoRow(
                            icon: Icons.show_chart_rounded,
                            label: 'Desvio',
                            value: deviationKg == null || deviationKg.abs() < 0.05
                                ? 'Dentro da faixa'
                                : '${deviationKg > 0 ? '+' : ''}${Units.displayValue(deviationKg, user.unitPref).toStringAsFixed(1)} ${Units.label(user.unitPref)}',
                            valueColor: deviationKg == null || deviationKg.abs() < 0.05 ? AppColors.positive : AppColors.negative,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _CategoriesCard(heightCm: user.heightCm!, unitPref: user.unitPref, currentBmi: bmi),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: valueColor ?? scheme.onSurface)),
        ],
      ),
    );
  }
}

/// "Categorias" - the full WHO breakdown, switchable (via [PillSwitcher],
/// same widget the rest of Suma already uses for kg/lb, Emagrecer/Ganhar
/// peso, ...) between each band's actual BMI range and the equivalent
/// weight range for this person's own height ("quantos kg posso ter em
/// cada categoria").
class _CategoriesCard extends StatefulWidget {
  final double heightCm;
  final String unitPref;
  final double currentBmi;
  const _CategoriesCard({required this.heightCm, required this.unitPref, required this.currentBmi});

  @override
  State<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends State<_CategoriesCard> {
  String _mode = 'bmi'; // 'bmi' or 'weight'

  @override
  Widget build(BuildContext context) {
    final activeBand = bmiBandFor(widget.currentBmi);
    final heightM = widget.heightCm / 100;

    String rangeText(BmiBand band) {
      if (_mode == 'bmi') {
        return band.max == null
            ? '≥ ${band.min.toStringAsFixed(1)}'
            : (band.min <= 0 ? '≤ ${(band.max! - 0.1).toStringAsFixed(1)}' : '${band.min.toStringAsFixed(1)} – ${(band.max! - 0.1).toStringAsFixed(1)}');
      }
      final minKg = band.min * heightM * heightM;
      final maxKg = band.max == null ? null : band.max! * heightM * heightM;
      if (maxKg == null) return '≥ ${Units.formatWithUnit(minKg, widget.unitPref)}';
      if (band.min <= 0) return '≤ ${Units.formatWithUnit(maxKg, widget.unitPref)}';
      return '${Units.format(minKg, widget.unitPref)} – ${Units.formatWithUnit(maxKg, widget.unitPref)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel('Categorias', padding: EdgeInsets.zero)),
            SizedBox(
              width: 148,
              child: PillSwitcher<String>(
                values: const ['bmi', 'weight'],
                labels: ['IMC', Units.label(widget.unitPref).toUpperCase()],
                selected: _mode,
                onChanged: (v) => setState(() => _mode = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SumaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < bmiBands.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _CategoryRow(band: bmiBands[i], active: activeBand == bmiBands[i], rangeText: rangeText(bmiBands[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final BmiBand band;
  final bool active;
  final String rangeText;
  const _CategoryRow({required this.band, required this.active, required this.rangeText});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: active ? band.color.withValues(alpha: 0.10) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(width: 4, height: 22, decoration: BoxDecoration(color: band.color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Text(band.label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? scheme.onSurface : scheme.onSurfaceVariant))),
          Text(rangeText, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}

/// A semicircular gauge spanning every [bmiBands] color, with a dot marking
/// where [bmi] falls and the number itself centered underneath.
class _BmiGauge extends StatelessWidget {
  final double bmi;
  const _BmiGauge({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 150,
      child: CustomPaint(
        painter: _GaugePainter(bmi: bmi, trackColor: scheme.outlineVariant.withValues(alpha: 0.3), labelColor: scheme.onSurfaceVariant, valueColor: scheme.onSurface),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double bmi;
  final Color trackColor;
  final Color labelColor;
  final Color valueColor;
  const _GaugePainter({required this.bmi, required this.trackColor, required this.labelColor, required this.valueColor});

  double _angleFor(double value) {
    final t = ((value - _gaugeMin) / (_gaugeMax - _gaugeMin)).clamp(0.0, 1.0);
    return math.pi + t * math.pi; // sweeps from 180° (left) to 360°/0° (right), through the top
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 16);
    final radius = math.min(size.width / 2 - 24, size.height - 40);
    const strokeWidth = 12.0;

    for (final band in bmiBands) {
      final startAngle = _angleFor(band.min);
      final endAngle = _angleFor(band.max ?? _gaugeMax);
      if (endAngle <= startAngle) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        Paint()
          ..color = band.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Boundary tick labels - the gauge's own bounds plus the two bounds of
    // "peso normal" (the ones anyone actually cares about at a glance).
    for (final v in [_gaugeMin, 18.5, 25.0, _gaugeMax]) {
      final angle = _angleFor(v);
      final tickOuter = center + Offset(math.cos(angle), math.sin(angle)) * (radius + strokeWidth / 2 + 2);
      final labelPos = center + Offset(math.cos(angle), math.sin(angle)) * (radius + strokeWidth / 2 + 14);
      _drawLabel(canvas, v.toStringAsFixed(1), labelPos);
      canvas.drawCircle(tickOuter, 1.4, Paint()..color = labelColor.withValues(alpha: 0.5));
    }

    // Marker for the actual BMI value.
    final markerAngle = _angleFor(bmi);
    final markerPos = center + Offset(math.cos(markerAngle), math.sin(markerAngle)) * radius;
    canvas.drawCircle(markerPos, 8, Paint()..color = Colors.white);
    canvas.drawCircle(markerPos, 8, Paint()
      ..color = Bmi.color(bmi)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    canvas.drawCircle(markerPos, 3.4, Paint()..color = Bmi.color(bmi));

    // The number itself, centered under the arc.
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: 'IMC\n', style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w600)),
          TextSpan(text: bmi.toStringAsFixed(1), style: TextStyle(fontSize: 30, color: valueColor, fontWeight: FontWeight.w800)),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - radius * 0.55 - painter.height / 2));
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.bmi != bmi;
}
