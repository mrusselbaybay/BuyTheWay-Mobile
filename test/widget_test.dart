import 'package:buytheway/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BuyTheWay app boots to its branded splash screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'BuyTheWay');
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
