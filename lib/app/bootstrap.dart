import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/logging/app_logger.dart';

/// Single startup path for every flavor and entry point.
///
/// The order matters: DI is configured before [builder] runs, so a widget can resolve a dependency in its constructor, and the error handlers are
/// installed before `runApp` so a crash during the first frame is still reported.
///
/// `runZonedGuarded` is intentionally absent. `PlatformDispatcher.onError` covers uncaught async errors on current Flutter and does not require every
/// error to travel through one zone — which matters once background isolates (Drift's, `workmanager`'s) enter the picture in P2/P4.
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  configureCoreDependencies();
  final logger = getIt<GPAppLogger>();

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(
      'uncaught flutter error',
      fields: {'library': details.library},
      error: details.exception,
      stackTrace: details.stack,
    );
    previousOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.error('uncaught async error', error: error, stackTrace: stack);
    // `true` = handled; returning false would re-report it to the platform and duplicate every line once Sentry is wired in P7.
    return true;
  };

  // Resolved before the first frame so the app never paints English and then flips to Vietnamese.
  await getIt<GPLocalization>().init(deviceLocale: PlatformDispatcher.instance.locale);

  logger.info('app bootstrapped');
  runApp(builder());
}
