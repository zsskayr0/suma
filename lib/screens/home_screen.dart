import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/suma_bottom_nav.dart';
import 'admin_users_screen.dart';
import 'dashboard_screen.dart';
import 'entry_form_sheet.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Shell shown once someone is logged in. On phone-width windows this is a
/// floating pill-shaped bottom nav with a raised "+" in the middle
/// (universal "novo registro" entry point); on desktop-width windows
/// (Windows build) it switches to a [DesktopSidebar] - collapsed to icons
/// by default, expanding on hover - with its own "+" below the brand, so
/// the much larger canvas gets used instead of a stretched-out phone
/// layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  // Bumped for a tab every time it's navigated TO - passed down as
  // DashboardScreen/HistoryScreen's revealToken so their chart/stat tiles
  // replay their entrance animation on every revisit, not just the very
  // first time (IndexedStack keeps every tab's own state alive, so nothing
  // would naturally replay on its own).
  final Map<int, int> _visitTokens = {};

  void _goTo(int i) => setState(() {
        _index = i;
        _visitTokens[i] = (_visitTokens[i] ?? 0) + 1;
      });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // Any member of the family sees the tab now, not just the admin - the
    // screen itself adapts what it shows based on role (see
    // AdminUsersScreen).
    final showFamilyTab = appState.currentFamily != null;

    final items = <_NavItem>[
      _NavItem('Estatísticas', Icons.bar_chart_rounded, Icons.bar_chart_rounded, DashboardScreen(onViewHistory: () => _goTo(1), revealToken: _visitTokens[0] ?? 0), svgAsset: 'assets/icons/nav_estatisticas.svg'),
      _NavItem('Histórico', Icons.history_rounded, Icons.history_rounded, HistoryScreen(revealToken: _visitTokens[1] ?? 0), svgAsset: 'assets/icons/nav_historico.svg'),
      if (showFamilyTab) _NavItem('Usuários', Icons.group_outlined, Icons.group_rounded, const AdminUsersScreen(), svgAsset: 'assets/icons/nav_usuarios.svg'),
      _NavItem('Perfil', Icons.person_outline_rounded, Icons.person_rounded, const SettingsScreen(), isProfile: true),
    ];

    final safeIndex = _index >= items.length ? 0 : _index;
    final pages = IndexedStack(
      index: safeIndex,
      children: [
        for (var i = 0; i < items.length; i++)
          _FadeInOnActivate(activationToken: _visitTokens[i] ?? 0, child: items[i].page),
      ],
    );

    if (Responsive.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            DesktopSidebar(
              items: [
                for (final i in items)
                  SidebarEntry(label: i.label, icon: i.icon, selectedIcon: i.selectedIcon, svgAsset: i.svgAsset),
              ],
              selectedIndex: safeIndex,
              onSelect: _goTo,
              onAdd: () => EntryFormSheet.show(context),
              avatarUrl: appState.currentProfile?.avatarUrl,
              userName: appState.currentProfile?.name ?? '',
              userEmail: appState.currentProfile?.email,
              userIsAdmin: appState.currentProfile?.isAdmin ?? false,
            ),
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
        items: [
          for (final i in items)
            BottomNavEntry(
              label: i.label,
              icon: i.icon,
              selectedIcon: i.selectedIcon,
              svgAsset: i.svgAsset,
              avatarName: i.isProfile ? (appState.currentProfile?.name ?? '') : null,
              avatarUrl: i.isProfile ? appState.currentProfile?.avatarUrl : null,
            ),
        ],
        selectedIndex: safeIndex,
        onSelect: _goTo,
        onAdd: () => EntryFormSheet.show(context),
      ),
    );
  }
}

/// Fades its child in whenever [activationToken] changes - used to give
/// each tab's page a soft fade-in every time you switch to it, without
/// tearing down and remounting the page itself (which would lose scroll
/// position, filters, etc. - IndexedStack already keeps all tabs alive;
/// this just layers a repeatable fade on top of that).
class _FadeInOnActivate extends StatefulWidget {
  final Object activationToken;
  final Widget child;
  const _FadeInOnActivate({required this.activationToken, required this.child});

  @override
  State<_FadeInOnActivate> createState() => _FadeInOnActivateState();
}

class _FadeInOnActivateState extends State<_FadeInOnActivate> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward();

  @override
  void didUpdateWidget(covariant _FadeInOnActivate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activationToken != oldWidget.activationToken) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool isProfile;
  // Custom SVG glyph override - see BottomNavEntry.svgAsset.
  final String? svgAsset;
  const _NavItem(this.label, this.icon, this.selectedIcon, this.page, {this.isProfile = false, this.svgAsset});
}
