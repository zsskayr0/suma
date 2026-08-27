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

/// The visible date/value window the chart is drawn against - kept as plain
/// doubles (epoch ms for dates) so it can be lerped smoothly frame by frame
/// during a zoom/expand transition, which `DateTime` can't do on its own.
class _ChartDomain {
  final double minDateMs;
  final double maxDateMs;
  final double minV;
  final double maxV;

  const _ChartDomain({required this.minDateMs, required this.maxDateMs, required this.minV, required this.maxV});

  static _ChartDomain lerp(_ChartDomain a, _ChartDomain b, double t) {
    return _ChartDomain(
      minDateMs: ui.lerpDouble(a.minDateMs, b.minDateMs, t)!,
      maxDateMs: ui.lerpDouble(a.maxDateMs, b.maxDateMs, t)!,
      minV: ui.lerpDouble(a.minV, b.minV, t)!,
      maxV: ui.lerpDouble(a.maxV, b.maxV, t)!,
    );
  }
}

/// The domain a given set of series naturally spans - the same window the
/// chart settles on once any zoom transition finishes.
_ChartDomain _domainFor(List<ChartSeries> nonEmpty, String unitPref, double? goalWeightKg) {
  DateTime minDate = nonEmpty.first.entries.first.date;
  DateTime maxDate = nonEmpty.first.entries.last.date;
  double minV = double.infinity;
  double maxV = double.negativeInfinity;
  for (final s in nonEmpty) {
    for (final e in s.entries) {
      if (e.date.isBefore(minDate)) minDate = e.date;
      if (e.date.isAfter(maxDate)) maxDate = e.date;
      final v = Units.displayValue(e.weightKg, unitPref);
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
  }
  final displayGoal = goalWeightKg != null ? Units.displayValue(goalWeightKg, unitPref) : null;
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
  return _ChartDomain(minDateMs: minDate.millisecondsSinceEpoch.toDouble(), maxDateMs: maxDate.millisecondsSinceEpoch.toDouble(), minV: minV, maxV: maxV);
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

class _WeightLineChartState extends State<WeightLineChart> with TickerProviderStateMixin {
  Offset? _touch;

  // Plays once, the very first time the chart appears - the line "draws
  // itself in". Never replayed after that.
  late final AnimationController _revealCtrl;

  // Plays whenever the plotted data actually changes (period filter,
  // member selection, a new entry) - the domain (date/value window) tweens
  // from where it was to where it needs to be, so the chart *zooms* into a
  // narrower range or *expands* into a wider one instead of vanishing and
  // redrawing from scratch.
  late final AnimationController _domainCtrl;
  _ChartDomain? _fromDomain;
  _ChartDomain? _toDomain;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..forward();
    _domainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  }

  @override
  void didUpdateWidget(covariant WeightLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameData(oldWidget.series, widget.series)) return;

    final newNonEmpty = widget.series.where((s) => s.entries.isNotEmpty).toList();
    final newPointCount = newNonEmpty.fold<int>(0, (n, s) => n + s.entries.length);
    if (newPointCount < 2) {
      // Filtered down to (almost) nothing to plot - the widget falls back
      // to its placeholder text below, nothing to zoom to.
      _toDomain = null;
      return;
    }

    final oldNonEmpty = oldWidget.series.where((s) => s.entries.isNotEmpty).toList();
    final oldPointCount = oldNonEmpty.fold<int>(0, (n, s) => n + s.entries.length);
    final newDomain = _domainFor(newNonEmpty, widget.unitPref, widget.goalWeightKg);
    _fromDomain = oldPointCount >= 2 ? _domainFor(oldNonEmpty, widget.unitPref, widget.goalWeightKg) : newDomain;
    _toDomain = newDomain;
    _domainCtrl.forward(from: 0);
  }

  bool _sameData(List<ChartSeries> a, List<ChartSeries> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label || a[i].entries.length != b[i].entries.length) return false;
      if (a[i].entries.isNotEmpty) {
        final ea = a[i].entries.last, eb = b[i].entries.last;
        if (ea.weightKg != eb.weightKg || ea.date != eb.date) return false;
      }
    }
    return true;
  }

  void _setTouch(Offset? p) {
    if (!mounted) return;
    if (p == null && _touch == null) return;
    setState(() => _touch = p);
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
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

    final restingDomain = _toDomain ?? _domainFor(nonEmpty, widget.unitPref, widget.goalWeightKg);

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
              child: AnimatedBuilder(
                animation: Listenable.merge([_revealCtrl, _domainCtrl]),
                builder: (context, _) {
                  final from = _fromDomain;
                  final domain = (from != null && _domainCtrl.value < 1.0)
                      ? _ChartDomain.lerp(from, restingDomain, Curves.easeOutCubic.transform(_domainCtrl.value))
                      : restingDomain;
                  return CustomPaint(
                    painter: _ChartPainter(
                      series: nonEmpty,
                      unitPref: widget.unitPref,
                      goalWeightKg: widget.goalWeightKg,
                      domain: domain,
                      gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
                      labelColor: scheme.onSurfaceVariant,
                      markerFill: scheme.surface,
                      singleSeriesFill: nonEmpty.length == 1,
                      touch: _touch,
                      tooltipBg: scheme.inverseSurface,
                      tooltipFg: scheme.onInverseSurface,
                      // Only plays on first mount (see initState/didUpdateWidget) -
                      // a period/member change zooms the domain instead of
                      // redrawing the line from scratch.
                      revealProgress: Curves.easeOutCubic.transform(_revealCtrl.value),
                    ),
                  );
                },
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
  final _ChartDomain domain;
  final Color gridColor;
  final Color labelColor;
  final Color markerFill;
  final bool singleSeriesFill;
  final Offset? touch;
  final Color tooltipBg;
  final Color tooltipFg;
  final double revealProgress;

  _ChartPainter({
    required this.series,
    required this.unitPref,
    required this.goalWeightKg,
    required this.domain,
    required this.gridColor,
    required this.labelColor,
    required this.markerFill,
    required this.singleSeriesFill,
    required this.touch,
    required this.tooltipBg,
    required this.tooltipFg,
    required this.revealProgress,
  });

  /// Cuts [path] off at the [t] (0..1) fraction of its total length -
  /// [end] is the exact point where the cut happened (null when [t] >= 1,
  /// meaning "just use the path as-is, all the way to its real end").
  ({Path path, Offset? end}) _truncatePath(Path path, double t) {
    if (t >= 1.0) return (path: path, end: null);
    if (t <= 0.0) return (path: Path(), end: null);
    final metrics = path.computeMetrics().toList();
    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final targetLength = totalLength * t;
    final result = Path();
    var consumed = 0.0;
    Offset? end;
    for (final metric in metrics) {
      if (consumed + metric.length < targetLength) {
        result.addPath(metric.extractPath(0, metric.length), Offset.zero);
        consumed += metric.length;
        continue;
      }
      final remaining = targetLength - consumed;
      result.addPath(metric.extractPath(0, remaining), Offset.zero);
      end = metric.getTangentForOffset(remaining)?.position;
      break;
    }
    return (path: result, end: end);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    const topPad = 26.0; // extra room for peak/trough bubbles
    const sidePad = 2.0;
    final chartHeight = size.height - bottomPad - topPad;
    final chartLeft = sidePad;
    final chartRight = size.width - sidePad;

    final minDateMs = domain.minDateMs;
    final totalMs = math.max(1.0, domain.maxDateMs - minDateMs);
    final minV = domain.minV;
    final maxV = domain.maxV;

    double xFor(DateTime d) => chartLeft + ((d.millisecondsSinceEpoch - minDateMs) / totalMs) * (chartRight - chartLeft);
    double yFor(double v) => topPad + chartHeight - ((v - minV) / (maxV - minV)) * chartHeight;
    DateTime dateForX(double x) {
      final fraction = ((x - chartLeft) / (chartRight - chartLeft)).clamp(0.0, 1.0);
      return DateTime.fromMillisecondsSinceEpoch((minDateMs + fraction * totalMs).round());
    }

    // Points outside the current (possibly mid-zoom) domain are clamped
    // into view instead of being cut - during a transition, a series can
    // briefly span more or less than what's visible, and this keeps the
    // line from ending in an abrupt, off-curve chop at the edges.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Horizontal gridlines.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topPad + chartHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Goal dashed line.
    final displayGoal = goalWeightKg != null ? Units.displayValue(goalWeightKg!, unitPref) : null;
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

      // The line "draws itself in" - reveal cuts both the stroke and the
      // fill off at the same point along the curve, so the gradient never
      // extends past where the line has actually reached yet. Only
      // relevant on first mount - revealProgress is pinned at 1 for every
      // repaint after that, so this is a no-op during a zoom transition.
      final revealed = _truncatePath(linePath, revealProgress);
      final revealedLine = revealed.path;
      final frontier = revealed.end ?? points.last;

      // Every series gets its own soft gradient fill under its line, not
      // just when it's the only one on the chart - comparing two family
      // members used to make both go flat/lineless the moment a second
      // person was added. Multiple overlapping fills read fine as long as
      // each is faint enough not to muddy the others.
      if (points.length > 1 && revealProgress > 0) {
        final fillAlpha = singleSeriesFill ? 0.30 : 0.16;
        final areaPath = Path.from(revealedLine)
          ..lineTo(frontier.dx, topPad + chartHeight)
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
        revealedLine,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Markers/labels pop in only once the line has (almost) finished
      // drawing, fading in over the last stretch of the reveal instead of
      // just appearing mid-animation.
      final markerOpacity = ((revealProgress - 0.85) / 0.15).clamp(0.0, 1.0);
      if (markerOpacity <= 0) continue;

      if (singleSeriesFill) {
        final last = points.last;
        canvas.drawCircle(last, 6, Paint()..color = markerFill.withValues(alpha: markerOpacity));
        canvas.drawCircle(last, 6, Paint()
          ..color = s.color.withValues(alpha: s.color.a * markerOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);
        canvas.drawCircle(last, 2.6, Paint()..color = s.color.withValues(alpha: s.color.a * markerOpacity));

        // Peak/trough labels - skip if either coincides with the last point
        // (already marked) or there are too few points to make it useful.
        if (s.entries.length > 2) {
          var maxIdx = 0, minIdx = 0;
          for (var i = 1; i < s.entries.length; i++) {
            if (s.entries[i].weightKg > s.entries[maxIdx].weightKg) maxIdx = i;
            if (s.entries[i].weightKg < s.entries[minIdx].weightKg) minIdx = i;
          }
          if (maxIdx != s.entries.length - 1) {
            _drawValueBubble(canvas, points[maxIdx], Units.format(s.entries[maxIdx].weightKg, unitPref), s.color, above: true, opacity: markerOpacity, canvasWidth: size.width);
          }
          if (minIdx != s.entries.length - 1 && minIdx != maxIdx) {
            _drawValueBubble(canvas, points[minIdx], Units.format(s.entries[minIdx].weightKg, unitPref), s.color, above: false, opacity: markerOpacity, canvasWidth: size.width);
          }
        }
      } else {
        for (final p in points) {
          canvas.drawCircle(p, 3, Paint()..color = s.color.withValues(alpha: s.color.a * markerOpacity));
        }
      }
    }

    canvas.restore();

    _drawLabel(canvas, DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(domain.minDateMs.round())), Offset(sidePad, size.height - bottomPad + 4), TextAlign.left);
    _drawLabel(canvas, DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(domain.maxDateMs.round())), Offset(size.width - sidePad, size.height - bottomPad + 4), TextAlign.right);

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

  void _drawValueBubble(Canvas canvas, Offset point, String text, Color color, {required bool above, double opacity = 1.0, required double canvasWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: opacity))),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    const paddingH = 6.0, paddingV = 3.0;
    final bubbleWidth = painter.width + paddingH * 2;
    final bubbleHeight = painter.height + paddingV * 2;
    final dy = above ? point.dy - bubbleHeight - 8 : point.dy + 8;
    // Clamped horizontally - a peak/trough very often lands right at one
    // edge of a short window (the min/max of the last 30 days is commonly
    // the oldest or newest point in it), and without this the bubble's text
    // got clipped clean off-canvas whenever that happened.
    final left = (point.dx - bubbleWidth / 2).clamp(0.0, math.max(0.0, canvasWidth - bubbleWidth)).toDouble();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, dy, bubbleWidth, bubbleHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: color.a * opacity));
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
        oldDelegate.touch != touch ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.domain != domain;
  }
}
