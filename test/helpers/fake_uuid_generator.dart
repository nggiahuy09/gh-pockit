import 'package:ghpockit/core/utils/uuid_generator.dart';

/// Predictable ids, so a test can name the id a write is about to mint. [v5] stays derived from the name, as the category seeder relies on.
final class FakeUuidGenerator extends GPUuidGenerator {
  FakeUuidGenerator([this.prefix = 'id']);

  final List<String> _issuedV7 = [];
  final String prefix;

  var _v4Count = 0;
  var _v7Count = 0;

  List<String> get issuedV7 => List.unmodifiable(_issuedV7);

  @override
  String v4() => '$prefix-v4-${++_v4Count}';

  @override
  String v5(String name) => '$prefix-v5-$name';

  @override
  String v7() {
    final id = '$prefix-v7-${++_v7Count}';
    _issuedV7.add(id);

    return id;
  }
}
