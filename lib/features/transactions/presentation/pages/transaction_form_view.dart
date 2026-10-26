import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/pop_or_go.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/theme/tokens/dimensions.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/chip.dart';
import '../../../../core/widgets/date_picker.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/field.dart';
import '../../../../core/widgets/form_failure_banner.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/select.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/presentation/account_type_extension.dart';
import '../../../categories/presentation/category_entity_extension.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_type.dart';
import '../bloc/transaction_form_bloc.dart';
import '../transaction_form_field_enum.dart';
import '../transaction_form_outcome_enum.dart';
import '../transaction_type_extension.dart';

final class TransactionFormView extends StatelessWidget {
  const TransactionFormView({super.key, required this.clock});

  final GPClock clock;

  void _handleDone(BuildContext context, TransactionFormState state) =>
      context.popOrGoNamed(RouteNames.transactions, state.isDeleted ? TransactionFormOutcome.deleted : TransactionFormOutcome.saved);

  void _handleDelete(BuildContext context) => context.read<TransactionFormBloc>().add(const TransactionFormDeleteEvent());

  @override
  Widget build(BuildContext context) {
    final viewLocale = context.l10n.transactions;

    return BlocConsumer<TransactionFormBloc, TransactionFormState>(
      listenWhen: (prev, next) => (!prev.isSaved && next.isSaved) || (!prev.isDeleted && next.isDeleted),
      listener: (_, state) => _handleDone(context, state),
      builder: (_, state) {
        final canDelete = state.original != null && !state.isSaving && !state.isDeleting;

        return Scaffold(
          appBar: AppBar(
            title: Text(state.isEditing ? viewLocale.edit : viewLocale.add),
            actions: [
              if (state.isEditing) IconButton(icon: const Icon(Icons.delete_outline), tooltip: viewLocale.delete, onPressed: canDelete ? () => _handleDelete(context) : null),
            ],
          ),
          body: _TransactionFormBody(state: state, today: clock.nowUtc().toLocal()),
        );
      },
    );
  }
}

final class _TransactionFormBody extends StatelessWidget {
  const _TransactionFormBody({required this.state, required this.today});

  final TransactionFormState state;
  final DateTime today;

  void _handleAddAccount(BuildContext context) => unawaited(context.pushNamed(RouteNames.newAccount));

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.transactions;
    final failure = state.failure;
    final currencyCode = state.currencyCode;

    if (state.isLoading) {
      return failure == null ? const Center(child: CircularProgressIndicator()) : GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.getMessage(locale));
    }

    // Nothing loaded: the transaction is gone, or could not be read. The failure says which.
    if (state.isEditing && state.original == null) return GPEmptyState(icon: const Icon(Icons.error_outline), title: failure?.getMessage(locale) ?? '');

    if (currencyCode == null) {
      return GPEmptyState(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        actionLabel: locale.accounts.add,
        message: viewLocale.noAccountsBody,
        title: viewLocale.noAccountsTitle,
        onAction: () => _handleAddAccount(context),
      );
    }

    return _TransactionForm(state: state, today: today, currencyCode: currencyCode);
  }
}

final class _TransactionForm extends StatefulWidget {
  const _TransactionForm({required this.state, required this.today, required this.currencyCode});

  final TransactionFormState state;

  /// Local, read at build: the date field shows today until the user picks a day.
  final DateTime today;

  final String currencyCode;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

final class _TransactionFormState extends State<_TransactionForm> {
  final Map<TransactionFormField, FocusNode> _focusNodes = {for (final field in TransactionFormField.values) field: FocusNode(debugLabel: field.name)};

  static const List<TransactionType> _types = [TransactionType.expense, TransactionType.income, TransactionType.transfer];

  TransactionFormState get _state => widget.state;

  DateTime get _day {
    final shown = _state.pickedDay ?? _state.original?.occurredAt.toLocal() ?? widget.today;
    return DateTime(shown.year, shown.month, shown.day);
  }

