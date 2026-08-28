import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact "estilizado" time picker - a small analog clock face (its
/// hands animate smoothly to the selected time) above two iOS/MIUI-style
/// scrolling number wheels. Built to replace two side-by-side [StepperField]
/// cards for Hora/Minuto, which - designed for one full-width field at a
/// time - overflowed when squeezed into half-width columns.
class SumaTimePicker extends StatelessWidget {
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const SumaTimePicker({
    super.key,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _AnalogClockFace(hour: hour, minute: minute, size: 72),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NumberWheel(value: hour, values: List.generate(24, (i) => i), onChanged: onHourChanged),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
                ),
                _NumberWheel(value: minute, values: List.generate(12, (i) => i * 5), onChanged: onMinuteChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One scrolling wheel of two-digit values (à la UIPickerView) - the
/// centered item reads large/bold/accented, neighbors fade out above and
/// below.
class _NumberWheel extends StatefulWidget {
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;
  const _NumberWheel({required this.value, required this.values, required this.onChanged});

  @override
  State<_NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<_NumberWheel> {
  late final FixedExtentScrollController _ctrl = FixedExtentScrollController(initialItem: widget.values.indexOf(widget.value).clamp(0, widget.values.length - 1));

  @override
  void didUpdateWidget(covariant _NumberWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the wheel in sync if the value changes from outside (e.g. the
    // other wheel's onChanged also nudges this one - it doesn't today, but
    // this is what would keep it honest if that ever changes).
    final target = widget.values.indexOf(widget.value);
    if (target >= 0 && _ctrl.hasClients && _ctrl.selectedItem != target) {
      _ctrl.animateToItem(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      child: ListWheelScrollView.useDelegate(
        controller: _ctrl,
        itemExtent: 40,
        diameterRatio: 1.35,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => widget.onChanged(widget.values[i]),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.values.length,
          builder: (context, i) {
            final selected = widget.values[i] == widget.value;
            return Center(
              child: Text(
                widget.values[i].toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: selected ? 26 : 17,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Purely decorative analog face above the wheels - hour/minute hands
/// rotate to match the picked time, animating smoothly between changes.
class _AnalogClockFace extends StatelessWidget {
  final int hour;
  final int minute;
  final double size;
  const _AnalogClockFace({required this.hour, required this.minute, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A single tween of "minutes since 12:00" instead of two separate
    // angle tweens - TweenAnimationBuilder animates from whatever it's
    // currently showing to this new `end` any time it changes (that's the
    // whole point of the widget - `begin` only matters on first mount), so
    // both hands glide together in one smooth motion instead of drifting
    // out of sync.
    final totalMinutes = (hour % 12) * 60.0 + minute;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: totalMinutes, end: totalMinutes),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, animatedMinutes, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ClockFacePainter(
            hourAngle: (animatedMinutes / 60) * (math.pi / 6),
            minuteAngle: (animatedMinutes % 60) * (math.pi / 30),
            faceColor: scheme.primary.withValues(alpha: 0.08),
            tickColor: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            handColor: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ClockFacePainter extends CustomPainter {
  final double hourAngle;
  final double minuteAngle;
  final Color faceColor;
  final Color tickColor;
  final Color handColor;

  const _ClockFacePainter({
    required this.hourAngle,
    required this.minuteAngle,
    required this.faceColor,
    required this.tickColor,
    required this.handColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = faceColor);

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * (math.pi / 6);
      final outer = center + Offset(math.sin(angle), -math.cos(angle)) * (radius - 3);
      final inner = center + Offset(math.sin(angle), -math.cos(angle)) * (radius - (i % 3 == 0 ? 9 : 6));
      canvas.drawLine(inner, outer, tickPaint);
    }

    final hourHand = center + Offset(math.sin(hourAngle), -math.cos(hourAngle)) * (radius * 0.48);
    final minuteHand = center + Offset(math.sin(minuteAngle), -math.cos(minuteAngle)) * (radius * 0.72);
    canvas.drawLine(
      center,
      hourHand,
      Paint()
        ..color = handColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center,
      minuteHand,
      Paint()
        ..color = handColor.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 2.6, Paint()..color = handColor);
  }

  @override
  bool shouldRepaint(covariant _ClockFacePainter oldDelegate) {
    return oldDelegate.hourAngle != hourAngle || oldDelegate.minuteAngle != minuteAngle;
  }
}
