import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/clock.dart';
import '../bloc/transaction_deletion_bloc.dart';
import '../bloc/transaction_list_bloc.dart';
import 'transactions_view.dart';

final class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key, required this.clock});

  final GPClock clock;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => TransactionListBloc()),
      BlocProvider(create: (_) => TransactionDeletionBloc()),
    ],
    child: TransactionsView(clock: clock),
  );
}