  /// A planned expense may be dated ahead; a year covers rent and insurance. Widened to the day shown, which an edit may have outside it.
  ({DateTime first, DateTime last}) get _dateBounds {
    final today = widget.today;
    final day = _day;
    final first = DateTime(2000);
    final last = DateTime(today.year + 1, today.month, today.day);
    return (first: day.isBefore(first) ? day : first, last: day.isAfter(last) ? day : last);
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// A refused save moves focus to the field it is about: the keyboard may be hiding it, and a screen reader then reads its error (ADR-0016).
  void _handleFailure(TransactionFormState state) {
    final field = state.failedField;
    final node = field == null ? null : _focusNodes[field];
    if (node == null) return;

    node.requestFocus();
    // A text field scrolls itself into view on focus; a dropdown does not.
    final fieldContext = node.context;
    if (fieldContext != null) unawaited(Scrollable.ensureVisible(fieldContext, alignment: 0.3, duration: GPDurationTokens.fast));
  }

  void _handleTypeChange(TransactionType type) => context.read<TransactionFormBloc>().add(TransactionFormTypeChangeEvent(type));

  void _handleAmountChange(int? minorUnits) => context.read<TransactionFormBloc>().add(TransactionFormAmountChangeEvent(minorUnits));

  void _handleAccountChange(String accountId) => context.read<TransactionFormBloc>().add(TransactionFormAccountChangeEvent(accountId));

  void _handleDestinationChange(String accountId) => context.read<TransactionFormBloc>().add(TransactionFormDestinationChangeEvent(accountId));

  void _handleCategoryChange(String? categoryId) => context.read<TransactionFormBloc>().add(TransactionFormCategoryChangeEvent(categoryId));

  void _handleDateChange(DateTime day) => context.read<TransactionFormBloc>().add(TransactionFormDateChangeEvent(day));

  void _handleNoteChange(String note) => context.read<TransactionFormBloc>().add(TransactionFormNoteChangeEvent(note));

  void _handleAddAccount() => unawaited(context.pushNamed(RouteNames.newAccount));

  void _handleSubmit() => context.read<TransactionFormBloc>().add(const TransactionFormSubmitEvent());

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.transactions;
    final spacing = context.spacing;
    final categoriesForType = _state.categoriesForType;
    final destinations = _state.destinationsForSource;
    // A category deleted since the transaction was filed shows as uncategorised, as the list shows it (ADR-0010), and stays filed until another is picked.
    final categoryId = categoriesForType.any((category) => category.id == _state.categoryId) ? _state.categoryId : null;
    final destinationId = destinations.any((account) => account.id == _state.destinationAccountId) ? _state.destinationAccountId : null;
    final failure = _state.failure;
    final failedField = _state.failedField;
    final failureMessage = failure?.getMessage(locale);
    final dateBounds = _dateBounds;

    return BlocListener<TransactionFormBloc, TransactionFormState>(
      listenWhen: (prev, next) => next.failure != null && next.failure != prev.failure,
      listener: (_, state) => _handleFailure(state),
      child: ListView(
        // Dragging the form puts the keyboard away: the number pad has no Done key and the note's return key adds a line.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(spacing.md),
        children: [
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.xs),
              child: Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [for (final type in _types) GPChip(label: type.getTitle(locale), selected: _state.type == type, onPressed: () => _handleTypeChange(type))],
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          GPMoneyField(
            focusNode: _focusNodes[TransactionFormField.amount],
            currencyCode: widget.currencyCode,
            errorText: failedField == TransactionFormField.amount ? failureMessage : null,
            label: viewLocale.fieldAmount,
            initialMinorUnits: _state.amountMinorUnits,
            // An edit opens on what is there: the keyboard would cover it before the user picked what to change.
            autofocus: !_state.isEditing,
            onChanged: _handleAmountChange,
          ),
          SizedBox(height: spacing.md),
          GPSelect<String>(
            options: [for (final option in _state.accounts ?? const <AccountEntity>[]) GPSelectOption(icon: option.type.icon, value: option.id, label: option.name)],
            focusNode: _focusNodes[TransactionFormField.account],
            value: _state.selectedAccount?.id,
            errorText: failedField == TransactionFormField.account ? failureMessage : null,
            label: _state.type.isTransfer ? viewLocale.fieldFromAccount : viewLocale.fieldAccount,
            onChanged: _handleAccountChange,
          ),
          SizedBox(height: spacing.md),
          if (_state.type.isTransfer && destinations.isEmpty)
            // Nothing to pick: say why and offer the way out, rather than an empty menu.
            GPField(
              errorText: failedField == TransactionFormField.destination ? failureMessage : null,
              helperText: viewLocale.noDestinationMessage,
              label: viewLocale.fieldToAccount,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Focus(
                  focusNode: _focusNodes[TransactionFormField.destination],
                  child: GPButton(leading: const Icon(Icons.add), variant: GPButtonVariant.outlined, label: locale.accounts.add, onPressed: _handleAddAccount),
                ),
              ),
            )
          else if (_state.type.isTransfer)
            GPSelect<String>(
              options: [for (final option in destinations) GPSelectOption(icon: option.type.icon, value: option.id, label: option.name)],
              focusNode: _focusNodes[TransactionFormField.destination],
              value: destinationId,
              errorText: failedField == TransactionFormField.destination ? failureMessage : null,
              label: viewLocale.fieldToAccount,
              onChanged: _handleDestinationChange,
            )
          else
            GPSelect<String?>(
              options: [
                GPSelectOption(value: null, label: viewLocale.uncategorised),
                for (final option in categoriesForType) GPSelectOption(value: option.id, label: option.getTitle(locale)),
              ],
              focusNode: _focusNodes[TransactionFormField.category],
              value: categoryId,
              errorText: failedField == TransactionFormField.category ? failureMessage : null,
              label: viewLocale.fieldCategory,
              onChanged: _handleCategoryChange,
            ),
          SizedBox(height: spacing.md),
          GPDateField(
            firstDate: dateBounds.first,
            lastDate: dateBounds.last,
            today: widget.today,
            value: _day,
            label: viewLocale.fieldDate,
            onChanged: _handleDateChange,
          ),
          SizedBox(height: spacing.md),
          GPTextField(
            focusNode: _focusNodes[TransactionFormField.note],
            textCapitalization: TextCapitalization.sentences,
            errorText: failedField == TransactionFormField.note ? failureMessage : null,
            initialValue: _state.note,
            label: viewLocale.fieldNote,
            maxLength: TransactionEntity.noteMaxLength,
            maxLines: null,
            onChanged: _handleNoteChange,
          ),
          // Only a failure no field owns: a conflict, a read failure, a row gone meanwhile.
          if (failureMessage != null && failedField == null) ...[
            SizedBox(height: spacing.sm),
            GPFormFailureBanner(message: failureMessage),
          ],
          SizedBox(height: spacing.lg),
          GPButton(
            variant: GPButtonVariant.accent,
            label: viewLocale.save,
            expanded: true,
            isLoading: _state.isSaving,
            onPressed: _state.isDeleting ? null : _handleSubmit,
          ),
        ],
      ),
    );
  }
}
