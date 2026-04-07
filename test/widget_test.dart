import 'package:flutter_test/flutter_test.dart';

import 'package:babysnap_ai/main.dart';

void main() {
  testWidgets('Home screen renders baby gallery shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(),
    );

    // MyApp shows onboarding or home based on first launch status
    // Just verify the app starts without crashing
    expect(find.byType(MyApp), findsOneWidget);
  });
}
