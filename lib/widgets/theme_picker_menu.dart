import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'suma_glass_sheet.dart';

/// Suma's "Tema" picker - a big sun that morphs into a moon (and back) as
/// you switch between Claro/Escuro, "Automático" resolving to whichever the
/// system currently is. Tapping a mode applies it live right away -
/// [onPreview] fires immediately so the app's real theme changes behind the
/// sheet, not just the little icon - but the sheet itself stays open until
/// "Confirmar" (or a tap outside), so you can flip between options and
/// compare before settling. [onPreview] should be cheap (see
/// AppState.themePreviewOverride) - it fires on every tap, and a heavy
/// handler here stutters against the sheet's own live blur animation.
Future<String?> showThemePickerMenu(BuildContext context, {required String selected, required ValueChanged<String> onPreview}) {
  return showSumaGlassSheet<String>(
    context,
    maxWidth: 340,
    builder: (ctx) => _ThemePickerBody(initial: selected, onPreview: onPreview),
  );
}

const _sunColor = Color(0xFFFFC94A);
const _moonColor = Color(0xFFD7DCE8);

class _ThemePickerBody extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onPreview;
  const _ThemePickerBody({required this.initial, required this.onPreview});

  @override
  State<_ThemePickerBody> createState() => _ThemePickerBodyState();
}

class _ThemePickerBodyState extends State<_ThemePickerBody> with SingleTickerProviderStateMixin {
  late String _pending = widget.initial;
  late final AnimationController _ctrl;

  double _targetFor(String mode) {
    if (mode == 'dark') return 1;
    if (mode == 'light') return 0;
    // "Automático" previews whatever the system is showing right now.
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark ? 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    // Deferred to the first frame - _targetFor('system') needs an inherited
    // MediaQuery, which isn't available yet inside initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ctrl.value = _targetFor(_pending);
    });
  }

  void _select(String mode) {
    if (mode == _pending) return;
    setState(() => _pending = mode);
    _ctrl.animateTo(_targetFor(mode), curve: Curves.easeInOutCubic);
    // Applies right away so the *real* app theme changes behind the sheet,
    // not just the preview icon - the sheet itself only closes on
    // "Confirmar" (or tapping outside), so you can flip between options and
    // actually see each one before settling.
    widget.onPreview(mode);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tema', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => SunMoonIcon(t: _ctrl.value, size: 96),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _ModeButton(icon: Icons.smartphone_rounded, label: 'Automático', selected: _pending == 'system', onTap: () => _select('system'))),
              const SizedBox(width: 8),
              Expanded(child: _ModeButton(icon: Icons.light_mode_rounded, label: 'Claro', selected: _pending == 'light', onTap: () => _select('light'))),
              const SizedBox(width: 8),
              Expanded(child: _ModeButton(icon: Icons.dark_mode_rounded, label: 'Escuro', selected: _pending == 'dark', onTap: () => _select('dark'))),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_pending),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sun that morphs into a crescent moon as [t] goes 0 -> 1: the rays fade
/// and shrink, the body cools from amber to pale silver, a second circle
/// "bites" a crescent out of it (true alpha cutout via BlendMode.clear, not
/// just an overlay - looks right regardless of what's behind it), and a
/// few stars fade in around it. Fully driven by [t], so it scrubs smoothly
/// with whatever curve/controller drives it - no internal animation state.
class SunMoonIcon extends StatelessWidget {
  final double t; // 0 = sun (light), 1 = moon (dark)
  final double size;
  const SunMoonIcon({super.key, required this.t, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _SunMoonPainter(t)));
  }
}

class _SunMoonPainter extends CustomPainter {
  final double t;
  const _SunMoonPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyRadius = size.width * 0.28;
    final color = Color.lerp(_sunColor, _moonColor, t)!;

    // Soft glow behind the body - warm for the sun, cool and fainter for
    // the moon.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.30 * (1 - t * 0.4))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, bodyRadius * 1.7, glowPaint);

    // Rays - shrink and fade out as the sun becomes a moon.
    final rayOpacity = (1 - t * 1.4).clamp(0.0, 1.0);
    if (rayOpacity > 0) {
      final rayPaint = Paint()
        ..color = color.withValues(alpha: rayOpacity)
        ..strokeWidth = size.width * 0.045
        ..strokeCap = StrokeCap.round;
      final rayInner = bodyRadius + size.width * 0.08;
      final rayOuter = rayInner + size.width * 0.11 * rayOpacity;
      for (var i = 0; i < 8; i++) {
        final angle = (i / 8) * 2 * math.pi;
        final from = center + Offset(math.cos(angle), math.sin(angle)) * rayInner;
        final to = center + Offset(math.cos(angle), math.sin(angle)) * rayOuter;
        canvas.drawLine(from, to, rayPaint);
      }
    }

    // Body, with a crescent "bitten" out of it as t increases - a real
    // alpha cutout (BlendMode.clear inside a layer) rather than an overlay
    // circle, so it looks correct regardless of what's behind this icon.
    canvas.saveLayer(Rect.fromCircle(center: center, radius: bodyRadius + 2), Paint());
    canvas.drawCircle(center, bodyRadius, Paint()..color = color);
    if (t > 0) {
      final biteCenter = center + Offset.lerp(Offset(bodyRadius * 1.6, 0), Offset(bodyRadius * 0.62, -bodyRadius * 0.32), t)!;
      canvas.drawCircle(biteCenter, bodyRadius * 0.92, Paint()..blendMode = BlendMode.clear);
    }
    canvas.restore();

    // A few stars, fading in as it becomes night.
    if (t > 0.15) {
      final starOpacity = ((t - 0.15) / 0.85).clamp(0.0, 1.0);
      final starPaint = Paint()..color = _moonColor.withValues(alpha: starOpacity);
      const stars = [Offset(0.16, 0.22), Offset(0.82, 0.18), Offset(0.86, 0.62), Offset(0.14, 0.68)];
      const starSizes = [2.4, 1.8, 2.1, 1.6];
      for (var i = 0; i < stars.length; i++) {
        canvas.drawCircle(Offset(stars[i].dx * size.width, stars[i].dy * size.height), starSizes[i], starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SunMoonPainter oldDelegate) => oldDelegate.t != t;
}
