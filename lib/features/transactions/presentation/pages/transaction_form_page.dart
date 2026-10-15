import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/pop_or_go.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/chip.dart';
import 'package:ghpockit/core/widgets/date_picker.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
import 'package:ghpockit/core/widgets/money_field.dart';
import 'package:ghpockit/core/widgets/select.dart';
import 'package:ghpockit/core/widgets/text_field.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/presentation/default_category_name.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_form_cubit.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_form_field.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_labels.dart';
import 'package:go_router/go_router.dart';

/// What the form hands back to the page that pushed it.
enum TransactionFormOutcome {
  saved,

  /// The list offers the undo (ADR-0017).
  deleted,
}

/// Create and edit share one page, for an expense, an income or a transfer.
class TransactionFormPage extends StatelessWidget {
  const TransactionFormPage({required this.clock, super.key});

  /// For the date field's "Today" / "Yesterday".
  final GPClock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<TransactionFormCubit>();

    return BlocConsumer<TransactionFormCubit, TransactionFormState>(
      listenWhen: (TransactionFormState previous, TransactionFormState current) => (!previous.isSaved && current.isSaved) || (!previous.isDeleted && current.isDeleted),
      listener: (BuildContext context, TransactionFormState state) =>
          context.popOrGoNamed(RouteNames.transactions, state.isDeleted ? TransactionFormOutcome.deleted : TransactionFormOutcome.saved),
      builder: (BuildContext context, TransactionFormState state) {
        final failure = state.failure;
        final currencyCode = state.currencyCode;
        final Widget body;

        if (state.isLoading && failure != null) {
          body = GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.message(l10n));
        } else if (state.isLoading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (cubit.isEditing && state.original == null) {
          // Nothing loaded: the transaction is gone, or could not be read. The failure says which.
          body = GPEmptyState(icon: const Icon(Icons.error_outline), title: failure?.message(l10n) ?? '');
        } else if (currencyCode == null) {
          body = GPEmptyState(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            title: l10n.transactions.noAccountsTitle,
            message: l10n.transactions.noAccountsMessage,
            actionLabel: l10n.accounts.add,
            onAction: () => context.pushNamed(RouteNames.newAccount),
          );
        } else {
          body = _TransactionForm(state: state, currencyCode: currencyCode, isEditing: cubit.isEditing, today: clock.nowUtc().toLocal());
        }

        final canDelete = state.original != null && !state.isSaving && !state.isDeleting;

        return Scaffold(
          appBar: AppBar(
            title: Text(cubit.isEditing ? l10n.transactions.edit : l10n.transactions.add),
            actions: <Widget>[
              if (cubit.isEditing) IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.transactions.delete, onPressed: canDelete ? cubit.delete : null),
            ],
          ),
          body: body,
        );
      },
    );
  }
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({required this.state, required this.currencyCode, required this.isEditing, required this.today});

  final TransactionFormState state;

  /// The selected account's, or the edited transaction's while its account is not on offer.
  final String currencyCode;

  final bool isEditing;

  /// Local, read at build: the date field shows today until the user picks a day.
  final DateTime today;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  static const List<TransactionType> _types = <TransactionType>[TransactionType.expense, TransactionType.income, TransactionType.transfer];

  final Map<TransactionFormField, FocusNode> _focusNodes = <TransactionFormField, FocusNode>{
    for (final field in TransactionFormField.values) field: FocusNode(debugLabel: field.name),
  };

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  TransactionFormState get _state => widget.state;

  DateTime get _day {
    final shown = _state.pickedDay ?? _state.original?.occurredAt.toLocal() ?? widget.today;
    return DateTime(shown.year, shown.month, shown.day);
  }

  /// A refused save moves focus to the field it is about: the keyboard may be hiding it, and a screen reader then reads its error (ADR-0016).
  void _focus(TransactionFormField field) {
    final node = _focusNodes[field]!..requestFocus();
    final fieldContext = node.context;
    // A text field scrolls itself into view on focus; a dropdown does not.
    if (fieldContext != null) unawaited(Scrollable.ensureVisible(fieldContext, alignment: 0.3, duration: GPDurationTokens.fast));
  }

  /// A planned expense may be dated ahead; a year covers rent and insurance. Widened to the day shown, which an edit may have outside it.
  (DateTime, DateTime) get _dateBounds {
    final today = widget.today;
    final day = _day;
    final firstDate = DateTime(2000);
    final lastDate = DateTime(today.year + 1, today.month, today.day);
    return (day.isBefore(firstDate) ? day : firstDate, day.isAfter(lastDate) ? day : lastDate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final cubit = context.read<TransactionFormCubit>();
    final accountId = _state.selectedAccount?.id;
    // A category deleted since the transaction was filed shows as uncategorised, as the list shows it (ADR-0010), and stays filed until another is picked.
    final categoryId = _state.categoriesForType.any((CategoryEntity category) => category.id == _state.categoryId) ? _state.categoryId : null;
    final isTransfer = _state.type == TransactionType.transfer;
    final destinations = _state.destinationsForSource;
    // Empty when nothing is picked yet, or when an edit's destination is no longer on offer.
    final destinationId = destinations.any((AccountEntity account) => account.id == _state.destinationAccountId) ? _state.destinationAccountId : null;
    final failure = _state.failure;
    final failedField = failure == null ? null : transactionFormFieldOf(failure);

    String? errorOn(TransactionFormField field) => failedField == field ? failure!.message(l10n) : null;

    return BlocListener<TransactionFormCubit, TransactionFormState>(
      listenWhen: (TransactionFormState previous, TransactionFormState current) => current.failure != null && current.failure != previous.failure,
      listener: (BuildContext context, TransactionFormState state) {
        final field = transactionFormFieldOf(state.failure!);
        if (field != null) _focus(field);
      },
      child: ListView(
        // Dragging the form puts the keyboard away: the number pad has no Done key and the note's return key adds a line.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(spacing.md),
        children: <Widget>[
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.xs),
              child: Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: <Widget>[
                  for (final type in _types) GPChip(label: type.labelIn(l10n), selected: _state.type == type, onPressed: () => cubit.typeChanged(type)),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          GPMoneyField(
            currencyCode: widget.currencyCode,
            initialMinorUnits: _state.amountMinorUnits,
            label: l10n.transactions.fieldAmount,
            errorText: errorOn(TransactionFormField.amount),
            focusNode: _focusNodes[TransactionFormField.amount],
            // An edit opens on what is there: the keyboard would cover it before the user picked what to change.
            autofocus: !widget.isEditing,
            onChanged: cubit.amountChanged,
          ),
          SizedBox(height: spacing.md),
          // Empty when an edit's account is no longer on offer.
          GPSelect<String>(
            label: isTransfer ? l10n.transactions.fieldFromAccount : l10n.transactions.fieldAccount,
            value: accountId,
            focusNode: _focusNodes[TransactionFormField.account],
            errorText: errorOn(TransactionFormField.account),
            options: <GPSelectOption<String>>[
              for (final AccountEntity option in _state.accounts!) GPSelectOption<String>(value: option.id, label: option.name, icon: option.type.icon),
            ],
            onChanged: cubit.accountChanged,
          ),
          SizedBox(height: spacing.md),
          if (isTransfer && destinations.isEmpty)
            // Nothing to pick: say why and offer the way out, rather than an empty menu.
            GPField(
              label: l10n.transactions.fieldToAccount,
              helperText: l10n.transactions.noDestinationMessage,
              errorText: errorOn(TransactionFormField.destination),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Focus(
                  focusNode: _focusNodes[TransactionFormField.destination],
                  child: GPButton(
                    label: l10n.accounts.add,
                    variant: GPButtonVariant.outlined,
                    leading: const Icon(Icons.add),
                    onPressed: () => context.pushNamed(RouteNames.newAccount),
                  ),
                ),
              ),
            )
          else if (isTransfer)
            GPSelect<String>(
              label: l10n.transactions.fieldToAccount,
              value: destinationId,
              focusNode: _focusNodes[TransactionFormField.destination],
              errorText: errorOn(TransactionFormField.destination),
              options: <GPSelectOption<String>>[
                for (final AccountEntity option in destinations) GPSelectOption<String>(value: option.id, label: option.name, icon: option.type.icon),
              ],
              onChanged: cubit.destinationChanged,
            )
          else
            GPSelect<String?>(
              label: l10n.transactions.fieldCategory,
              value: categoryId,
              focusNode: _focusNodes[TransactionFormField.category],
              errorText: errorOn(TransactionFormField.category),
              options: <GPSelectOption<String?>>[
                GPSelectOption<String?>(value: null, label: l10n.transactions.uncategorised),
                for (final CategoryEntity option in _state.categoriesForType) GPSelectOption<String?>(value: option.id, label: option.displayNameIn(l10n)),
              ],
              onChanged: cubit.categoryChanged,
            ),
          SizedBox(height: spacing.md),
          GPDateField(
            label: l10n.transactions.fieldDate,
            value: _day,
            today: widget.today,
            firstDate: _dateBounds.$1,
            lastDate: _dateBounds.$2,
            onChanged: cubit.dateChanged,
          ),
          SizedBox(height: spacing.md),
          GPTextField(
            initialValue: _state.note,
            focusNode: _focusNodes[TransactionFormField.note],
            maxLength: TransactionEntity.noteMaxLength,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            label: l10n.transactions.fieldNote,
            errorText: errorOn(TransactionFormField.note),
            onChanged: cubit.noteChanged,
          ),
          // Only a failure no field owns: a conflict, a read failure, a row gone meanwhile.
          if (failure != null && failedField == null) ...<Widget>[
            SizedBox(height: spacing.sm),
            GPFormFailureBanner(message: failure.message(l10n)),
          ],
          SizedBox(height: spacing.lg),
          GPButton(
            label: l10n.transactions.save,
            variant: GPButtonVariant.accent,
            expanded: true,
            isLoading: _state.isSaving,
            onPressed: _state.isDeleting ? null : cubit.submit,
          ),
        ],
      ),
    );
  }
}
