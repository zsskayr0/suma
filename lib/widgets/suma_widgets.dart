import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Rounded, softly-shadowed card used everywhere instead of the default
/// Material [Card] elevation, matching the flat "iOS grouped list" look.
class SumaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const SumaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: content,
      ),
    );
  }
}

/// Small-caps-ish section title used above groups of cards, e.g. "PREFERÊNCIAS".
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 8)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

/// A colored icon+value+label tile used in stat grids (variação, gordura,
/// hidratação, ...). [trend] paints the value green/red when non-null.
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool? trendPositive;

  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.trendPositive,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color valueColor = scheme.onSurface;
    if (trendPositive == true) valueColor = AppColors.positive;
    if (trendPositive == false) valueColor = AppColors.negative;

    return SumaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Responsive grid of [StatTile]-like children: 2 columns on phones, more on
/// wider windows (see [Responsive.statColumns]).
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.statColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, i) => children[i],
    );
  }
}

/// A pill-shaped +/- stepper with a large centered value, used for weight
/// input on the onboarding wizard and in Ajustes. The value is always shown
/// in whatever unit the caller passes in ([value]/[step]/[min]/[max] are all
/// in that same unit) - callers handle kg/lb conversion themselves.
///
/// The number itself is directly editable (tap it to type an exact value)
/// and the +/- buttons auto-repeat, accelerating, while held down.
class StepperField extends StatefulWidget {
  final String label;
  final double value;
  final String unit;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final int decimals;

  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.step = 0.1,
    this.min = 0,
    this.max = 999,
    this.decimals = 1,
  });

  @override
  State<StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<StepperField> {
  String _format(double v) => v.toStringAsFixed(widget.decimals);

  void _apply(double v) => widget.onChanged(v.clamp(widget.min, widget.max).toDouble());

  Future<void> _editDirectly() async {
    final controller = TextEditingController(text: _format(widget.value));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: widget.unit),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('OK')),
        ],
      ),
    );
    if (result == null) return;
    final parsed = double.tryParse(result.trim().replaceAll(',', '.'));
    if (parsed != null) _apply(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RepeatIconButton(icon: Icons.remove_rounded, onStep: () => _apply(widget.value - widget.step)),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _editDirectly,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: _format(widget.value), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                        TextSpan(text: ' ${widget.unit}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
              _RepeatIconButton(icon: Icons.add_rounded, onStep: () => _apply(widget.value + widget.step)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Round icon button that fires [onStep] once on tap, then keeps firing it
/// on a timer - accelerating - for as long as it's held down.
class _RepeatIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onStep;
  const _RepeatIconButton({required this.icon, required this.onStep});

  @override
  State<_RepeatIconButton> createState() => _RepeatIconButtonState();
}

class _RepeatIconButtonState extends State<_RepeatIconButton> {
  Timer? _timer;
  int _ticks = 0;

  void _start() {
    widget.onStep();
    _ticks = 0;
    _scheduleNext();
  }

  void _scheduleNext() {
    // Starts slow (~450ms before the first repeat) then accelerates down to
    // ~40ms between steps, so a long hold feels like it's speeding up.
    final delayMs = _ticks == 0 ? 450 : (140 - _ticks * 8).clamp(40, 140);
    _timer = Timer(Duration(milliseconds: delayMs), () {
      widget.onStep();
      _ticks++;
      _scheduleNext();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: Material(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(widget.icon, color: scheme.primary, size: 22),
        ),
      ),
    );
  }
}

/// Thin rounded progress bar with a label row (used for goal-weight
/// progress).
class GoalProgressBar extends StatelessWidget {
  final double progress; // 0..1
  final Color color;

  const GoalProgressBar({super.key, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0).toDouble(),
        minHeight: 10,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// A colored rounded pill with text, used for the BMI category and role
/// badges.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const Pill({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Centers page content and caps its width on wide desktop windows so the
/// UI reads as "more desktop, less stretched-phone" per Suma's design goals.
/// Always scrollable - callers can build a plain, non-scrolling `Column` and
/// still be safe if the content ends up taller than the viewport.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ResponsiveBody({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96)});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
