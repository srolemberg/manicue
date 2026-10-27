import 'package:flutter_test/flutter_test.dart';
import 'package:manicue/my_app.dart';

void main() {
  testWidgets('iCUE Dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the dashboard title and session card are displayed.
    expect(find.text('iCUE SDK Integration Dashboard'), findsOneWidget);
    expect(find.text('Informações da Sessão'), findsOneWidget);
  });
}
