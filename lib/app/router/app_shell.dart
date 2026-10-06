import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:go_router/go_router.dart';

@immutable
class ShellTab {
  const ShellTab({required this.label, required this.icon, required this.selectedIcon});

  /// A function, not a string: the tab outlives a language change, the string does not.
  final String Function(GPLocaleBaseRootBottomNav) label;
  final IconData icon;
  final IconData selectedIcon;
}

/// In branch order: must match the branch list in `app_router.dart`.
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

/// Holds no selected-tab state: `navigationShell.currentIndex` is the only source, so a deep link selects its tab with nothing to sync.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key}) : assert(shellTabs.length == 5, 'shellTabs must match the branch count in app_router.dart');

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Re-tapping the active tab pops it to its root (platform convention); switching to another tab must not reset it.
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
