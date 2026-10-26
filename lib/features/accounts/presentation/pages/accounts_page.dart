import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/accounts_bloc.dart';
import 'accounts_view.dart';

final class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => AccountsBloc(), child: const AccountsView());
}
