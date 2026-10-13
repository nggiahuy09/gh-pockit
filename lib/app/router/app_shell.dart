import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/widgets/glass.dart';
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
];

// Top-level functions so `shellTabs` stays `const`: a tear-off is a constant, a closure is not.
String _homeLabel(GPLocaleBaseRootBottomNav nav) => nav.home;
String _accountsLabel(GPLocaleBaseRootBottomNav nav) => nav.accounts;
String _transactionsLabel(GPLocaleBaseRootBottomNav nav) => nav.transactions;
String _budgetsLabel(GPLocaleBaseRootBottomNav nav) => nav.budgets;

/// The add button shows on every tab root; a page pushed inside a tab (settings) hides it.
const Set<String> _addButtonPaths = <String>{Routes.home, Routes.accounts, Routes.transactions, Routes.budgets};

/// Holds no selected-tab state: `navigationShell.currentIndex` is the only source, so a deep link selects its tab with nothing to sync.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, required this.location, super.key}) : assert(shellTabs.length == 4, 'shellTabs must match the branch count in app_router.dart');

  static const double dockHeight = 64;

  static const Key dockKey = Key('shell-dock');
  static const Key addButtonKey = Key('shell-add-transaction');

  final StatefulNavigationShell navigationShell;

  /// The current path, which decides whether the add button shows.
  final String location;

  void _onTabSelected(int index) {
    // Re-tapping the active tab pops it to its root (platform convention); switching to another tab must not reset it.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final spacing = context.spacing;
    final dockBottom = math.max(media.padding.bottom, 20).toDouble();
    final theme = Theme.of(context);
    // A floating snackbar sits on the safe area's edge, where the dock is: the inset lifts every snackbar shown in the shell clear of it.
    final snackBarInset = EdgeInsets.fromLTRB(spacing.smd, 0, spacing.smd, dockBottom + dockHeight + spacing.sm - media.padding.bottom);

    return Theme(
      data: theme.copyWith(snackBarTheme: theme.snackBarTheme.copyWith(insetPadding: snackBarInset)),
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            // The dock floats over the pages, so they see it as part of the bottom inset and keep their last row scrollable past it.
            MediaQuery(
              data: media.copyWith(padding: media.padding.copyWith(bottom: dockBottom + dockHeight + spacing.md)),
              child: navigationShell,
            ),
            Positioned(
              left: spacing.smd,
              right: spacing.smd,
              bottom: dockBottom,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: _Dock(
                  currentIndex: navigationShell.currentIndex,
                  onTabSelected: _onTabSelected,
                  showAddButton: _addButtonPaths.contains(location),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.currentIndex, required this.onTabSelected, required this.showAddButton});

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nav = l10n.root.bottomNav;
    final colors = context.colors;

    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            key: AppShell.dockKey,
            container: true,
            label: nav.label,
            child: GPGlass(
              child: SizedBox(
                height: AppShell.dockHeight,
                child: Padding(
                  padding: EdgeInsets.all(context.spacing.xs),
                  child: Row(
                    children: <Widget>[
                      for (var i = 0; i < shellTabs.length; i++)
                        Expanded(
                          child: _DockTab(tab: shellTabs[i], label: shellTabs[i].label(nav), selected: i == currentIndex, onTap: () => onTabSelected(i)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showAddButton) ...<Widget>[
          SizedBox(width: context.spacing.sm + context.spacing.xxs),
          GPGlass(
            circle: true,
            tint: colors.accent,
            child: SizedBox.square(
              dimension: AppShell.dockHeight,
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  key: AppShell.addButtonKey,
                  tooltip: l10n.transactions.add,
                  onPressed: () => context.pushNamed(RouteNames.newTransaction),
                  icon: Icon(Icons.add, size: 28, color: colors.onAccent),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({required this.tab, required this.label, required this.selected, required this.onTap});

  final ShellTab tab;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.onAccentContainer : colors.onBackground;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            overlayColor: WidgetStatePropertyAll<Color>(foreground.withValues(alpha: 0.08)),
            child: AnimatedContainer(
              duration: GPDurationTokens.normal,
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: selected ? colors.accentContainer : Colors.transparent),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(selected ? tab.selectedIcon : tab.icon, size: 24, color: foreground),
                  SizedBox(height: context.spacing.xxs),
                  // Shrinks rather than cuts: "Transactions" is wider than a quarter of a phone-width dock.
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, style: context.text.labelSmall.copyWith(color: foreground), maxLines: 1),
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
