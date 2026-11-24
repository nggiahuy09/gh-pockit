import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/auth/data/mapper/user_mapper.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:supabase/supabase.dart';

User _user({String? email}) => User(id: 'u-1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', email: email, createdAt: '2026-11-15T09:00:00Z');

void main() {
  test('maps the id and the email', () {
    expect(_user(email: 'huy@example.com').toDomain(), const UserEntity(id: 'u-1', email: 'huy@example.com'));
  });

  test('a user without an email maps to null', () {
    expect(_user().toDomain(), isNull);
    expect(_user(email: '').toDomain(), isNull);
  });
}
