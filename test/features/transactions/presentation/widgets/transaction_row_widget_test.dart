import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/widgets/money_text.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_item.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_sync_status.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/widgets/transaction_list_widget.dart';

import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/results.dart';

void main() {
  Future<void> pumpRow(WidgetTester tester, TransactionSyncStatus status, {GPLocale locale = GPLocale.vi}) async {
    final localization = await localizationFor(locale);
    await tester.pumpWidget(
      localizedHarness(
        localization: localization,
        child: Scaffold(body: TransactionRowWidget(item: _item(status))),
      ),
    );
  }

  group('the sync badge (ADR-0045)', () {
    testWidgets('a write waiting for its push shows it, and a screen reader says so', (tester) async {
      await pumpRow(tester, TransactionSyncStatus.pending);

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Chưa đồng bộ')), findsOneWidget);
    });

    testWidgets('the label follows the language', (tester) async {
      await pumpRow(tester, TransactionSyncStatus.pending, locale: GPLocale.en);

      expect(find.bySemanticsLabel(RegExp('Not synced yet')), findsOneWidget);
    });

    for (final status in [TransactionSyncStatus.synced, TransactionSyncStatus.localOnly]) {
      testWidgets('${status.name} shows no badge', (tester) async {
        await pumpRow(tester, status);

        expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
      });
    }

    testWidgets('the badge does not push the amount off a narrow row at a large text size', (tester) async {
      tester.view
        ..physicalSize = const Size(320.0, 640.0)
        ..devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpRow(tester, TransactionSyncStatus.pending);

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(GPMoneyText)).right, lessThanOrEqualTo(320.0));
    });
  });
}

TransactionListItem _item(TransactionSyncStatus status) => TransactionListItem(
  transaction: okValue(
    TransactionEntity.create(
      amount: Money(125000, 'VND'),
      type: TransactionType.expense,
      createdAt: DateTime.utc(2026, 11, 27, 3),
      occurredAt: DateTime.utc(2026, 11, 27, 3),
      updatedAt: DateTime.utc(2026, 11, 27, 3),
      accountId: 'acc-cash',
      id: 'tx-1',
      note: 'Phở bò với cả một ghi chú dài đủ để chiếm hết chỗ trên một dòng hẹp',
      syncStatus: status,
    ),
  ),
  category: null,
  accountName: 'Ví tiền mặt có một cái tên cũng rất dài',
);
