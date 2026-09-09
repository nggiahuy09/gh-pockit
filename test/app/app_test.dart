import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';

void main() {
  testWidgets('GPApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const GPApp());

    expect(find.text('Pockit'), findsOneWidget);
  });
}
