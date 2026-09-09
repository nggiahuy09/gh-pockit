import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/logging/log_redactor.dart';

void main() {
  group('redactSensitiveFields', () {
    test('keeps the safe fields a log line is actually for', () {
      final result = redactSensitiveFields({
        'entity': 'transaction',
        'id': '0199f2c1-0000-7000-8000-000000000001',
        'errorCode': 'conflict',
        'attempt': 3,
      });

      expect(result, {
        'entity': 'transaction',
        'id': '0199f2c1-0000-7000-8000-000000000001',
        'errorCode': 'conflict',
        'attempt': 3,
      });
    });

    test('redacts money, identity and credentials', () {
      final result = redactSensitiveFields({
        'amountMinor': 1250000,
        'balance': -400,
        'note': 'lunch with Mai',
        'email': 'someone@example.com',
        'accessToken': 'eyJhbGciOi',
      });

      expect(result.values, everyElement(redactedPlaceholder));
      // The keys survive: "the failed mutation had an amount" is useful, the
      // amount is not.
      expect(result.keys, containsAll(<String>['amountMinor', 'balance', 'note', 'email', 'accessToken']));
    });

    test('ignores case and separators in a key', () {
      final result = redactSensitiveFields({
        'AMOUNT_MINOR': 1,
        'refresh-token': 'x',
        'user.email': 'a@b.c',
      });

      expect(result.values, everyElement(redactedPlaceholder));
    });

    test('recurses into nested maps and lists', () {
      final result = redactSensitiveFields({
        'mutation': {
          'id': 'm1',
          'amount': 500,
          'lines': [
            {'note': 'coffee'},
            {'categoryId': 'c1'},
          ],
        },
      });

      final mutation = result['mutation']! as Map<String, Object?>;
      final lines = mutation['lines']! as List<Object?>;

      expect(mutation['id'], 'm1');
      expect(mutation['amount'], redactedPlaceholder);
      expect((lines.first! as Map<String, Object?>)['note'], redactedPlaceholder);
      expect((lines.last! as Map<String, Object?>)['categoryId'], 'c1');
    });

    test('redacts a whole DTO or response body dumped under one key', () {
      final result = redactSensitiveFields({
        'dto': {'anything': 'at all'},
        'responseBody': '{"amount":1}',
      });

      expect(result['dto'], redactedPlaceholder);
      expect(result['responseBody'], redactedPlaceholder);
    });

    test('null and empty collapse to an empty map', () {
      expect(redactSensitiveFields(null), isEmpty);
      expect(redactSensitiveFields(const {}), isEmpty);
    });
  });
}
