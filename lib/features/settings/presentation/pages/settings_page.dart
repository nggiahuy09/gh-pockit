import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/sample_data_bloc.dart';
import 'settings_view.dart';

final class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.showsDebugTools = kDebugMode});

  final bool showsDebugTools;

  /// Lazy: without the debug tools nothing reads the bloc, so it is never built.
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SampleDataBloc(),
    child: SettingsView(showsDebugTools: showsDebugTools),
  );
}
