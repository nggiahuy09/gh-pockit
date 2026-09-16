import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/localization/drift_locale_store.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/logging/developer_logger.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';

void main() {
  group('configureCoreDependencies', () {
    late GetIt container;

    setUp(() {
      // A private container, never `GetIt.instance`: a test that registered
      // into the global locator would leak into whichever test ran next.
      container = GetIt.asNewInstance();
      configureCoreDependencies(container: container);
    });

    tearDown(() => container.reset());

    test('registers the three core abstractions', () {
      expect(container<GPClock>(), isA<GPSystemClock>());
      expect(container<GPUuidGenerator>(), isA<GPUuidGeneratorImpl>());
      expect(container<GPAppLogger>(), isA<GPDeveloperLogger>());
    });

    test('resolves each one as a singleton', () {
      expect(container<GPClock>(), same(container<GPClock>()));
      expect(container<GPUuidGenerator>(), same(container<GPUuidGenerator>()));
      expect(container<GPAppLogger>(), same(container<GPAppLogger>()));
    });

    test('registers against the interface, not the implementation', () {
      // The point of the whole exercise: app code depends on `GPClock`, so a
      // test can swap in a fake. If these were registered as `GPSystemClock`,
      // callers would have to name the concrete type to resolve them.
      expect(container.isRegistered<GPClock>(), isTrue);
      expect(container.isRegistered<GPSystemClock>(), isFalse);
      expect(container.isRegistered<GPUuidGenerator>(), isTrue);
      expect(container.isRegistered<GPUuidGeneratorImpl>(), isFalse);
    });

    test('wires the logger to the registered GPClock', () {
      // Resolving the logger is what triggers its factory, which resolves
      // `GPClock` from the same container — the one dependency edge in the core
      // graph today. If it were wired to `DateTime.now()` instead, nothing
      // here would fail, which is exactly why the edge is asserted.
      container<GPAppLogger>().info('probe');

      expect(container<GPClock>(), isA<GPSystemClock>());
    });

    test('binds the locale store to Drift, not to the in-memory one', () async {
      // The W1 debt ADR-0004 left open: with `GPInMemoryLocaleStore` bound, a chosen language did not survive a restart. Asserted on the container rather
      // than trusted to the one-line swap, because nothing else in the app would fail if that line were reverted — the symptom is a setting quietly
      // forgetting itself between launches, which no other test would notice.
      //
      // The database is swapped for an in-memory one first: the production registration reaches `path_provider` for a file path, and a plain unit test has
      // no platform side to answer it. Swapping it is possible at all because every registration here is lazy — the store resolves the database when it is
      // first asked for rather than when it is registered, which is the same property that keeps sqlite setup off the path to the first frame.
      await container.unregister<GPAppDatabase>();
      container.registerLazySingleton<GPAppDatabase>(() => GPAppDatabase.forTesting(NativeDatabase.memory()), dispose: (db) => db.close());

      expect(container<GPLocaleStore>(), isA<GPDriftLocaleStore>());
      // Against the interface, like every other registration here, so a test can still substitute the in-memory store.
      expect(container.isRegistered<GPLocaleStore>(), isTrue);
      expect(container.isRegistered<GPDriftLocaleStore>(), isFalse);
    });

    test('a reset container can be configured again', () async {
      // Guards the bootstrap-twice case (hot restart, an integration test that
      // reboots the app): get_it throws on a duplicate registration, so the
      // reset has to be enough to start over.
      await container.reset();

      expect(() => configureCoreDependencies(container: container), returnsNormally);
      expect(container<GPClock>(), isA<GPSystemClock>());
    });

    test('defaults to the global locator when no container is given', () {
      configureCoreDependencies();
      addTearDown(() async {
        await getIt.reset();
      });

      expect(getIt<GPClock>(), isA<GPSystemClock>());
    });
  });
}
