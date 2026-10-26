import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/clock.dart';
import '../bloc/transaction_form_bloc.dart';
import 'transaction_form_view.dart';

final class TransactionFormPage extends StatelessWidget {
  const TransactionFormPage({super.key, required this.clock, this.transactionId});

  final GPClock clock;

  final String? transactionId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TransactionFormBloc(transactionId: transactionId),
    child: TransactionFormView(clock: clock),
  );
}
