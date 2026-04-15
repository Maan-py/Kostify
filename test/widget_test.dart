// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:kostify/main.dart';

void main() {
  testWidgets('Kostify app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const KostifyApp());

    // Verify splash screen muncul
    expect(find.text('Kostify'), findsOneWidget);
  });
}
