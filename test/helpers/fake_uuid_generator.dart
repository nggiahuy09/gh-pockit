import 'package:ghpockit/core/utils/uuid_generator.dart';

/// Predictable ids, so a test can name the id a write is about to mint. [v5] stays derived from the name, as the category seeder relies on.
class FakeUuidGenerator extends GPUuidGenerator {
  FakeUuidGenerator({this.prefix = 'id'});

  final String prefix;

  int _v7Count = 0;
  int _v4Count = 0;

  final List<String> issuedV7 = <String>[];

  @override
  String v4() => '$prefix-v4-${++_v4Count}';

  @override
  String v5(String name) => '$prefix-v5-$name';

  @override
  String v7() {
    final id = '$prefix-v7-${++_v7Count}';
    issuedV7.add(id);

    return id;
  }
}
