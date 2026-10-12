import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/pop_or_go.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
import 'package:ghpockit/core/widgets/money_field.dart';
import 'package:ghpockit/core/widgets/utf16_length_limit.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/account_form_cubit.dart';

/// Create and edit share one page; the currency is only offered on create (ADR-0010).
class AccountFormPage extends StatelessWidget {
  const AccountFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AccountFormCubit>();

    return BlocConsumer<AccountFormCubit, AccountFormState>(
      listenWhen: (AccountFormState previous, AccountFormState current) => !previous.isSaved && current.isSaved,
      listener: (BuildContext context, AccountFormState state) => context.popOrGoNamed(RouteNames.accounts),
      builder: (BuildContext context, AccountFormState state) {
        final Widget body;
        if (state.isLoading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (cubit.isEditing && state.original == null) {
          // Nothing loaded: the account is gone, or could not be read. The failure says which.
          body = GPEmptyState(icon: const Icon(Icons.error_outline), title: state.failure?.message(l10n) ?? '');
        } else {
          body = _AccountForm(state: state, isEditing: cubit.isEditing);
        }

        return Scaffold(
          appBar: AppBar(title: Text(cubit.isEditing ? l10n.accounts.edit : l10n.accounts.add)),
          body: body,
        );
      },
    );
  }
}

class _AccountForm extends StatelessWidget {
  const _AccountForm({required this.state, required this.isEditing});

  final AccountFormState state;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final cubit = context.read<AccountFormCubit>();
    final failure = state.failure;

    return ListView(
      // Dragging the form puts the keyboard away: the number pad has no Done key.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.all(spacing.md),
      children: <Widget>[
        TextFormField(
          initialValue: state.name,
          inputFormatters: const <TextInputFormatter>[GPUtf16LengthLimitingFormatter(AccountEntity.nameMaxLength)],
          autofocus: !isEditing,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.accounts.fieldName),
          onChanged: cubit.nameChanged,
        ),
        SizedBox(height: spacing.md),
        DropdownButtonFormField<AccountType>(
          initialValue: state.type,
          decoration: InputDecoration(labelText: l10n.accounts.fieldType),
          items: <DropdownMenuItem<AccountType>>[
            for (final type in AccountType.values) DropdownMenuItem<AccountType>(value: type, child: Text(type.labelIn(l10n))),
          ],
          onChanged: (AccountType? type) => type == null ? null : cubit.typeChanged(type),
        ),
        SizedBox(height: spacing.md),
        if (isEditing)
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.accounts.fieldCurrency, helperText: l10n.accounts.currencyFixed, enabled: false),
            child: Text(state.currencyCode),
          )
        else
          DropdownButtonFormField<CurrencyCode>(
            initialValue: CurrencyCode.fromCode(state.currencyCode),
            decoration: InputDecoration(labelText: l10n.accounts.fieldCurrency),
            items: <DropdownMenuItem<CurrencyCode>>[
              for (final currency in CurrencyCode.values) DropdownMenuItem<CurrencyCode>(value: currency, child: Text('${currency.code} (${currency.symbol})')),
            ],
            onChanged: (CurrencyCode? currency) => currency == null ? null : cubit.currencyChanged(currency),
          ),
        SizedBox(height: spacing.md),
        GPMoneyField(
          currencyCode: state.currencyCode,
          initialMinorUnits: state.initialMinorUnits,
          label: l10n.accounts.fieldInitialBalance,
          onChanged: cubit.initialBalanceChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.accounts.owed),
          value: state.isOwed,
          onChanged: (bool isOwed) => cubit.owedChanged(isOwed: isOwed),
        ),
        if (failure != null) ...<Widget>[
          SizedBox(height: spacing.sm),
          GPFormFailureBanner(message: failure.message(l10n)),
        ],
        SizedBox(height: spacing.lg),
        GPButton(label: l10n.accounts.save, expanded: true, isLoading: state.isSaving, onPressed: cubit.submit),
      ],
    );
  }
}
