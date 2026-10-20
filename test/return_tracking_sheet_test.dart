import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buytheway/screens/buyer/buyer_models.dart';
import 'package:buytheway/screens/buyer/orders/return_tracking_sheet.dart';

OrderItem _item(Map<String, dynamic> request) => OrderItem.fromJson({
      'id': '1',
      'name': 'Desk Lamp',
      'quantity': 1,
      'unit_price': 500,
      'returnRequest': {'requestType': 'refund_only', 'reason': 'damaged', 'quantity': 1, 'evidence': <String>[], ...request},
    });

Future<void> _pump(WidgetTester tester, OrderItem item) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReturnTrackingSheet(item: item))));
}

void main() {
  const note = 'The photos show the lamp was used after delivery, which is not covered by our return policy. '
      'Please contact support if you believe this is a mistake.';

  testWidgets('rejected request shows the full resolution note', (tester) async {
    await _pump(tester, _item({'status': 'Rejected', 'resolutionNote': note, 'submittedAt': '2026-10-01T08:00:00Z', 'resolvedAt': '2026-10-02T08:00:00Z'}));
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Reason for rejection'), findsOneWidget);
    expect(find.text(note), findsOneWidget);
    expect(find.text('Declined'), findsOneWidget);
  });

  testWidgets('rejected without a note falls back', (tester) async {
    await _pump(tester, _item({'status': 'Rejected'}));
    expect(find.text('The seller did not leave a reason.'), findsOneWidget);
  });

  testWidgets('pending has no callout; refunded shows the amount', (tester) async {
    await _pump(tester, _item({'status': 'Pending', 'submittedAt': '2026-10-01T08:00:00Z'}));
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Reason for rejection'), findsNothing);

    await _pump(tester, _item({'status': 'Approved', 'refundedAmount': 500}));
    await tester.pump();
    expect(find.text('Refunded'), findsWidgets);
    expect(find.text('Refund amount'), findsOneWidget);
    expect(find.text('₱500.00'), findsOneWidget);
  });
}
