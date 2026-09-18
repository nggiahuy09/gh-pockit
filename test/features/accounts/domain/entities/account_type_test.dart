import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

/// The stored vocabulary of `accounts.type`, pinned.
///
/// This file exists because the strings below are *data*, not code. `accounts_table.dart` refuses drift's `textEnum` precisely so that a rename cannot
/// silently orphan every existing row — and that refusal only pays off if something fails when the vocabulary changes. This is that something.
void main() {
  test('the stored vocabulary is exactly these five strings', () {
    // Change a value here and every row written by a previous build stops matching. If this test has to be edited, a migration has to be written.
    expect(
      {for (final type in AccountType.values) type.name: type.storageValue},
      {'cash': 'cash', 'bank': 'bank', 'eWallet': 'e_wallet', 'creditCard': 'credit_card', 'other': 'other'},
    );
  });

  test('covers the five types the blueprint lists', () {
    expect(AccountType.values, hasLength(5));
  });

  test('no two types share a storage value', () {
    // A duplicate would make `fromStorage` return whichever came first in `values`, turning one type into another on the next read.
    expect(AccountType.values.map((type) => type.storageValue).toSet(), hasLength(AccountType.values.length));
  });

  test('fromStorage round-trips every value', () {
    for (final type in AccountType.values) {
      expect(AccountType.fromStorage(type.storageValue), type, reason: '${type.name} does not survive a round trip');
    }
  });

  test('fromStorage returns null for an unknown value rather than falling back', () {
    // Falling back to `other` would hide a corrupt row and then write the fallback back on the next edit, destroying the original value. The mapper at
    // T6 turns this null into a GPDatabaseFailure, which is what a row it cannot read actually is.
    expect(AccountType.fromStorage('savings'), isNull);
    expect(AccountType.fromStorage(''), isNull);
    // The Dart name is not the stored value, and asking for one must not find the other.
    expect(AccountType.fromStorage('eWallet'), isNull);
  });
}
