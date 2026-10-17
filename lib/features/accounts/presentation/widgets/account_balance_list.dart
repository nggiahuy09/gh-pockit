import 'package:flutter/material.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/money_text.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';
import 'package:go_router/go_router.dart';

/// One card of account rows, as the canvas draws them on Home and on the Accounts tab: the same rows on both, so the two never drift apart.
class AccountBalanceCard extends StatelessWidget {
  const AccountBalanceCard({required this.balances, super.key});

  final List<AccountBalance> balances;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
      child: ClipRRect(
        borderRadius: context.radii.borderLg,
        // Transparent, so the ripple draws above the card's colour rather than under it on the page's Material.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < balances.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, thickness: 1, color: colors.outlineVariant),
                AccountBalanceRow(balance: balances[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon, name, type and balance; a tap opens the account's edit form.
class AccountBalanceRow extends StatelessWidget {
  const AccountBalanceRow({required this.balance, super.key});

  static const double minHeight = 64;

  final AccountBalance balance;

  @override
  Widget build(BuildContext context) {
    final account = balance.account;
    final l10n = context.l10n;
    final colors = context.colors;
    final spacing = context.spacing;

    return InkWell(
      onTap: () => context.pushNamed(RouteNames.editAccount, pathParameters: <String, String>{'accountId': account.id}),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
                child: Icon(account.type.icon, size: 20, color: colors.onSurfaceVariant),
              ),
              SizedBox(width: spacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge.copyWith(color: colors.onSurface),
                    ),
                    Text(account.type.labelIn(l10n), style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              SizedBox(width: spacing.smd),
              // Neutral keeps the balance's own sign; red only repeats it for money owed.
              GPMoneyText(
                balance.balance,
                style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: balance.balance.isNegative ? colors.expense : colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's frame with bars where the text goes, so the list lands in place rather than pushing the page around.
class AccountListSkeleton extends StatelessWidget {
  const AccountListSkeleton({super.key});

  /// Name and balance bar widths per row: uneven on purpose, so it reads as text rather than a grid.
  static const List<(double, double)> _rows = <(double, double)>[(120, 80), (150, 96), (104, 72), (168, 64)];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    Widget bar(double width, double height, {BorderRadius? radius}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: radius ?? context.radii.borderSm),
    );

    return Semantics(
      container: true,
      label: context.l10n.accounts.loading,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(spacing.xs, spacing.xs, spacing.xs, spacing.sm),
                child: bar(96, 12),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
                child: Column(
                  children: <Widget>[
                    for (final (name, amount) in _rows)
                      SizedBox(
                        height: AccountBalanceRow.minHeight,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing.md),
                          child: Row(
                            children: <Widget>[
                              bar(40, 40, radius: BorderRadius.circular(20)),
                              SizedBox(width: spacing.smd),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  bar(name, 14),
                                  SizedBox(height: spacing.xs),
                                  bar(64, 10),
                                ],
                              ),
                              const Spacer(),
                              bar(amount, 14),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
