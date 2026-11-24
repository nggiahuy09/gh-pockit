import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/auth/domain/entities/auth_status.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';

void main() {
  const user = UserEntity(id: 'u-1', email: 'huy@example.com');

  test('statuses of one kind and one user are equal; different kinds never are', () {
    expect(const AuthSignedIn(user), const AuthSignedIn(user));
    expect(const AuthSignedOut(), const AuthSignedOut());
    expect(const AuthSignedOut(), isNot(const AuthLocalOnly()));
    expect(const AuthSignedIn(user), isNot(const AuthSignedIn(UserEntity(id: 'u-2', email: 'huy@example.com'))));
  });

  test('a signed-in status prints the user id, never the email', () {
    expect(const AuthSignedIn(user).toString(), 'AuthSignedIn(u-1)');
  });
}
