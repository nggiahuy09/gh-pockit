import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/locale.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/dialog.dart';
import '../../../../core/widgets/radio.dart';
import '../../../auth/presentation/bloc/sign_out_bloc.dart';
import '../../../auth/presentation/widgets/sync_account_card_widget.dart';
import '../bloc/sample_data_bloc.dart';

final class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.showsDebugTools});

  final bool showsDebugTools;

  /// Fire and forget: the notifier drives the repaint, and a local-only write has nothing to roll back (ADR-0004).
  void _handleLocaleChange(BuildContext context, GPLocale locale) => unawaited(context.localization.changeLocale(locale));

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.settings;

    return BlocListener<SignOutBloc, SignOutState>(
      listener: _handleSignOutState,
      child: Scaffold(
        appBar: AppBar(title: Text(viewLocale.title)),
        body: ListView(
          padding: EdgeInsets.all(context.spacing.md),
          children: [
            const SyncAccountCardWidget(),
            GPRadioList<GPLocale>(
              // Untranslated on purpose: each language names itself.
              options: [for (final option in GPLocale.values) GPRadioOption(locale: option.toPlatformLocale(), value: option, label: option.displayName)],
              value: locale.locale,
              label: viewLocale.language,
              title: viewLocale.language,
              onChanged: (selected) => _handleLocaleChange(context, selected),
            ),
            if (showsDebugTools) const _DebugTools(),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOutState(BuildContext context, SignOutState state) async {
    final locale = context.l10n;
    final viewLocale = locale.auth;
    final bloc = context.read<SignOutBloc>();
    switch (state) {
      case SignOutBlockedState(:final count):
        await showGPDialog<void>(
          actions: [GPDialogAction(value: null, label: viewLocale.gotIt)],
          context: context,
          icon: Icons.cloud_upload_outlined,
          tone: GPDialogTone.warning,
          message: viewLocale.signOutBlockedBody(count),
          title: viewLocale.signOutBlockedTitle,
        );
        if (!bloc.isClosed) bloc.add(const SignOutCancelEvent());
      case SignOutConfirmingState():
        final confirmed = await showGPDialog<bool>(
          actions: [
            GPDialogAction.cancel(value: false, label: locale.root.cancel),
            GPDialogAction(value: true, variant: GPButtonVariant.danger, label: viewLocale.signOut),
          ],
          context: context,
          icon: Icons.logout,
          tone: GPDialogTone.danger,
          message: viewLocale.signOutConfirmBody,
          title: viewLocale.signOutConfirmTitle,
        );
        if (!bloc.isClosed) bloc.add((confirmed ?? false) ? const SignOutConfirmEvent() : const SignOutCancelEvent());
      case SignOutDoneState() when context.mounted:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewLocale.signedOut)));
      case SignOutErrorState(:final failure) when context.mounted:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.getMessage(locale))));
      case SignOutIdleState() || SignOutCheckingState() || SignOutInProgressState() || SignOutDoneState() || SignOutErrorState():
        break;
    }
  }
}

final class _DebugTools extends StatelessWidget {
  const _DebugTools();

  void _handleAdd(BuildContext context) {
    final viewLocale = context.l10n.settings;
    context.read<SampleDataBloc>().add(SampleDataAddEvent(accountName: viewLocale.debugSampleAccountName, note: viewLocale.debugSampleNote));
  }

  void _handleSeed(BuildContext context) => context.read<SampleDataBloc>().add(const SampleDataSeedEvent());

  void _handleOutcome(BuildContext context, SampleDataState state) {
    final locale = context.l10n;
    final viewLocale = locale.settings;
    final message = switch (state) {
      SampleDataInitState() || SampleDataLoadingState() => null,
      SampleDataAddedState() => viewLocale.debugSampleAdded,
      SampleDataAddErrorState(:final failure) => failure.getMessage(locale),
      SampleDataSeededState(:final count) => viewLocale.debugDatasetSeeded(count),
      SampleDataSeedErrorState(:final failure) => failure.getMessage(locale),
    };
    if (message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final viewLocale = context.l10n.settings;
    final spacing = context.spacing;

    return BlocListener<SampleDataBloc, SampleDataState>(
      listenWhen: (_, next) => next is SampleDataOutcomeState,
      listener: (_, state) => _handleOutcome(context, state),
      child: Padding(
        padding: EdgeInsets.only(top: spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.sm,
          children: [
            Text(viewLocale.debugTitle, style: context.text.titleSmall.copyWith(color: context.colors.onSurfaceVariant)),
            BlocSelector<SampleDataBloc, SampleDataState, bool>(
              selector: (state) => state is SampleDataLoadingState,
              builder: (_, isBusy) => Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  GPButton(
                    leading: const Icon(Icons.add),
                    variant: GPButtonVariant.tonal,
                    label: viewLocale.debugAddSample,
                    onPressed: isBusy ? null : () => _handleAdd(context),
                  ),
                  GPButton(
                    leading: const Icon(Icons.dataset_outlined),
                    variant: GPButtonVariant.tonal,
                    label: viewLocale.debugSeedDataset,
                    isLoading: isBusy,
                    onPressed: () => _handleSeed(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
