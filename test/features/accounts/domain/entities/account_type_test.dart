import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

void main() {
  test('the stored vocabulary is exactly these five strings', () {
    // Editing this map means writing a migration.
    expect(
      {for (final type in AccountType.values) type.name: type.storageValue},
      {'cash': 'cash', 'bank': 'bank', 'eWallet': 'e_wallet', 'creditCard': 'credit_card', 'other': 'other'},
    );
  });

  test('covers the five types the blueprint lists', () {
    expect(AccountType.values, hasLength(5));
  });

  test('no two types share a storage value', () {
    expect(AccountType.values.map((type) => type.storageValue).toSet(), hasLength(AccountType.values.length));
  });

  test('fromStorage round-trips every value', () {
    for (final type in AccountType.values) {
      expect(AccountType.fromStorage(type.storageValue), type, reason: '${type.name} does not survive a round trip');
    }
  });

  test('fromStorage returns null for an unknown value rather than falling back', () {
    expect(AccountType.fromStorage('savings'), isNull);
    expect(AccountType.fromStorage(''), isNull);
    expect(AccountType.fromStorage('eWallet'), isNull);
  });
}
