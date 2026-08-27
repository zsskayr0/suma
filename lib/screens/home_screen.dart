import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/responsive.dart';
import '../widgets/suma_bottom_nav.dart';
import '../widgets/suma_mark.dart';
import 'admin_users_screen.dart';
import 'dashboard_screen.dart';
import 'entry_form_sheet.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Shell shown once someone is logged in. On phone-width windows this is a
/// floating pill-shaped bottom nav with a raised "+" in the middle
/// (universal "novo registro" entry point); on desktop-width windows
/// (Windows build) it switches to a persistent side [NavigationRail] with
/// its own "+" below the brand, so the much larger canvas gets used instead
/// of a stretched-out phone layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final showFamilyTab = (appState.currentProfile?.isAdmin ?? false) && appState.currentFamily != null;

    final items = <_NavItem>[
      _NavItem('Hoje', Icons.today_outlined, Icons.today_rounded, DashboardScreen(onViewHistory: () => _goTo(1))),
      _NavItem('Histórico', Icons.history_rounded, Icons.history_rounded, const HistoryScreen()),
      if (showFamilyTab) _NavItem('Usuários', Icons.group_outlined, Icons.group_rounded, const AdminUsersScreen()),
      _NavItem('Perfil', Icons.person_outline_rounded, Icons.person_rounded, const SettingsScreen()),
    ];

    final safeIndex = _index >= items.length ? 0 : _index;
    final pages = IndexedStack(index: safeIndex, children: [for (final i in items) i.page]);

    if (Responsive.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: safeIndex,
              onDestinationSelected: _goTo,
              labelType: NavigationRailLabelType.all,
              leading: _RailBrand(onAdd: () => EntryFormSheet.show(context)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              destinations: [
                for (final i in items)
                  NavigationRailDestination(icon: Icon(i.icon), selectedIcon: Icon(i.selectedIcon), label: Text(i.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      // Lets `body` paint behind the floating bottom nav, so page content is
      // visible through the margins around the pill instead of the bar
      // sitting on a solid background strip.
      extendBody: true,
      body: pages,
      bottomNavigationBar: SumaBottomNav(
        items: [for (final i in items) BottomNavEntry(label: i.label, icon: i.icon, selectedIcon: i.selectedIcon)],
        selectedIndex: safeIndex,
        onSelect: _goTo,
        onAdd: () => EntryFormSheet.show(context),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  final VoidCallback onAdd;
  const _RailBrand({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const SumaMark(size: 34),
          const SizedBox(height: 6),
          Text('Suma', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  const _NavItem(this.label, this.icon, this.selectedIcon, this.page);
}
