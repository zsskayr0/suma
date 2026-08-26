import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/entry.dart';
import '../utils/units.dart';

/// One plotted line: a person's entries (ascending by date), the color it's
/// drawn in, and the label shown for it in the legend when there's more
/// than one series (comparing family members).
class ChartSeries {
  final String label;
  final Color color;
  final List<WeightEntry> entries; // must be sorted ascending by date

  const ChartSeries({required this.label, required this.color, required this.entries});
}

/// A smooth, gradient-filled weight trend chart drawn entirely with
/// [CustomPainter] (no charting package dependency). Plots one or more
/// [ChartSeries] on a shared date/value scale - a single series gets the
/// full "dashboard" look (gradient fill, end marker); two or more get a
/// legend and plain lines instead, so the comparison stays readable.
class WeightLineChart extends StatelessWidget {
  final List<ChartSeries> series;
  final String unitPref;
  final double? goalWeightKg;
  final double height;

  const WeightLineChart({
    super.key,
    required this.series,
    required this.unitPref,
    this.goalWeightKg,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nonEmpty = series.where((s) => s.entries.isNotEmpty).toList();
    final totalPoints = nonEmpty.fold<int>(0, (sum, s) => sum + s.entries.length);

    if (nonEmpty.isEmpty || totalPoints < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            nonEmpty.isEmpty ? 'Sem registros neste período' : 'Registre mais um dia para ver a evolução',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(
              series: nonEmpty,
              unitPref: unitPref,
              goalWeightKg: goalWeightKg,
              gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
              labelColor: scheme.onSurfaceVariant,
              markerFill: scheme.surface,
              singleSeriesFill: nonEmpty.length == 1,
            ),
          ),
        ),
        if (nonEmpty.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in nonEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(s.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartSeries> series;
  final String unitPref;
  final double? goalWeightKg;
  final Color gridColor;
  final Color labelColor;
  final Color markerFill;
  final bool singleSeriesFill;

  _ChartPainter({
    required this.series,
    required this.unitPref,
    required this.goalWeightKg,
    required this.gridColor,
    required this.labelColor,
    required this.markerFill,
    required this.singleSeriesFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    const topPad = 14.0;
    const sidePad = 2.0;
    final chartHeight = size.height - bottomPad - topPad;

    DateTime minDate = series.first.entries.first.date;
    DateTime maxDate = series.first.entries.last.date;
    double minV = double.infinity;
    double maxV = double.negativeInfinity;
    for (final s in series) {
      for (final e in s.entries) {
        if (e.date.isBefore(minDate)) minDate = e.date;
        if (e.date.isAfter(maxDate)) maxDate = e.date;
        final v = Units.displayValue(e.weightKg, unitPref);
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    final displayGoal = goalWeightKg != null ? Units.displayValue(goalWeightKg!, unitPref) : null;
    if (displayGoal != null) {
      minV = math.min(minV, displayGoal);
      maxV = math.max(maxV, displayGoal);
    }
    if ((maxV - minV).abs() < 0.6) {
      maxV += 0.6;
      minV -= 0.6;
    }
    final span = maxV - minV;
    minV -= span * 0.18;
    maxV += span * 0.18;

    final totalDays = math.max(1, maxDate.difference(minDate).inDays);

    double xFor(DateTime d) => sidePad + (d.difference(minDate).inDays / totalDays) * (size.width - sidePad * 2);
    double yFor(double v) => topPad + chartHeight - ((v - minV) / (maxV - minV)) * chartHeight;

    // Horizontal gridlines.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topPad + chartHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Goal dashed line.
    if (displayGoal != null) {
      _drawDashedLine(canvas, Offset(0, yFor(displayGoal)), Offset(size.width, yFor(displayGoal)), series.first.color.withValues(alpha: 0.55));
    }

    for (final s in series) {
      final points = [for (final e in s.entries) Offset(xFor(e.date), yFor(Units.displayValue(e.weightKg, unitPref)))];
      if (points.isEmpty) continue;

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      if (singleSeriesFill && points.length > 1) {
        final areaPath = Path.from(linePath)
          ..lineTo(points.last.dx, topPad + chartHeight)
          ..lineTo(points.first.dx, topPad + chartHeight)
          ..close();
        final shader = ui.Gradient.linear(
          Offset(0, topPad),
          Offset(0, topPad + chartHeight),
          [s.color.withValues(alpha: 0.30), s.color.withValues(alpha: 0.0)],
        );
        canvas.drawPath(areaPath, Paint()..shader = shader);
      }

      canvas.drawPath(
        linePath,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      if (singleSeriesFill) {
        final last = points.last;
        canvas.drawCircle(last, 6, Paint()..color = markerFill);
        canvas.drawCircle(last, 6, Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);
        canvas.drawCircle(last, 2.6, Paint()..color = s.color);
      } else {
        for (final p in points) {
          canvas.drawCircle(p, 3, Paint()..color = s.color);
        }
      }
    }

    _drawLabel(canvas, DateFormat('dd/MM').format(minDate), Offset(sidePad, size.height - bottomPad + 4), TextAlign.left);
    _drawLabel(canvas, DateFormat('dd/MM').format(maxDate), Offset(size.width - sidePad, size.height - bottomPad + 4), TextAlign.right);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dashWidth = 5.0;
    const gapWidth = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final totalLength = (end - start).distance;
    if (totalLength <= 0) return;
    var covered = 0.0;
    final direction = (end - start) / totalLength;
    while (covered < totalLength) {
      final segStart = start + direction * covered;
      final segEnd = start + direction * math.min(covered + dashWidth, totalLength);
      canvas.drawLine(segStart, segEnd, paint);
      covered += dashWidth + gapWidth;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset anchor, TextAlign align) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w500)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    double dx;
    switch (align) {
      case TextAlign.right:
        dx = anchor.dx - painter.width;
        break;
      case TextAlign.center:
        dx = anchor.dx - painter.width / 2;
        break;
      default:
        dx = anchor.dx;
    }
    painter.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.unitPref != unitPref || oldDelegate.goalWeightKg != goalWeightKg;
  }
}
