import 'package:buytheway/screens/buyer/catalog/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buyer home stays renderable when the viewport shrinks', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 100);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
