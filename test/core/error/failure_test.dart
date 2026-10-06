import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';

/// Every [GPFailure] subtype, by hand: Dart cannot enumerate a sealed class's subtypes at runtime, so a new one must be added here.
const allFailures = <GPFailure>[
  GPNetworkFailure(),
  GPTimeoutFailure(),
  GPAuthenticationFailure(),
  GPAuthorizationFailure(),
  // Every code, not one representative: each maps to its own message.
  GPValidationFailure(GPValidationCode.accountNameEmpty),
  GPValidationFailure(GPValidationCode.accountNameTooLong),
  GPValidationFailure(GPValidationCode.accountHasTransactions),
  GPValidationFailure(GPValidationCode.categoryNameEmpty),
  GPValidationFailure(GPValidationCode.categoryNameTooLong),
  GPValidationFailure(GPValidationCode.transactionAmountNotPositive),
  GPValidationFailure(GPValidationCode.transactionDestinationMissing),
  GPValidationFailure(GPValidationCode.transactionDestinationSameAsSource),
  GPValidationFailure(GPValidationCode.transactionNoteTooLong),
  GPValidationFailure(GPValidationCode.transactionCurrencyMismatch),
  GPValidationFailure(GPValidationCode.transactionTransferCurrenciesDiffer),
  GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch),
  GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4),
  GPNotFoundFailure(),
  GPDatabaseFailure(),
  GPUnknownFailure(),
];

void main() {
  group('GPFailure', () {
    test('fieldless failures compare equal without a hand-written operator', () {
      // Equal through `const` canonicalisation: each is one shared instance.
      expect(const GPNetworkFailure(), const GPNetworkFailure());
      expect(const GPUnknownFailure(), const GPUnknownFailure());
      expect(const GPNetworkFailure(), isNot(const GPTimeoutFailure()));
    });

    test('two failures of different types are never equal', () {
      for (var i = 0; i < allFailures.length; i++) {
        for (var j = 0; j < allFailures.length; j++) {
          if (i == j) continue;
          expect(allFailures[i], isNot(allFailures[j]), reason: '${allFailures[i].runtimeType} must not equal ${allFailures[j].runtimeType}');
        }
      }
    });
  });

  group('GPValidationFailure', () {
    test('every validation code appears in allFailures', () {
      final covered = allFailures.whereType<GPValidationFailure>().map((failure) => failure.code).toSet();

      expect(covered, GPValidationCode.values.toSet());
    });

    test('is equal by value, not by identity', () {
      // Not `const`: canonicalisation would make both one object, leaving `operator ==` untested.
      // ignore: prefer_const_constructors
      final first = GPValidationFailure(GPValidationCode.accountNameEmpty);
      // Same reason as above.
      // ignore: prefer_const_constructors
      final second = GPValidationFailure(GPValidationCode.accountNameEmpty);

      expect(identical(first, second), isFalse);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(const GPValidationFailure(GPValidationCode.accountNameTooLong)));
    });

    test('toString carries the code and nothing else', () {
      expect(const GPValidationFailure(GPValidationCode.accountNameEmpty).toString(), 'GPValidationFailure(code: accountNameEmpty)');
    });
  });

  group('GPConflictFailure', () {
    test('is equal by value, not by identity', () {
      // Not `const`: the resolver builds these at runtime, and canonicalisation would make both one object, leaving `operator ==` untested.
      // ignore: prefer_const_constructors
      final first = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);
      // Same reason as above.
      // ignore: prefer_const_constructors
      final second = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);

      expect(identical(first, second), isFalse);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('differs when any single field differs', () {
      const base = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);

      expect(base, isNot(const GPConflictFailure(entityId: 'tx-2', localVersion: 3, remoteVersion: 4)));
      expect(base, isNot(const GPConflictFailure(entityId: 'tx-1', localVersion: 9, remoteVersion: 4)));
      expect(base, isNot(const GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 9)));
    });

    test('toString carries the id and versions and nothing else', () {
      const failure = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);

      expect(failure.toString(), 'GPConflictFailure(entityId: tx-1, localVersion: 3, remoteVersion: 4)');
    });
  });

  group('GPFailureMessage', () {
    const locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

    for (final locale in locales) {
      group(locale.locale.name, () {
        test('every failure resolves to a non-empty message', () {
          for (final failure in allFailures) {
            expect(failure.message(locale).trim(), isNotEmpty, reason: '${failure.runtimeType} has no message');
          }
        });

        test('no two failures share a message', () {
          final messages = allFailures.map((failure) => failure.message(locale)).toList();

          expect(messages.toSet(), hasLength(messages.length));
        });
      });
    }

    test('English and Vietnamese never return the same string', () {
      for (final failure in allFailures) {
        expect(failure.message(const GPLocaleEn()), isNot(failure.message(const GPLocaleVi())), reason: '${failure.runtimeType} is not translated');
      }
    });

    test('a validation message names the rule that broke, not just "invalid"', () {
      const empty = GPValidationFailure(GPValidationCode.accountNameEmpty);
      const tooLong = GPValidationFailure(GPValidationCode.accountNameTooLong);

      expect(empty.message(const GPLocaleEn()), isNot(tooLong.message(const GPLocaleEn())));
      expect(empty.message(const GPLocaleVi()), isNot(tooLong.message(const GPLocaleVi())));
    });

    test('a validation message carries no limit number', () {
      // The form field shows the limit with a live counter; a number hard-coded in the copy would go stale silently.
      final limits = {
        GPValidationCode.accountNameTooLong: AccountEntity.nameMaxLength,
        GPValidationCode.categoryNameTooLong: CategoryEntity.nameMaxLength,
        GPValidationCode.transactionNoteTooLong: TransactionEntity.noteMaxLength,
      };

      for (final locale in locales) {
        for (final MapEntry(key: code, value: limit) in limits.entries) {
          expect(GPValidationFailure(code).message(locale), isNot(contains('$limit')), reason: '${code.name} (${locale.locale.name})');
        }
      }
    });

    test('a conflict reads the same regardless of which row conflicted', () {
      const first = GPConflictFailure(entityId: 'tx-1', localVersion: 1, remoteVersion: 2);
      const second = GPConflictFailure(entityId: 'acc-9', localVersion: 7, remoteVersion: 8);

      expect(first.message(const GPLocaleEn()), second.message(const GPLocaleEn()));
    });
  });
}
