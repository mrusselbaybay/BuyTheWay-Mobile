import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buytheway/screens/driver/deliveries/failed_attempt_sheet.dart';

void main() {
  Future<void> openSheet(
      WidgetTester tester, void Function((String, String?)?) onResult) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      return TextButton(
          onPressed: () async {
            final result = await showModalBottomSheet<(String, String?)>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FailedAttemptSheet(),
            );
            onResult(result);
          },
          child: const Text('Report failure'));
    }))));
    await tester.tap(find.text('Report failure'));
    await tester.pumpAndSettle();
  }

  testWidgets('requires a reason and trims the required Others description',
      (tester) async {
    (String, String?)? result;
    await openSheet(tester, (value) => result = value);
    expect(
        tester
            .widget<ElevatedButton>(
                find.byWidgetPredicate((widget) => widget is ElevatedButton))
            .onPressed,
        isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Others').last);
    await tester.tap(find.text('Others').last);
    await tester.pumpAndSettle();
    expect(find.text('Describe what happened'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.byWidgetPredicate((widget) => widget is ElevatedButton))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(
                find.byWidgetPredicate((widget) => widget is ElevatedButton))
            .onPressed,
        isNull);
    await tester.enterText(
        find.byType(TextFormField), '  Recipient moved away  ');
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm failed attempt'));
    await tester.tap(find.text('Confirm failed attempt'));
    await tester.pumpAndSettle();
    expect(result, ('others', 'Recipient moved away'));
  });

  testWidgets('submits a predefined reason without a description',
      (tester) async {
    (String, String?)? result;
    await openSheet(tester, (value) => result = value);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recipient not available').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Confirm failed attempt'));
    await tester.pumpAndSettle();
    expect(result, ('recipient_unavailable', null));
  });
}
