import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cftk/pages/isentropic_flow.dart';

void main() {
  testWidgets('Gas selection and manual gamma input test', (WidgetTester tester) async {
    // 1. Build the widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IsentropicFlowScreen(),
        ),
      ),
    );

    // Verify default state (Air, gamma = 1.4)
    expect(find.text('Air'), findsOneWidget);
    final gammaFieldFinder = find.byType(TextField).first;
    expect(tester.widget<TextField>(gammaFieldFinder).controller?.text, '1.4');

    // 2. Open dropdown and select Helium (gamma = 1.67)
    await tester.tap(find.text('Air'));
    await tester.pumpAndSettle();

    // Tap Helium in the bottom sheet
    final heliumItemFinder = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text('Helium'),
    );
    expect(heliumItemFinder, findsOneWidget);
    await tester.tap(heliumItemFinder);
    await tester.pumpAndSettle();

    // Verify display name is Helium and gamma is 1.67
    expect(find.text('Helium'), findsOneWidget);
    expect(tester.widget<TextField>(gammaFieldFinder).controller?.text, '1.67');

    // 3. Open dropdown again and select Argon (gamma = 1.67)
    await tester.tap(find.text('Helium'));
    await tester.pumpAndSettle();

    // Tap Argon in the bottom sheet
    final argonItemFinder = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text('Argon'),
    );
    expect(argonItemFinder, findsOneWidget);
    await tester.tap(argonItemFinder);
    await tester.pumpAndSettle();

    // Verify display name is Argon and gamma is 1.67
    expect(find.text('Argon'), findsOneWidget);
    expect(tester.widget<TextField>(gammaFieldFinder).controller?.text, '1.67');

    // 4. Manually edit gamma to 1.3
    await tester.enterText(gammaFieldFinder, '1.3');
    await tester.pumpAndSettle();

    // Ammonia is the first gas in the list with gamma = 1.3, so it should display Ammonia
    expect(find.text('Ammonia'), findsOneWidget);
    expect(find.text('CO₂'), findsNothing); // CO₂ also has gamma = 1.3 but should not display

    // 5. Open dropdown and select CO₂ (gamma = 1.3)
    await tester.tap(find.text('Ammonia'));
    await tester.pumpAndSettle();

    final co2ItemFinder = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text('CO₂'),
    );
    expect(co2ItemFinder, findsOneWidget);
    await tester.tap(co2ItemFinder);
    await tester.pumpAndSettle();

    // Verify display name is CO₂
    expect(find.text('CO₂'), findsOneWidget);
    expect(find.text('Ammonia'), findsNothing);

    // 6. Manually edit gamma to 1.5 (non-matching)
    await tester.enterText(gammaFieldFinder, '1.5');
    await tester.pumpAndSettle();

    // Should display "Other"
    expect(find.text('Other'), findsOneWidget);

    // 7. Manually edit gamma to 2.0
    await tester.enterText(gammaFieldFinder, '2.0');
    await tester.pumpAndSettle();

    // Should display "Other"
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('Disallow spaces in input fields test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IsentropicFlowScreen(),
        ),
      ),
    );

    final fields = find.byType(TextField);
    final machFieldFinder = fields.at(1);

    await tester.tap(machFieldFinder);
    await tester.pumpAndSettle();
    
    // 1. Simulate typing a space after '1' (increment by 1 char, which is whitespace)
    // This should be rejected by the formatter
    await tester.enterText(machFieldFinder, '1 ');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(machFieldFinder).controller?.text, '1');

    // 2. Simulate pasting '0.    5' (multi-character insertion containing whitespace)
    // This should be allowed by the formatter to show the error
    await tester.enterText(machFieldFinder, '0.    5');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(machFieldFinder).controller?.text, '0.    5');

    // Verify "Invalid expression" is displayed
    expect(find.text('Invalid expression'), findsOneWidget);
  });
}
