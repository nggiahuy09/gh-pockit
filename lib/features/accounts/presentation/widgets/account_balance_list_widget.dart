import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/account_balance.dart';
import '../account_type_extension.dart';

/// The same rows on Home and on the Accounts tab, so the two never drift apart.
final class AccountBalanceCardWidget extends StatelessWidget {
  const AccountBalanceCardWidget({super.key, required this.balances});

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
            children: [
              for (var i = 0; i < balances.length; i++) ...[
                if (i > 0) Divider(height: 1.0, thickness: 1.0, color: colors.outlineVariant),
                AccountBalanceRowWidget(balance: balances[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A tap opens the account's edit form.
final class AccountBalanceRowWidget extends StatelessWidget {
  const AccountBalanceRowWidget({super.key, required this.balance});

  final AccountBalance balance;

  static const minHeight = 64.0;

  void _handleTap(BuildContext context) => unawaited(context.pushNamed(RouteNames.editAccount, pathParameters: {'accountId': balance.account.id}));

  @override
  Widget build(BuildContext context) {
    final account = balance.account;
    final colors = context.colors;
    final spacing = context.spacing;

    return InkWell(
      onTap: () => _handleTap(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          child: Row(
            spacing: spacing.smd,
            children: [
              SizedBox.square(
                dimension: 40.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
                  child: Icon(account.type.icon, size: 20.0, color: colors.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge.copyWith(color: colors.onSurface),
                    ),
                    Text(account.type.getTitle(context.l10n), style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              // Neutral keeps the balance's own sign; red only repeats it for money owed.
              GPMoneyText(
                style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: balance.balance.isNegative ? colors.expense : colors.onSurface),
                amount: balance.balance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's frame with bars where the text goes, so the list lands in place rather than pushing the page around.
final class AccountListSkeletonWidget extends StatelessWidget {
  const AccountListSkeletonWidget({super.key});

  /// Name and balance bar widths per row: uneven on purpose, so it reads as text rather than a grid.
  static const _rows = [(120.0, 80.0), (150.0, 96.0), (104.0, 72.0), (168.0, 64.0)];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Semantics(
      container: true,
      label: context.l10n.accounts.loading,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(spacing.xs, spacing.xs, spacing.xs, spacing.sm),
                child: const _SkeletonBar(height: 12.0, width: 96.0),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
                child: Column(
                  children: [
                    for (final (name, amount) in _rows)
                      SizedBox(
                        height: AccountBalanceRowWidget.minHeight,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing.md),
                          child: Row(
                            spacing: spacing.smd,
                            children: [
                              _SkeletonBar(borderRadius: BorderRadius.circular(20.0), height: 40.0, width: 40.0),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: spacing.xs,
                                children: [
                                  _SkeletonBar(height: 14.0, width: name),
                                  const _SkeletonBar(height: 10.0, width: 64.0),
                                ],
                              ),
                              const Spacer(),
                              _SkeletonBar(height: 14.0, width: amount),
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

final class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({this.borderRadius, required this.height, required this.width});

  final BorderRadius? borderRadius;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: borderRadius ?? context.radii.borderSm),
    ),
  );
}
