import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/database_error_app.dart';
import 'package:ghpockit/core/database/database_too_new_exception.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';

void main() {
  // Nothing is registered in `getIt` here: the screen runs when the bootstrap stopped before the database was usable.
  const tooNew = GPDatabaseTooNewException(fileVersion: 6, appVersion: 5);
  final stepFailed = ArgumentError.value('Unknown migration from 5');

  for (final locale in GPLocale.values) {
    final strings = switch (locale) {
      GPLocale.en => const GPLocaleEn().error,
      GPLocale.vi => const GPLocaleVi().error,
    };

    testWidgets('a newer file asks for an update, in $locale', (tester) async {
      await tester.pumpWidget(GPDatabaseErrorApp(error: tooNew, locale: locale));

      expect(find.text(strings.databaseTooNewTitle), findsOneWidget);
      expect(find.text(strings.databaseTooNewBody), findsOneWidget);
      expect(find.byIcon(Icons.system_update_outlined), findsOneWidget);
    });

    testWidgets('any other failure says the data is still there, in $locale', (tester) async {
      await tester.pumpWidget(GPDatabaseErrorApp(error: stepFailed, locale: locale));

      expect(find.text(strings.databaseOpenFailedTitle), findsOneWidget);
      expect(find.text(strings.databaseOpenFailedBody), findsOneWidget);
      expect(find.text(strings.databaseTooNewTitle), findsNothing);
    });
  }
}
