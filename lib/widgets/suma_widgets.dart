import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.padding = const EdgeInsets.all(14),
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
            blurRadius: 12,
            offset: const Offset(0, 4),
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

/// A circular avatar showing the person's uploaded photo when they have
/// one, falling back to their initial on a tinted background otherwise -
/// used on the profile card, the admin member list and the "Perfil" nav
/// destination.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  // When set, draws a role-colored ring around the avatar - verde-água for
  // the family admin, azul-bebê for everyone else (see AppColors.roleRing).
  // Left null wherever the ring would mean something else (e.g. Histórico's
  // member-picker chips already use a ring for *selection*).
  final bool? isAdmin;

  const UserAvatar({super.key, required this.avatarUrl, required this.name, this.radius = 20, this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = avatarUrl;
    final admin = isAdmin;
    // The ring is drawn *inside* the requested radius (like an Instagram
    // story ring), not added on top of it - growing the total footprint
    // broke tight layouts that size around `radius` exactly (the mobile
    // bottom nav's Perfil slot overflowed by ~9px once the ring padded
    // the widget larger than its parent expected).
    final ringWidth = admin == null ? 0.0 : (radius * 0.09 + 1.4).clamp(1.6, 3.0);
    final innerRadius = radius - ringWidth - (admin == null ? 0 : 1);

    final inner = (url != null && url.isNotEmpty)
        ? CircleAvatar(radius: innerRadius, backgroundColor: scheme.primary.withValues(alpha: 0.16), backgroundImage: NetworkImage(url))
        : CircleAvatar(
            radius: innerRadius,
            backgroundColor: scheme.primary.withValues(alpha: 0.16),
            child: Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: innerRadius * 0.72),
            ),
          );

    if (admin == null) return inner;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(radius * 2, radius * 2), painter: _RingPainter(color: AppColors.roleRing(admin), width: ringWidth)),
          inner,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double width;
  const _RingPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.color != color || oldDelegate.width != width;
}

/// A pill-shaped switcher with an animated sliding selected background - the
/// same "Login/Cadastro" tab pattern from the auth screens, reused wherever
/// a small set (2-3) of mutually-exclusive options needs picking without the
/// heavier stock [SegmentedButton] look.
class PillSwitcher<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  const PillSwitcher({super.key, required this.values, required this.labels, required this.selected, required this.onChanged}) : assert(values.length == labels.length);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(values[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: values[i] == selected ? (Theme.of(context).cardTheme.color ?? scheme.surface) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: values[i] == selected
                        ? [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: values[i] == selected ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: values[i] == selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          _RollingStatValue(
            text: value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: valueColor),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Renders a [StatTile]'s value as a rolling number when it has one (e.g.
/// "105.1 kg", "17") - starts at 0 and spins up to the real value at a
/// decelerating speed, like a slot-machine reel settling, and re-rolls from
/// whatever it's currently showing whenever the value actually changes.
/// Falls back to plain text for anything that isn't a leading number (e.g.
/// "—" when there's no data yet).
class _RollingStatValue extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _RollingStatValue({required this.text, required this.style});

  static final _numeric = RegExp(r'^(-?\d+(?:[.,]\d+)?)(.*)$');

  @override
  Widget build(BuildContext context) {
    final match = _numeric.firstMatch(text);
    if (match == null) return Text(text, style: style, overflow: TextOverflow.ellipsis);

    final numberText = match.group(1)!;
    final suffix = match.group(2)!;
    final normalized = numberText.replaceAll(',', '.');
    final target = double.tryParse(normalized);
    if (target == null) return Text(text, style: style, overflow: TextOverflow.ellipsis);
    final decimals = normalized.contains('.') ? normalized.split('.').last.length : 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutExpo,
      builder: (context, animated, _) => Text('${animated.toStringAsFixed(decimals)}$suffix', style: style, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Responsive grid of [StatTile]-like children: 2 columns on phones, more on
/// wider windows (see [Responsive.statColumns]).
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  // Overrides the desktop-width column count only (tablet/phone still fall
  // back to Responsive.statColumns) - Histórico uses this to fit every
  // summary tile in a single row instead of wrapping to a second line.
  final int? desktopColumns;
  const StatGrid({super.key, required this.children, this.desktopColumns});

  @override
  Widget build(BuildContext context) {
    final columns = desktopColumns != null && Responsive.isDesktop(context) ? desktopColumns! : Responsive.statColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      // A fixed height instead of childAspectRatio: with a ratio, wide
      // windows (more available width per tile once the column count caps
      // out) also made each tile *taller*, ballooning the empty space below
      // the icon/value/label instead of just widening it.
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        mainAxisExtent: 116,
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
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 3)],
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
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
  final ScrollController? controller;

  const ResponsiveBody({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(14, 6, 14, 84), this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
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
