import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import 'fake_account_repository.dart';
import 'fake_category_repository.dart';
import 'fake_clock.dart';
import 'fake_transaction_repository.dart';

/// Scoped to the dock: an open tab's name also appears in the app bar.
Finder dockLabel(String label) => find.descendant(of: find.byKey(AppShell.dockKey), matching: find.text(label));

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(dockLabel(label));
  await tester.pumpAndSettle();
}

/// From the Home tab root, in English.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

/// The tab pages resolve from the global locator. The transactions watch never emits, so that tab stays on its skeleton.
void registerShellFakes() {
  getIt
    ..registerSingleton<AccountRepository>(const FakeAccountRepository())
    ..registerSingleton<CategoryRepository>(const FakeCategoryRepository())
    ..registerSingleton<TransactionRepository>(FakeTransactionRepository())
    ..registerSingleton<GPClock>(FakeClock());
}
