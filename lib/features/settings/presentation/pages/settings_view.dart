import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/locale.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/radio.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(viewLocale.title)),
      body: ListView(
        padding: EdgeInsets.all(context.spacing.md),
        children: [
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
    );
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
