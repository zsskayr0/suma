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
/// full "dashboard" look (gradient fill, peak/trough labels, end marker);
/// two or more get a legend and plain lines instead, so the comparison
/// stays readable. Drag (or tap) across it to see the date/weight at that
/// point.
class WeightLineChart extends StatefulWidget {
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
  State<WeightLineChart> createState() => _WeightLineChartState();
}

class _WeightLineChartState extends State<WeightLineChart> {
  Offset? _touch;

  void _setTouch(Offset? p) {
    if (!mounted) return;
    if (p == null && _touch == null) return;
    setState(() => _touch = p);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nonEmpty = widget.series.where((s) => s.entries.isNotEmpty).toList();
    final totalPoints = nonEmpty.fold<int>(0, (sum, s) => sum + s.entries.length);

    if (nonEmpty.isEmpty || totalPoints < 2) {
      return SizedBox(
        height: widget.height,
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
        MouseRegion(
          // Desktop/trackpad/pen: follow the pointer live without needing to
          // click-drag first, like the reference dashboards. Touch devices
          // still rely on the drag/tap handlers below (hover events aren't
          // fired for touch input, so there's no double-handling).
          onHover: (e) => _setTouch(e.localPosition),
          onExit: (_) => _setTouch(null),
          child: GestureDetector(
            onHorizontalDragStart: (d) => _setTouch(d.localPosition),
            onHorizontalDragUpdate: (d) => _setTouch(d.localPosition),
            onHorizontalDragEnd: (_) => _setTouch(null),
            onHorizontalDragCancel: () => _setTouch(null),
            onTapDown: (d) => _setTouch(d.localPosition),
            onTapCancel: () => _setTouch(null),
            onTapUp: (_) => Future.delayed(const Duration(seconds: 2), () => _setTouch(null)),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(
                  series: nonEmpty,
                  unitPref: widget.unitPref,
                  goalWeightKg: widget.goalWeightKg,
                  gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
                  labelColor: scheme.onSurfaceVariant,
                  markerFill: scheme.surface,
                  singleSeriesFill: nonEmpty.length == 1,
                  touch: _touch,
                  tooltipBg: scheme.inverseSurface,
                  tooltipFg: scheme.onInverseSurface,
                ),
              ),
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
  final Offset? touch;
  final Color tooltipBg;
  final Color tooltipFg;

  _ChartPainter({
    required this.series,
    required this.unitPref,
    required this.goalWeightKg,
    required this.gridColor,
    required this.labelColor,
    required this.markerFill,
    required this.singleSeriesFill,
    required this.touch,
    required this.tooltipBg,
    required this.tooltipFg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    const topPad = 26.0; // extra room for peak/trough bubbles
    const sidePad = 2.0;
    final chartHeight = size.height - bottomPad - topPad;
    final chartLeft = sidePad;
    final chartRight = size.width - sidePad;

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
    maxV += span * 0.22; // a bit more headroom on top for peak bubbles

    final totalDays = math.max(1, maxDate.difference(minDate).inDays);

    double xFor(DateTime d) => chartLeft + (d.difference(minDate).inDays / totalDays) * (chartRight - chartLeft);
    double yFor(double v) => topPad + chartHeight - ((v - minV) / (maxV - minV)) * chartHeight;
    DateTime dateForX(double x) {
      final fraction = ((x - chartLeft) / (chartRight - chartLeft)).clamp(0.0, 1.0);
      return minDate.add(Duration(days: (fraction * totalDays).round()));
    }

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

      // Every series gets its own soft gradient fill under its line, not
      // just when it's the only one on the chart - comparing two family
      // members used to make both go flat/lineless the moment a second
      // person was added. Multiple overlapping fills read fine as long as
      // each is faint enough not to muddy the others.
      if (points.length > 1) {
        final fillAlpha = singleSeriesFill ? 0.30 : 0.16;
        final areaPath = Path.from(linePath)
          ..lineTo(points.last.dx, topPad + chartHeight)
          ..lineTo(points.first.dx, topPad + chartHeight)
          ..close();
        final shader = ui.Gradient.linear(
          Offset(0, topPad),
          Offset(0, topPad + chartHeight),
          [s.color.withValues(alpha: fillAlpha), s.color.withValues(alpha: 0.0)],
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

        // Peak/trough labels - skip if either coincides with the last point
        // (already marked) or there are too few points to make it useful.
        if (s.entries.length > 2) {
          var maxIdx = 0, minIdx = 0;
          for (var i = 1; i < s.entries.length; i++) {
            if (s.entries[i].weightKg > s.entries[maxIdx].weightKg) maxIdx = i;
            if (s.entries[i].weightKg < s.entries[minIdx].weightKg) minIdx = i;
          }
          if (maxIdx != s.entries.length - 1) {
            _drawValueBubble(canvas, points[maxIdx], Units.format(s.entries[maxIdx].weightKg, unitPref), s.color, above: true);
          }
          if (minIdx != s.entries.length - 1 && minIdx != maxIdx) {
            _drawValueBubble(canvas, points[minIdx], Units.format(s.entries[minIdx].weightKg, unitPref), s.color, above: false);
          }
        }
      } else {
        for (final p in points) {
          canvas.drawCircle(p, 3, Paint()..color = s.color);
        }
      }
    }

    _drawLabel(canvas, DateFormat('dd/MM/yyyy').format(minDate), Offset(sidePad, size.height - bottomPad + 4), TextAlign.left);
    _drawLabel(canvas, DateFormat('dd/MM').format(maxDate), Offset(size.width - sidePad, size.height - bottomPad + 4), TextAlign.right);

    // Touch/drag tooltip: nearest entry per series to the touched date.
    final t = touch;
    if (t != null) {
      final touchX = t.dx.clamp(chartLeft, chartRight);
      final virtualDate = dateForX(touchX);
      canvas.drawLine(Offset(touchX, topPad), Offset(touchX, topPad + chartHeight), Paint()
        ..color = labelColor.withValues(alpha: 0.4)
        ..strokeWidth = 1);

      final lines = <String>[];
      DateTime? nearestDate;
      for (final s in series) {
        if (s.entries.isEmpty) continue;
        var nearest = s.entries.first;
        var bestDiff = (nearest.date.difference(virtualDate)).inDays.abs();
        for (final e in s.entries) {
          final diff = (e.date.difference(virtualDate)).inDays.abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            nearest = e;
          }
        }
        nearestDate ??= nearest.date;
        final point = Offset(xFor(nearest.date), yFor(Units.displayValue(nearest.weightKg, unitPref)));
        canvas.drawCircle(point, 4.5, Paint()..color = markerFill);
        canvas.drawCircle(point, 4.5, Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        lines.add(series.length > 1 ? '${s.label}: ${Units.formatWithUnit(nearest.weightKg, unitPref)}' : Units.formatWithUnit(nearest.weightKg, unitPref));
      }
      if (nearestDate != null) {
        lines.insert(0, DateFormat('dd/MM/yyyy').format(nearestDate));
        _drawTooltip(canvas, size, touchX, lines);
      }
    }
  }

  void _drawValueBubble(Canvas canvas, Offset point, String text, Color color, {required bool above}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    const paddingH = 6.0, paddingV = 3.0;
    final bubbleWidth = painter.width + paddingH * 2;
    final bubbleHeight = painter.height + paddingV * 2;
    final dy = above ? point.dy - bubbleHeight - 8 : point.dy + 8;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(point.dx - bubbleWidth / 2, dy, bubbleWidth, bubbleHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    painter.paint(canvas, Offset(rect.left + paddingH, rect.top + paddingV));
  }

  void _drawTooltip(Canvas canvas, Size size, double touchX, List<String> lines) {
    final painters = [
      for (var i = 0; i < lines.length; i++)
        TextPainter(
          text: TextSpan(text: lines[i], style: TextStyle(fontSize: 11, color: tooltipFg, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500)),
          textDirection: ui.TextDirection.ltr,
        )..layout(),
    ];
    const paddingH = 10.0, paddingV = 8.0, lineGap = 2.0;
    final boxWidth = painters.map((p) => p.width).fold(0.0, math.max) + paddingH * 2;
    final boxHeight = painters.fold(0.0, (sum, p) => sum + p.height + lineGap) + paddingV * 2 - lineGap;

    var left = touchX - boxWidth / 2;
    left = left.clamp(0.0, math.max(0.0, size.width - boxWidth));
    const top = 0.0;

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, boxWidth, boxHeight), const Radius.circular(10));
    canvas.drawRRect(rect, Paint()..color = tooltipBg);

    var dy = top + paddingV;
    for (final p in painters) {
      p.paint(canvas, Offset(left + paddingH, dy));
      dy += p.height + lineGap;
    }
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
    return oldDelegate.series != series ||
        oldDelegate.unitPref != unitPref ||
        oldDelegate.goalWeightKg != goalWeightKg ||
        oldDelegate.touch != touch;
  }
}
