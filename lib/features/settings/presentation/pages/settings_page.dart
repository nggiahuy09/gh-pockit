import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/radio.dart';
import 'package:ghpockit/features/settings/presentation/bloc/sample_data_cubit.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({this.showDebugTools = kDebugMode, super.key});

  final bool showDebugTools;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // From the tree, not `getIt`, so the page pumps in a widget test without DI.
    final localization = context.localization;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings.title)),
      body: ListView(
        padding: EdgeInsets.all(context.spacing.md),
        children: <Widget>[
          GPRadioList<GPLocale>(
            label: l10n.settings.language,
            title: l10n.settings.language,
            value: l10n.locale,
            options: <GPRadioOption<GPLocale>>[
              // Untranslated on purpose: each language names itself.
              for (final GPLocale locale in GPLocale.values) GPRadioOption<GPLocale>(value: locale, label: locale.displayName, locale: locale.toPlatformLocale()),
            ],
            // Fire and forget: the notifier drives the repaint, and a local-only write has nothing to roll back (ADR-0004).
            onChanged: (GPLocale selected) => unawaited(localization.changeLocale(selected)),
          ),
          if (showDebugTools) BlocProvider<SampleDataCubit>(create: (_) => SampleDataCubit(), child: const _DebugTools()),
        ],
      ),
    );
  }
}

class _DebugTools extends StatelessWidget {
  const _DebugTools();

  Future<void> _addSample(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<SampleDataCubit>().addSample(accountName: l10n.settings.debugSampleAccountName, note: l10n.settings.debugSampleNote);

    final message = switch (result) {
      GPOk<TransactionEntity>() => l10n.settings.debugSampleAdded,
      GPErr<TransactionEntity>(:final failure) => failure.message(l10n),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _seedDataset(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<SampleDataCubit>().seedDataset();

    final message = switch (result) {
      GPOk<int>(:final value) => l10n.settings.debugDatasetSeeded(value),
      GPErr<int>(:final failure) => failure.message(l10n),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.only(top: spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.settings.debugTitle, style: context.text.titleSmall.copyWith(color: context.colors.onSurfaceVariant)),
          SizedBox(height: spacing.sm),
          BlocBuilder<SampleDataCubit, bool>(
            builder: (BuildContext context, bool isBusy) => Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: <Widget>[
                GPButton(
                  label: l10n.settings.debugAddSample,
                  variant: GPButtonVariant.tonal,
                  leading: const Icon(Icons.add),
                  onPressed: isBusy ? null : () => unawaited(_addSample(context)),
                ),
                GPButton(
                  label: l10n.settings.debugSeedDataset,
                  variant: GPButtonVariant.tonal,
                  leading: const Icon(Icons.dataset_outlined),
                  isLoading: isBusy,
                  onPressed: () => unawaited(_seedDataset(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
