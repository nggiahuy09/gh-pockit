import 'package:supabase/supabase.dart';

import '../../domain/entities/user_entity.dart';

extension UserMapper on User {
  /// Null for a user without an email, which this app's email-only sign-up never creates.
  UserEntity? toDomain() {
    final email = this.email;
    if (email == null || email.isEmpty) return null;

    return UserEntity(id: id, email: email);
  }
}
