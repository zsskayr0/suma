import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'suma_mark.dart';
import 'suma_widgets.dart';

const _railWidth = 248.0;

class SidebarEntry {
  final String label;
  // Same plain Material glyphs as the mobile bottom nav (outline when
  // unselected, filled when selected) - lighter-weight than the Heroicons
  // tried before, and keeps the two nav styles visually consistent.
  final IconData? icon;
  final IconData? selectedIcon;
  // When set, renders this SVG asset instead of [icon]/[selectedIcon] - see
  // BottomNavEntry.svgAsset, used the same way for "Usuários" here too.
  final String? svgAsset;
  const SidebarEntry({required this.label, this.icon, this.selectedIcon, this.svgAsset});
}

/// Desktop nav rail - full-width rows (icon + label, written out in full)
/// instead of the icon-only strip tried earlier this round, back to the
/// same flat blur-glass recipe as the bottom nav/glass sheets (translucent
/// surface + backdrop blur + a thin border). The selected row is marked with
/// an outline in Suma's own brand color rather than a hover flyout - there's
/// room for labels now, so a tooltip-on-hover to explain an icon isn't
/// needed anymore.
class DesktopSidebar extends StatelessWidget {
  final List<SidebarEntry> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final String? avatarUrl;
  final String userName;
  final String? userEmail;
  final bool userIsAdmin;

  const DesktopSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
    required this.avatarUrl,
    required this.userName,
    required this.userEmail,
    required this.userIsAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The last item is always "Perfil" (see HomeScreen) - it lives only in
    // the footer avatar below, not repeated in the main list.
    final mainItems = items.sublist(0, items.length - 1);
    final profileIndex = items.length - 1;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: _railWidth,
          decoration: BoxDecoration(
            color: (dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.86),
            border: Border(right: BorderSide(color: scheme.outlineVariant.withValues(alpha: dark ? 0.3 : 0.5))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const SumaMark(size: 26),
                    const SizedBox(width: 10),
                    Text('Suma', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AddButton(onTap: onAdd),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    for (var i = 0; i < mainItems.length; i++)
                      _SidebarItem(entry: mainItems[i], selected: i == selectedIndex, onTap: () => onSelect(i)),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _UserFooter(avatarUrl: avatarUrl, name: userName, email: userEmail, isAdmin: userIsAdmin, onTap: () => onSelect(profileIndex)),
              const SizedBox(height: 10),
            ],
          ),
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
    return Material(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text('Novo registro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final SidebarEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    // Filled when selected, outline otherwise - same as the mobile bottom
    // nav's icon/selectedIcon pair. A handful of entries (Usuários) use a
    // custom SVG glyph instead, tinted the same way.
    final iconWidget = entry.svgAsset != null
        ? SvgPicture.asset(entry.svgAsset!, width: 20, height: 20, colorFilter: ColorFilter.mode(color, BlendMode.srcIn))
        : Icon(selected ? entry.selectedIcon : entry.icon, size: 20, color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? scheme.primary.withValues(alpha: 0.10) : Colors.transparent,
          border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 1.4),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      entry.label,
                      style: TextStyle(fontSize: 14.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? scheme.primary : scheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String? email;
  final bool isAdmin;
  final VoidCallback onTap;

  const _UserFooter({required this.avatarUrl, required this.name, required this.email, required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                UserAvatar(avatarUrl: avatarUrl, name: name, radius: 17, isAdmin: isAdmin),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      if (email != null && email!.isNotEmpty)
                        Text(email!, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
