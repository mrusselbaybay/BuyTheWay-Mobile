import 'dart:convert';
import 'dart:typed_data';

import 'package:buytheway/screens/remittances/remittance_format.dart';
import 'package:buytheway/screens/remittances/remittances_screen.dart';
import 'package:buytheway/services/api_service.dart';
import 'package:buytheway/services/remittance_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('converts peso input to exact cents and rejects ambiguous amounts', () {
    expect(parseRemittancePesos('100.01'), 10001);
    expect(parseRemittancePesos('0.10'), 10);
    expect(parseRemittancePesos('50'), 5000);
    for (final value in ['1.001', '-1', '1e4', '1,000', '', 'NaN']) {
      expect(parseRemittancePesos(value), isNull);
    }
    expect(remittanceMoney('123456'), '₱1,234.56');
  });

  test('submits COD proof to the seller endpoint without claiming verification',
      () async {
    final api = RemittanceApiService(
        accessToken: 'courier-token',
        role: RemittanceRole.courier,
        client: MockClient((request) async {
          expect(request.url.path, '/api/courier/remittances/cod');
          expect(request.headers['Authorization'], 'Bearer courier-token');
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'collection_id': 'collection',
            'reference': 'GC123',
            'proof_path': 'owned/proof.png'
          });
          return http.Response(
              jsonEncode({
                'data': {'status': 'awaiting_verification'}
              }),
              201);
        }));
    addTearDown(api.close);
    await api.submitCod(
        collectionId: 'collection',
        reference: 'GC123',
        proofPath: 'owned/proof.png');
  });

  test('preserves server duplicate-reference validation errors', () async {
    final api = RemittanceApiService(
        accessToken: 'token',
        role: RemittanceRole.courier,
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'message': 'Invalid',
              'errors': {
                'reference': ['This reference was already submitted.']
              }
            }),
            422)));
    addTearDown(api.close);
    await expectLater(
        api.submitCod(
            collectionId: 'c', reference: 'duplicate', proofPath: 'p'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'This reference was already submitted.')));
  });

  test('uploads a single canonical proof using the expected multipart field',
      () async {
    final api = RemittanceApiService(
        accessToken: 'token',
        role: RemittanceRole.courier,
        client: MockClient((request) async {
          expect(request.url.path, '/api/courier/remittances/proof');
          expect(
              request.headers['content-type'], contains('multipart/form-data'));
          expect(request.body, matches(RegExp(r'name=.proof.')));
          expect(request.body, matches(RegExp(r'filename=.receipt.png.')));
          return http.Response(
              jsonEncode({
                'data': {'path': 'owner/remittances/receipt.png'}
              }),
              201);
        }));
    addTearDown(api.close);
    expect(await api.uploadProof(Uint8List.fromList([1, 2, 3]), 'receipt.png'),
        'owner/remittances/receipt.png');
    await expectLater(
        api.uploadProof(Uint8List(5 * 1024 * 1024 + 1), 'large.png'),
        throwsA(isA<ApiException>()));
  });

  test('fee payments preserve partial cents and selected obligation IDs',
      () async {
    final api = RemittanceApiService(
        accessToken: 'seller-token',
        role: RemittanceRole.seller,
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'obligation_ids': ['a', 'b'],
            'amount_cents': 10001,
            'reference': 'REF',
            'proof_path': 'p'
          });
          return http.Response(jsonEncode({'data': {}}), 201);
        }));
    addTearDown(api.close);
    await api.submitPayment(
        obligationIds: ['a', 'b'],
        cents: 10001,
        reference: 'REF',
        proofPath: 'p');
  });

  test('loads only the requested page with encoded search filters', () async {
    final api = RemittanceApiService(
        accessToken: 'token',
        role: RemittanceRole.courier,
        client: MockClient((request) async {
          expect(request.url.queryParameters,
              {'page': '2', 'search': '#ORD 1', 'status': 'verified'});
          return http.Response(
              jsonEncode({
                'data': {
                  'items': [
                    {'id': 'r'}
                  ],
                  'current_page': 2,
                  'last_page': 3
                }
              }),
              200);
        }));
    addTearDown(api.close);
    final page =
        await api.records('cod', page: 2, search: '#ORD 1', status: 'verified');
    expect(page.page, 2);
    expect(page.lastPage, 3);
    expect(page.items.single['id'], 'r');
  });

  testWidgets(
      'courier sees seller confirmation state and cannot verify their own receipt',
      (tester) async {
    final api = _FakeApi(RemittanceRole.courier);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
        home: RemittancesScreen(
            accessToken: 't', role: RemittanceRole.courier, api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Awaiting seller confirmation'), 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);
    expect(find.text('Confirm receipt'), findsNothing);
    expect(find.text('Remit to seller'), findsNothing);
    expect(find.text('Awaiting seller confirmation'), findsOneWidget);
  });

  testWidgets(
      'seller must acknowledge actual receipt before confirmation is sent',
      (tester) async {
    final api = _FakeApi(RemittanceRole.seller);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
        home: RemittancesScreen(
            accessToken: 't', role: RemittanceRole.seller, api: api)));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Confirm receipt');
    await tester.scrollUntilVisible(button, 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(button, 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.reviews, 0);
    expect(
        find.text(
            'Confirm that you checked your account and received the payment.'),
        findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.reviews, 1);
    expect(api.status, 'verified');
  });
}

class _FakeApi extends RemittanceApiService {
  _FakeApi(RemittanceRole role)
      : super(
            role: role,
            accessToken: 'test',
            client: MockClient((_) async => http.Response('{}', 200)));
  int reviews = 0;
  String status = 'awaiting_verification';

  @override
  Future<Map<String, dynamic>> summary() async => {
        'outstanding_cents': 0,
        'manual_cod_owed_cents': 50000,
        'exposure_cents': 0,
        'cod_eligible': true
      };

  @override
  Future<RemittancePageData> records(String tab,
          {int page = 1, String search = '', String status = ''}) async =>
      RemittancePageData([
        {
          'id': 'receipt',
          'order_number': 'ORD123',
          'amount_cents': 50000,
          'remaining_cents': 50000,
          'reference': 'GC123',
          'status': this.status,
          'can_verify': role == RemittanceRole.seller
        },
      ], 1, 1);

  @override
  Future<void> review(String tab, String id, String action, String note) async {
    expect(role, RemittanceRole.seller);
    expect(action, 'verify');
    reviews++;
    status = 'verified';
  }
}
