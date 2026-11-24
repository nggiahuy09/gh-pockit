import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/button.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/sign_out_bloc.dart';

/// Hidden when unknown or local-only (ADR-0041).
final class SyncAccountCardWidget extends StatelessWidget {
  const SyncAccountCardWidget({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthBlocState>(
    builder: (context, state) => switch (state) {
      AuthUnknownState() || AuthLocalOnlyState() => const SizedBox.shrink(),
      AuthSignedOutState() => _SyncCard(
        body: context.l10n.auth.syncSignedOutBody,
        action: GPButton(
          variant: GPButtonVariant.tonal,
          size: GPButtonSize.small,
          label: context.l10n.auth.signIn,
          onPressed: () => context.pushNamed(RouteNames.login),
        ),
      ),
      AuthSignedInState(:final user) => _SyncCard(
        body: context.l10n.auth.syncSignedInBody(user.email),
        action: BlocSelector<SignOutBloc, SignOutState, bool>(
          selector: (state) => state is SignOutCheckingState || state is SignOutInProgressState,
          builder: (context, isBusy) => GPButton(
            variant: GPButtonVariant.text,
            size: GPButtonSize.small,
            label: context.l10n.auth.signOut,
            isLoading: isBusy,
            onPressed: () => context.read<SignOutBloc>().add(const SignOutRequestEvent()),
          ),
        ),
      ),
    },
  );
}

final class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.body, this.action});

  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final text = context.text;
    final action = this.action;

    return Card(
      margin: EdgeInsets.only(bottom: spacing.md),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          spacing: spacing.smd,
          children: [
            Icon(Icons.cloud_sync_outlined, color: colors.onSurfaceVariant),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing.xs,
                children: [
                  Text(context.l10n.auth.syncTitle, style: text.titleMedium.copyWith(color: colors.onSurface)),
                  Text(body, style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
