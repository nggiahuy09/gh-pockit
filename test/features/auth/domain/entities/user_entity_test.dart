import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';

void main() {
  const user = UserEntity(id: 'u-1', email: 'huy@example.com');

  test('two users with the same id and email are equal', () {
    expect(user, const UserEntity(id: 'u-1', email: 'huy@example.com'));
    expect(user, isNot(const UserEntity(id: 'u-1', email: 'other@example.com')));
  });

  test('toString prints the id and never the email', () {
    expect(user.toString(), 'UserEntity(id: u-1)');
  });
}
