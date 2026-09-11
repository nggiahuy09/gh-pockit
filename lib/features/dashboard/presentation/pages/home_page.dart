import 'package:flutter/material.dart';

/// Placeholder for the dashboard (total balance, monthly income/expense, recent transactions — blueprint §7.1). Filled in at W6 flex, once
/// `watchAccountBalances()` exists; there is nothing to show before the aggregate queries land.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home')),
    body: const Center(child: Text('Home')),
  );
}
