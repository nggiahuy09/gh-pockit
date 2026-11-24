import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/backend_config_error_app.dart';
import 'package:ghpockit/app/config/backend_config.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';

void main() {
  for (final locale in GPLocale.values) {
    final strings = switch (locale) {
      GPLocale.en => const GPLocaleEn().error,
      GPLocale.vi => const GPLocaleVi().error,
    };

    testWidgets('names the problem under the message, in $locale', (tester) async {
      await tester.pumpWidget(GPBackendConfigErrorApp(locale: locale, problem: GPBackendConfigProblem.flavorMismatch));

      expect(find.text(strings.backendConfigInvalidTitle), findsOneWidget);
      expect(find.text('${strings.backendConfigInvalidBody}\n\nflavorMismatch'), findsOneWidget);
    });
  }
}
