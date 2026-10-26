import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/pop_or_go.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/money/currency_code.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/field.dart';
import '../../../../core/widgets/form_failure_banner.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/select.dart';
import '../../../../core/widgets/switch.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../../core/widgets/utf16_length_limit.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/account_type.dart';
import '../account_form_field_enum.dart';
import '../account_type_extension.dart';
import '../bloc/account_form_bloc.dart';

/// Create and edit share one view; the currency is only offered on create (ADR-0010).
final class AccountFormView extends StatelessWidget {
  const AccountFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.accounts;

    return BlocConsumer<AccountFormBloc, AccountFormState>(
      listenWhen: (prev, next) => !prev.isSaved && next.isSaved,
      listener: (_, _) => context.popOrGoNamed(RouteNames.accounts),
      builder: (_, state) => Scaffold(
        appBar: AppBar(title: Text(state.isEditing ? viewLocale.edit : viewLocale.add)),
        body: switch (state) {
          AccountFormState(isLoading: true) => const Center(child: CircularProgressIndicator()),
          // Nothing loaded: the account is gone, or could not be read. The failure says which.
          AccountFormState(isEditing: true, original: null) => GPEmptyState(icon: const Icon(Icons.error_outline), title: state.failure?.getMessage(locale) ?? ''),
          AccountFormState() => _AccountForm(state: state),
        },
      ),
    );
  }
}

final class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.state});

  final AccountFormState state;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

final class _AccountFormState extends State<_AccountForm> {
  final _nameFocus = FocusNode(debugLabel: 'name');

  @override
  void dispose() {
    _nameFocus.dispose();
    super.dispose();
  }

  void _handleFailure(AccountFormState state) {
    // A refused name takes focus back: the keyboard may be down, and a screen reader then reads its error (ADR-0016).
    if (state.failedField == AccountFormField.name) _nameFocus.requestFocus();
  }

  void _handleNameChange(String name) => context.read<AccountFormBloc>().add(AccountFormNameChangeEvent(name));

  void _handleTypeChange(AccountType type) => context.read<AccountFormBloc>().add(AccountFormTypeChangeEvent(type));

  void _handleCurrencyChange(CurrencyCode currency) => context.read<AccountFormBloc>().add(AccountFormCurrencyChangeEvent(currency));

  void _handleInitialBalanceChange(int? minorUnits) => context.read<AccountFormBloc>().add(AccountFormInitialBalanceChangeEvent(minorUnits));

  void _handleOwedChange(bool isOwed) => context.read<AccountFormBloc>().add(AccountFormOwedChangeEvent(isOwed));

  void _handleSubmit() => context.read<AccountFormBloc>().add(const AccountFormSubmitEvent());

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.accounts;
    final spacing = context.spacing;
    final state = widget.state;
    final failure = state.failure;
    final failedField = state.failedField;

    return BlocListener<AccountFormBloc, AccountFormState>(
      listenWhen: (prev, next) => next.failure != null && next.failure != prev.failure,
      listener: (_, state) => _handleFailure(state),
      child: ListView(
        // Dragging the form puts the keyboard away: the number pad has no Done key.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(spacing.md),
        children: [
          GPTextField(
            inputFormatters: const [GPUtf16LengthLimitingFormatter(AccountEntity.nameMaxLength)],
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.sentences,
            errorText: failedField == AccountFormField.name ? failure?.getMessage(locale) : null,
            initialValue: state.name,
            label: viewLocale.fieldName,
            autofocus: !state.isEditing,
            onChanged: _handleNameChange,
          ),
          SizedBox(height: spacing.md),
          GPSelect<AccountType>(
            options: [for (final type in AccountType.values) GPSelectOption(icon: type.icon, value: type, label: type.getTitle(locale))],
            value: state.type,
            label: viewLocale.fieldType,
            onChanged: _handleTypeChange,
          ),
          SizedBox(height: spacing.md),
          if (state.isEditing)
            GPPickerField(leading: Icons.payments_outlined, helperText: viewLocale.currencyFixed, label: viewLocale.fieldCurrency, value: state.currencyCode, onTap: null)
          else
            GPSelect<CurrencyCode>(
              options: [
                for (final currency in CurrencyCode.values) GPSelectOption(icon: Icons.payments_outlined, value: currency, label: '${currency.code} (${currency.symbol})'),
              ],
              value: CurrencyCode.fromCode(state.currencyCode),
              label: viewLocale.fieldCurrency,
              onChanged: _handleCurrencyChange,
            ),
          SizedBox(height: spacing.md),
          GPMoneyField(currencyCode: state.currencyCode, label: viewLocale.fieldInitialBalance, initialMinorUnits: state.initialMinorUnits, onChanged: _handleInitialBalanceChange),
          SizedBox(height: spacing.sm),
          GPSwitchRow(title: viewLocale.owed, value: state.isOwed, onChanged: _handleOwedChange),
          // Only a failure no field owns: a conflict, a row gone meanwhile, a read failure.
          if (failure != null && failedField == null) ...[
            SizedBox(height: spacing.sm),
            GPFormFailureBanner(message: failure.getMessage(locale)),
          ],
          SizedBox(height: spacing.lg),
          GPButton(label: viewLocale.save, expanded: true, isLoading: state.isSaving, onPressed: _handleSubmit),
        ],
      ),
    );
  }
}
