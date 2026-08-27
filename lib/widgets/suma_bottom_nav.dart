import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BottomNavEntry {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const BottomNavEntry({required this.label, required this.icon, required this.selectedIcon});
}

/// Floating pill-shaped bottom nav (mobile only) - a raised circular "+" sits
/// centered above the bar as the single, universal "novo registro" entry
/// point, replacing the old per-screen appBar icon (Hoje) and FAB
/// (Histórico). A light glass touch (faint blur + translucency, thin border,
/// soft shadow to lift it off the page) on top of the same flat-card look
/// used everywhere else - not a full frosted-glass panel, just enough to
/// read as floating.
class SumaBottomNav extends StatelessWidget {
  final List<BottomNavEntry> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  const SumaBottomNav({super.key, required this.items, required this.selectedIndex, required this.onSelect, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final indexed = items.asMap().entries.toList();
    final half = (indexed.length / 2).ceil();
    final left = indexed.sublist(0, half);
    final right = indexed.sublist(half);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: (dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: dark ? 0.3 : 0.5)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.4 : 0.10), blurRadius: 24, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(
                    children: [
                      for (final e in left) Expanded(child: _NavButton(entry: e.value, selected: e.key == selectedIndex, onTap: () => onSelect(e.key))),
                      const SizedBox(width: 60), // room for the raised + button
                      for (final e in right) Expanded(child: _NavButton(entry: e.value, selected: e.key == selectedIndex, onTap: () => onSelect(e.key))),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(top: -14, child: _AddButton(onTap: onAdd)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final BottomNavEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(selected ? entry.selectedIcon : entry.icon, key: ValueKey(selected), color: color, size: 22),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
              child: Text(entry.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 4),
            boxShadow: [
              BoxShadow(color: scheme.primary.withValues(alpha: 0.38), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
