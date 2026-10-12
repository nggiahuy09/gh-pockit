import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/pop_or_go.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
import 'package:ghpockit/core/widgets/money_field.dart';
import 'package:ghpockit/core/widgets/utf16_length_limit.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/presentation/default_category_name.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_form_cubit.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_days.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_labels.dart';
import 'package:go_router/go_router.dart';

/// Expense or income for now; the type picker grows a transfer with the transfer flow.
class TransactionFormPage extends StatelessWidget {
  const TransactionFormPage({required this.clock, super.key});

  /// For the date field's "Today" / "Yesterday".
  final GPClock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<TransactionFormCubit, TransactionFormState>(
      listenWhen: (TransactionFormState previous, TransactionFormState current) => !previous.isSaved && current.isSaved,
      listener: (BuildContext context, TransactionFormState state) => context.popOrGoNamed(RouteNames.transactions),
      builder: (BuildContext context, TransactionFormState state) {
        final failure = state.failure;
        final account = state.selectedAccount;
        final Widget body;

        if (state.isLoading && failure != null) {
          body = GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.message(l10n));
        } else if (state.isLoading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (account == null) {
          body = GPEmptyState(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            title: l10n.transactions.noAccountsTitle,
            message: l10n.transactions.noAccountsMessage,
            actionLabel: l10n.accounts.add,
            onAction: () => context.pushNamed(RouteNames.newAccount),
          );
        } else {
          body = _TransactionForm(state: state, account: account, today: clock.nowUtc().toLocal());
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n.transactions.add)),
          body: body,
        );
      },
    );
  }
}

class _TransactionForm extends StatelessWidget {
  const _TransactionForm({required this.state, required this.account, required this.today});

  final TransactionFormState state;
  final AccountEntity account;

  /// Local, read at build: the date field shows today until the user picks a day.
  final DateTime today;

  DateTime get _day => state.pickedDay ?? DateTime(today.year, today.month, today.day);

  /// Transfers arrive with their own flow.
  static const List<TransactionType> _types = <TransactionType>[TransactionType.expense, TransactionType.income];

  Future<void> _pickDate(BuildContext context) async {
    final cubit = context.read<TransactionFormCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      // A planned expense may be dated ahead; a year covers rent and insurance.
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );

    if (picked != null) cubit.dateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final cubit = context.read<TransactionFormCubit>();
    final failure = state.failure;

    return ListView(
      padding: EdgeInsets.all(spacing.md),
      children: <Widget>[
        SegmentedButton<TransactionType>(
          segments: <ButtonSegment<TransactionType>>[
            for (final type in _types) ButtonSegment<TransactionType>(value: type, label: Text(type.labelIn(l10n))),
          ],
          selected: <TransactionType>{state.type},
          showSelectedIcon: false,
          onSelectionChanged: (Set<TransactionType> selected) => cubit.typeChanged(selected.single),
        ),
        SizedBox(height: spacing.md),
        GPMoneyField(
          currencyCode: account.initialBalance.currencyCode,
          initialMinorUnits: state.amountMinorUnits,
          label: l10n.transactions.fieldAmount,
          autofocus: true,
          onChanged: cubit.amountChanged,
        ),
        SizedBox(height: spacing.md),
        DropdownButtonFormField<String>(
          // Keyed by the selection: `initialValue` is read once, and the cubit may move it (an account archived elsewhere).
          key: ValueKey<String>('account-${account.id}'),
          initialValue: account.id,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.transactions.fieldAccount),
          items: <DropdownMenuItem<String>>[
            for (final AccountEntity option in state.accounts!)
              DropdownMenuItem<String>(
                value: option.id,
                child: Text(option.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (String? id) => id == null ? null : cubit.accountChanged(id),
        ),
        SizedBox(height: spacing.md),
        DropdownButtonFormField<String?>(
          key: ValueKey<String>('category-${state.type.name}-${state.categoryId}'),
          initialValue: state.categoryId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.transactions.fieldCategory),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(child: Text(l10n.transactions.uncategorised)),
            for (final CategoryEntity option in state.categoriesForType)
              DropdownMenuItem<String?>(
                value: option.id,
                child: Text(option.displayNameIn(l10n), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: cubit.categoryChanged,
        ),
        SizedBox(height: spacing.md),
        InkWell(
          borderRadius: context.radii.borderMd,
          onTap: () => _pickDate(context),
          child: InputDecorator(
            decoration: InputDecoration(labelText: l10n.transactions.fieldDate, suffixIcon: const Icon(Icons.calendar_today_outlined)),
            child: Text(dayLabel(_day, today: today, l10n: l10n)),
          ),
        ),
        SizedBox(height: spacing.md),
        TextFormField(
          initialValue: state.note,
          inputFormatters: const <TextInputFormatter>[GPUtf16LengthLimitingFormatter(TransactionEntity.noteMaxLength)],
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.transactions.fieldNote),
          onChanged: cubit.noteChanged,
        ),
        if (failure != null) ...<Widget>[
          SizedBox(height: spacing.sm),
          GPFormFailureBanner(message: failure.message(l10n)),
        ],
        SizedBox(height: spacing.lg),
        GPButton(label: l10n.transactions.save, variant: GPButtonVariant.accent, expanded: true, isLoading: state.isSaving, onPressed: cubit.submit),
      ],
    );
  }
}
