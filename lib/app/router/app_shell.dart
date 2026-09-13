import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:go_router/go_router.dart';

/// One tab of the bottom navigation.
///
/// Kept as data rather than five hand-written `NavigationDestination`s so the branch order in `app_router.dart` and the destination order here cannot
/// drift apart: [AppShell] asserts they have the same length, and both read this one list.
@immutable
class ShellTab {
  const ShellTab({required this.label, required this.icon, required this.selectedIcon});

  /// Reads this tab's label off the active strings, rather than holding one. A tab outlives a language change, the string does not.
  final String Function(GPLocaleBaseRootBottomNav) label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The five tabs, in branch order. Changing this order changes which branch index each tab maps to — keep it in sync with the branch list in
/// `app_router.dart`.
const List<ShellTab> shellTabs = <ShellTab>[
  ShellTab(label: _homeLabel, icon: Icons.home_outlined, selectedIcon: Icons.home),
  ShellTab(label: _accountsLabel, icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet),
  ShellTab(label: _transactionsLabel, icon: Icons.swap_vert_outlined, selectedIcon: Icons.swap_vert),
  ShellTab(label: _budgetsLabel, icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart),
  ShellTab(label: _settingsLabel, icon: Icons.settings_outlined, selectedIcon: Icons.settings),
];

// Top-level functions so `shellTabs` stays `const`: a tear-off is a constant, a closure is not.
String _homeLabel(GPLocaleBaseRootBottomNav nav) => nav.home;
String _accountsLabel(GPLocaleBaseRootBottomNav nav) => nav.accounts;
String _transactionsLabel(GPLocaleBaseRootBottomNav nav) => nav.transactions;
String _budgetsLabel(GPLocaleBaseRootBottomNav nav) => nav.budgets;
String _settingsLabel(GPLocaleBaseRootBottomNav nav) => nav.settings;

/// The persistent chrome around every tab: the bottom navigation bar, and the branch [Navigator] currently on screen.
///
/// This widget owns no state of its own. `navigationShell.currentIndex` is the single source of truth for which tab is selected, which means a deep
/// link straight into `/budgets` selects the Budgets tab without anybody having to synchronise an `int` by hand.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key}) : assert(shellTabs.length == 5, 'shellTabs must match the branch count in app_router.dart');

  /// The shell built by `StatefulShellRoute.indexedStack` — it holds one [Navigator] per branch and keeps all five alive.
  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // `initialLocation: true` only when the tab is re-tapped: that is the platform convention of "tap the active tab to pop back to its root".
    // Tapping a different tab must NOT reset it — the whole point of the stateful shell is that the other branch is still where the user left it.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.l10n.root.bottomNav;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: <Widget>[
          for (final ShellTab tab in shellTabs) NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label(nav)),
        ],
      ),
    );
  }
}
