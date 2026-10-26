import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/locale_base/locale_base.dart';
import '../../core/localization/localization_scope.dart';
import '../../core/theme/theme_context.dart';
import '../../core/theme/tokens/dimensions.dart';
import '../../core/widgets/glass.dart';
import 'routes.dart';

@immutable
final class ShellTab {
  const ShellTab({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;

  /// A function, not a string: the tab outlives a language change, the string does not.
  final String Function(GPLocaleBaseRootBottomNav nav) label;
}

/// In branch order: must match the branch list in `app_router.dart`.
const List<ShellTab> shellTabs = [
  ShellTab(icon: Icons.home_outlined, selectedIcon: Icons.home, label: _homeLabel),
  ShellTab(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet, label: _accountsLabel),
  ShellTab(icon: Icons.swap_vert_outlined, selectedIcon: Icons.swap_vert, label: _transactionsLabel),
  ShellTab(icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart, label: _budgetsLabel),
];

// Top-level functions so `shellTabs` stays `const`: a tear-off is a constant, a closure is not.
String _homeLabel(GPLocaleBaseRootBottomNav nav) => nav.home;

String _accountsLabel(GPLocaleBaseRootBottomNav nav) => nav.accounts;

String _transactionsLabel(GPLocaleBaseRootBottomNav nav) => nav.transactions;

String _budgetsLabel(GPLocaleBaseRootBottomNav nav) => nav.budgets;

/// The add button shows on every tab root; a page pushed inside a tab (settings) hides it.
const Set<String> _addButtonPaths = {Routes.home, Routes.accounts, Routes.transactions, Routes.budgets};

/// Holds no selected-tab state: `navigationShell.currentIndex` is the only source, so a deep link selects its tab with nothing to sync.
final class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell, required this.location}) : assert(shellTabs.length == 4, 'shellTabs must match the branch count in app_router.dart');

  final StatefulNavigationShell navigationShell;

  /// The current path, which decides whether the add button shows.
  final String location;

  static const dockKey = Key('shell-dock');
  static const addButtonKey = Key('shell-add-transaction');
  static const dockHeight = 64.0;

  /// Re-tapping the active tab pops it to its root (platform convention); switching to another tab must not reset it.
  void _handleTabSelect(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final spacing = context.spacing;
    final dockBottom = math.max(media.padding.bottom, 20.0);
    final theme = Theme.of(context);
    // A floating snackbar sits on the safe area's edge, where the dock is: the inset lifts every snackbar shown in the shell clear of it.
    final snackBarInset = EdgeInsets.fromLTRB(spacing.smd, 0.0, spacing.smd, dockBottom + dockHeight + spacing.sm - media.padding.bottom);

    return Theme(
      data: theme.copyWith(snackBarTheme: theme.snackBarTheme.copyWith(insetPadding: snackBarInset)),
      child: Scaffold(
        body: Stack(
          children: [
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
                child: _Dock(currentIndex: navigationShell.currentIndex, showsAddButton: _addButtonPaths.contains(location), onTabSelect: _handleTabSelect),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Dock extends StatelessWidget {
  const _Dock({required this.currentIndex, required this.showsAddButton, required this.onTabSelect});

  final int currentIndex;
  final bool showsAddButton;
  final void Function(int index) onTabSelect;

  void _handleAdd(BuildContext context) => unawaited(context.pushNamed(RouteNames.newTransaction));

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final navLocale = locale.root.bottomNav;
    final colors = context.colors;
    final spacing = context.spacing;

    return Row(
      spacing: spacing.sm + spacing.xxs,
      children: [
        Expanded(
          child: Semantics(
            key: AppShell.dockKey,
            container: true,
            label: navLocale.label,
            child: GPGlass(
              child: SizedBox(
                height: AppShell.dockHeight,
                child: Padding(
                  padding: EdgeInsets.all(spacing.xs),
                  child: Row(
                    children: [
                      for (var i = 0; i < shellTabs.length; i++)
                        Expanded(
                          child: _DockTab(tab: shellTabs[i], label: shellTabs[i].label.call(navLocale), isSelected: i == currentIndex, onTap: () => onTabSelect.call(i)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showsAddButton)
          GPGlass(
            tint: colors.accent,
            circle: true,
            child: SizedBox.square(
              dimension: AppShell.dockHeight,
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  key: AppShell.addButtonKey,
                  tooltip: locale.transactions.add,
                  onPressed: () => _handleAdd(context),
                  icon: Icon(Icons.add, size: 28.0, color: colors.onAccent),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final class _DockTab extends StatelessWidget {
  const _DockTab({required this.tab, required this.label, required this.isSelected, required this.onTap});

  final ShellTab tab;
  final String label;
  final bool isSelected;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = isSelected ? colors.onAccentContainer : colors.onBackground;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: 0.08)),
            child: AnimatedContainer(
              duration: GPDurationTokens.normal,
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: isSelected ? colors.accentContainer : Colors.transparent),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: context.spacing.xxs,
                children: [
                  Icon(isSelected ? tab.selectedIcon : tab.icon, size: 24.0, color: foreground),
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
