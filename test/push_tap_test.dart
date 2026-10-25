import 'package:flutter_test/flutter_test.dart';
import 'package:buytheway/services/push_service.dart';

void main() {
  test('parses courier notification navigation data from an FCM tap', () {
    final tap = PushTap.fromData({
      'kind': 'notification',
      'notificationId': 'notification-1',
      'target': 'deliveries',
      'parcelId': 'parcel-1',
    });

    expect(tap.isMessage, isFalse);
    expect(tap.notificationId, 'notification-1');
    expect(tap.target, 'deliveries');
    expect(tap.parcelId, 'parcel-1');
  });

  test('keeps chat taps separate from courier notifications', () {
    final tap =
        PushTap.fromData({'kind': 'message', 'conversationId': 'thread-1'});

    expect(tap.isMessage, isTrue);
    expect(tap.conversationId, 'thread-1');
    expect(tap.target, isNull);
  });
}
