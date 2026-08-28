import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The 30d/90d/6m/1a/Tudo period picker used by Histórico and the pet
/// history screen - separate glass pills (each with its own blur, same
/// recipe as the floating bottom nav) instead of one shared bar, centered
/// as a row.
class PeriodFilter extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;
  const PeriodFilter({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Compact suffixes on mobile so all five chips fit on one line without
    // needing a horizontal scroll to reach "Tudo" - desktop has the room to
    // spell them out, so it keeps the full labels.
    final compact = !Responsive.isDesktop(context);
    final options = <String, int?>{
      compact ? '30d' : '30 dias': 30,
      compact ? '90d' : '90 dias': 90,
      compact ? '6m' : '6 meses': 182,
      compact ? '1a' : '1 ano': 365,
      'Tudo': null,
    };
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options.entries) ...[
              PeriodChip(label: o.key, selected: selected == o.value, onTap: () => onChanged(o.value)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const PeriodChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              // Not easeOutBack here - "back" curves briefly overshoot past
              // their target (that's what makes them bounce), and this
              // container's boxShadow animates between a real shadow and
              // none. An overshot progress value made BoxShadow.lerp compute
              // a momentarily *negative* blurRadius, which crashes with
              // "Text shadow blur radius should be non-negative" - Flutter
              // reuses that assertion for BoxShadow too, since it's built on
              // the same Shadow class as actual text shadows. The bounce
              // itself still reads fine on the AnimatedScale below, which
              // only ever animates between two small positive numbers.
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? scheme.primary : (dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: selected ? Colors.transparent : scheme.outlineVariant.withValues(alpha: dark ? 0.3 : 0.5)),
                boxShadow: selected ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                scale: selected ? 1.05 : 1.0,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: selected ? Colors.white : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
