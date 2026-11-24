import 'package:flutter/material.dart';

import '../core/localization/locale.dart';
import 'config/backend_config.dart';
import 'startup_error_app.dart';

/// Names the problem on screen: iOS shows no app log (ADR-0038).
final class GPBackendConfigErrorApp extends StatelessWidget {
  const GPBackendConfigErrorApp({super.key, required this.locale, required this.problem});

  final GPLocale locale;
  final GPBackendConfigProblem problem;

  @override
  Widget build(BuildContext context) => GPStartupErrorApp(
    icon: Icons.settings_suggest_outlined,
    locale: locale,
    message: (strings) => '${strings.error.backendConfigInvalidBody}\n\n${problem.name}',
    title: (strings) => strings.error.backendConfigInvalidTitle,
  );
}
