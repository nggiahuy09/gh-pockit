import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/bootstrap.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/features/categories/presentation/widgets/category_icon_widget.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_view.dart';
import 'package:ghpockit/features/transactions/presentation/widgets/transaction_list_widget.dart';
import 'package:integration_test/integration_test.dart';

const _flings = 30;

const _frameBudget = Duration(microseconds: 16667);

// How long after a new snapshot a frame's build may start and still be counted as that snapshot's frame.
const _snapshotReach = Duration(milliseconds: 50);

// A fixed wait, not `pumpAndSettle`: in the live app something always has a frame scheduled, so it never settles. Long enough for a fling to stop.
const _settle = Duration(milliseconds: 1500);

/// The device tier of the harness (ADR-0026): a profile build on a phone, with `--dart-define=DATASET`. How to run it: docs/benchmarks/README.md.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Frames come from the app and the engine, as they would for a user; `pump` only waits.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('Home, then the transaction list: time to data, then frames over a long scroll', (tester) async {
    expect(benchmarkDatasetSize, isNotNull, reason: 'run with --dart-define=DATASET=1k|10k|50k');
    final flutterOnError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    addTearDown(() => PlatformDispatcher.instance.onError = platformOnError);

    final stopwatch = Stopwatch()..start();
    await bootstrap(GPApp.new);
    // bootstrap's handler forwards to the test's own, which the binding expects back before the test ends.
    FlutterError.onError = flutterOnError;
    await _pumpUntilFound(tester, find.byType(CategoryIconWidget));
    final homeDataMillis = stopwatch.elapsedMilliseconds;

    stopwatch.reset();
    await tester.tap(find.descendant(of: find.byKey(AppShell.dockKey), matching: find.byIcon(Icons.swap_vert_outlined)));
    await _pumpUntilFound(tester, find.byType(TransactionRowWidget));
    final firstRowsMillis = stopwatch.elapsedMilliseconds;
    await tester.pump(_settle);

    // Every frame and every new window, both on the `Timeline.now` clock, so a slow frame can be matched to the snapshot that preceded it.
    final snapshots = <({int atMicros, int rows})>[];
    final listBloc = tester.element(find.byType(TransactionsView)).read<TransactionListBloc>();
    final subscription = listBloc.stream.listen((state) {
      if (state is TransactionListLoadedState) snapshots.add((atMicros: Timeline.now, rows: state.snapshot.items.length));
    });
    final frames = <FrameTiming>[];
    final TimingsCallback onTimings = frames.addAll;
    binding.addTimingsCallback(onTimings);

    await binding.watchPerformance(() async {
      for (var i = 0; i < _flings; i++) {
        await tester.fling(find.descendant(of: find.byType(TransactionsView), matching: find.byType(CustomScrollView)), const Offset(0, -1500), 5000);
        await tester.pump(_settle);
      }
    }, reportKey: 'transactions_scroll');

    final clockLeadMillis = (Timeline.now - frames.last.timestampInMicroseconds(FramePhase.rasterFinish)) ~/ 1000;
    binding.removeTimingsCallback(onTimings);
    await subscription.cancel();
    final slowFrames = [
      for (final frame in frames)
        if (frame.buildDuration > _frameBudget) frame,
    ];
    final afterSnapshot = [
      for (final frame in slowFrames)
        if (_snapshotBefore(frame, snapshots) case final snapshot?) {'rows': snapshot.rows, 'build_ms': frame.buildDuration.inMicroseconds / 1000},
    ];

    binding.reportData = {
      ...?binding.reportData,
      'dataset': benchmarkDatasetSize?.key,
      'home_data_ms': homeDataMillis,
      'transactions_first_rows_ms': firstRowsMillis,
      'list_snapshots': snapshots.length,
      'list_rows_at_end': snapshots.lastOrNull?.rows,
      'slow_build_frames': slowFrames.length,
      'slow_build_frames_after_a_snapshot': afterSnapshot.length,
      'slow_build_frames_after_a_snapshot_detail': afterSnapshot,
      // From the last frame's raster end to now. Small and positive means the two clocks agree, which the matching above relies on.
      'clock_lead_ms': clockLeadMillis,
    };
  });
}

/// The newest snapshot taken within [_snapshotReach] before [frame] began to build.
({int atMicros, int rows})? _snapshotBefore(FrameTiming frame, List<({int atMicros, int rows})> snapshots) {
  final buildStart = frame.timestampInMicroseconds(FramePhase.buildStart);

  return snapshots.where((snapshot) => snapshot.atMicros <= buildStart && buildStart - snapshot.atMicros <= _snapshotReach.inMicroseconds).lastOrNull;
}

/// Waits in real time while the app renders on its own, so the time read after it is the user's, to within a few milliseconds.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(minutes: 1));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) throw TestFailure('nothing matched $finder within a minute');
    await tester.pump(const Duration(milliseconds: 4));
  }
}
