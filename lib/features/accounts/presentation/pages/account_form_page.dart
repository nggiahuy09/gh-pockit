import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/account_form_bloc.dart';
import 'account_form_view.dart';

final class AccountFormPage extends StatelessWidget {
  const AccountFormPage({super.key, this.accountId});

  /// Null creates an account.
  final String? accountId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AccountFormBloc(accountId: accountId),
    child: const AccountFormView(),
  );
}
