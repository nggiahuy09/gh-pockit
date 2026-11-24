import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/sign_out_bloc.dart';
import '../bloc/sample_data_bloc.dart';
import 'settings_view.dart';

final class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.showsDebugTools = kDebugMode});

  final bool showsDebugTools;

  /// Lazy: without the debug tools nothing reads the sample bloc, so it is never built.
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => SampleDataBloc()),
      BlocProvider(create: (_) => SignOutBloc()),
    ],
    child: SettingsView(showsDebugTools: showsDebugTools),
  );
}
