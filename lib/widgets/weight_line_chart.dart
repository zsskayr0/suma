import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/entry.dart';
import '../utils/units.dart';

/// A smooth, gradient-filled weight trend chart drawn entirely with
/// [CustomPainter] (no charting package dependency). Handles empty/short
/// series gracefully and optionally draws a dashed goal-weight line.
class WeightLineChart extends StatelessWidget {
  final List<WeightEntry> entries; // must be sorted ascending by date
  final String unitPref;
  final double? goalWeightKg;
  final Color lineColor;
  final double height;

  const WeightLineChart({
    super.key,
    required this.entries,
    required this.unitPref,
    this.goalWeightKg,
    required this.lineColor,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (entries.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            entries.isEmpty ? 'Sem registros neste período' : 'Registre mais um dia para ver a evolução',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          entries: entries,
          unitPref: unitPref,
          goalWeightKg: goalWeightKg,
          lineColor: lineColor,
          gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
          labelColor: scheme.onSurfaceVariant,
          markerFill: scheme.surface,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<WeightEntry> entries;
  final String unitPref;
  final double? goalWeightKg;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color markerFill;

  _ChartPainter({
    required this.entries,
    required this.unitPref,
    required this.goalWeightKg,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.markerFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    const topPad = 14.0;
    const sidePad = 2.0;
    final chartWidth = size.width - sidePad * 2;
    final chartHeight = size.height - bottomPad - topPad;

    final values = entries.map((e) => Units.displayValue(e.weightKg, unitPref)).toList();
    double minV = values.reduce(math.min);
    double maxV = values.reduce(math.max);
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

    double xFor(int i) => sidePad + (entries.length == 1 ? chartWidth / 2 : (i / (entries.length - 1)) * chartWidth);
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
      _drawDashedLine(canvas, Offset(0, yFor(displayGoal)), Offset(size.width, yFor(displayGoal)), lineColor.withValues(alpha: 0.55));
    }

    final points = [for (var i = 0; i < entries.length; i++) Offset(xFor(i), yFor(values[i]))];

    // Smooth line through the points.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Gradient fill under the line.
    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, topPad + chartHeight)
      ..lineTo(points.first.dx, topPad + chartHeight)
      ..close();
    final shader = ui.Gradient.linear(
      Offset(0, topPad),
      Offset(0, topPad + chartHeight),
      [lineColor.withValues(alpha: 0.30), lineColor.withValues(alpha: 0.0)],
    );
    canvas.drawPath(areaPath, Paint()..shader = shader);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Marker on the latest point.
    final last = points.last;
    canvas.drawCircle(last, 6, Paint()..color = markerFill);
    canvas.drawCircle(last, 6, Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4);
    canvas.drawCircle(last, 2.6, Paint()..color = lineColor);

    // Date range labels.
    _drawLabel(canvas, DateFormat('dd/MM').format(entries.first.date), Offset(sidePad, size.height - bottomPad + 4), TextAlign.left);
    _drawLabel(canvas, DateFormat('dd/MM').format(entries.last.date), Offset(size.width - sidePad, size.height - bottomPad + 4), TextAlign.right);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dashWidth = 5.0;
    const gapWidth = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final totalLength = (end - start).distance;
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
    return oldDelegate.entries != entries ||
        oldDelegate.unitPref != unitPref ||
        oldDelegate.goalWeightKg != goalWeightKg ||
        oldDelegate.lineColor != lineColor;
  }
}
