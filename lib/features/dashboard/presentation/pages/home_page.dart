import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_accounts_bloc.dart';
import 'home_view.dart';

final class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => HomeAccountsBloc(), child: const HomeView());
}
