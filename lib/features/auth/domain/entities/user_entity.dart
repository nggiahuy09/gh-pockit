import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
final class UserEntity with Equatable {
  const UserEntity({required this.id, required this.email});

  /// The server's uid: the `owner_id` of every row this user syncs.
  final String id;

  final String email;

  @override
  List<Object?> get props => [id, email];

  // No email: a log line or a failed `expect` must not print it (golden rule 9).
  @override
  String toString() => 'UserEntity(id: $id)';
}
