import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
final class UserEntity with Equatable {
  const UserEntity({required this.id, required this.email});

  /// The server's uid, and the `owner_id` of the user's rows.
  final String id;

  final String email;

  @override
  List<Object?> get props => [id, email];

  // No email (golden rule 9).
  @override
  String toString() => 'UserEntity(id: $id)';
}
