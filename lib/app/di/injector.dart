import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:get_it/get_it.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/logging/developer_logger.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';

/// The app-wide service locator.
///
/// Only `app/bootstrap.dart`, the `configure*Dependencies()` functions and widget-tree entry points are allowed to touch it. A BLoC receives its
/// dependencies through its constructor and never calls `getIt<...>()` itself — otherwise the dependency graph stops being visible in the code and every
/// BLoC test needs a configured locator.
final GetIt getIt = GetIt.instance;

/// Registers the dependencies that belong to no single feature.
///
/// Registration is split per module (`configureCoreDependencies`, `configureAuthDependencies`, …) as in the blueprint, so a module can be
/// registered in isolation in a test instead of booting the whole graph.
///
/// Everything here is a `lazySingleton`: created on first resolve, then shared. Eager construction at startup would put database and network setup
/// on the critical path to the first frame for no reason.
///
/// [container] exists for tests: passing a fresh `GetIt()` keeps a test from mutating the global instance and leaking into the next one.
void configureCoreDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<GPClock>(GPSystemClock.new)
    // Singleton, not a factory: `v7()` carries a counter that keeps IDs created in the same millisecond in order, and that only holds if the
    // whole app shares one generator.
    ..registerLazySingleton<GPUuidGenerator>(() => GPUuidGeneratorImpl(clock: c<GPClock>()))
    ..registerLazySingleton<GPAppLogger>(
      // Debug lines are useful while developing and are noise (and a leak risk) in a shipped build, so the filter is set once, here.
      () => GPDeveloperLogger(clock: c<GPClock>(), minLevel: kReleaseMode ? GPLogLevel.info : GPLogLevel.debug),
    );
}
