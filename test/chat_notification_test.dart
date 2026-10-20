import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:buytheway/services/chat_notification.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isPng(Uint8List bytes) => bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;

Future<Uint8List> _solidPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), ui.Paint()..color = const ui.Color(0xFFFF0000));
  final image = await recorder.endRecording().toImage(width, height);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  group('initials', () {
    test('takes up to two words', () {
      expect(ChatNotification.initials('Maria Cruz'), 'MC');
      expect(ChatNotification.initials('maria dela cruz'), 'MD');
      expect(ChatNotification.initials('  Aling   Nena Store '), 'AN');
    });

    test('handles one word, empty, emoji and non-Latin names', () {
      expect(ChatNotification.initials('Maria'), 'M');
      expect(ChatNotification.initials('   '), '?');
      expect(ChatNotification.initials('😀 Smile'), '😀S');
      expect(ChatNotification.initials('李 小龍'), '李小');
    });
  });

  testWidgets('draws an initials circle when there is no photo', (tester) async {
    final bytes = await tester.runAsync(() => ChatNotification.avatar(null, 'Maria Cruz'));
    expect(bytes, isNotNull);
    expect(_isPng(bytes!), isTrue);
  });

  testWidgets('never fetches a non-https photo, and falls back to initials', (tester) async {
    final bytes = await tester.runAsync(() => ChatNotification.avatar('http://insecure.example.test/a.jpg', 'Maria Cruz'));
    expect(_isPng(bytes!), isTrue);
  });

  testWidgets('crops a landscape and a portrait photo to a small round PNG', (tester) async {
    await tester.runAsync(() async {
      for (final size in [const ui.Size(800, 300), const ui.Size(300, 800), const ui.Size(50, 50)]) {
        final photo = await _solidPng(size.width.toInt(), size.height.toInt());
        final round = await ChatNotification.roundPhoto(photo);
        expect(_isPng(round), isTrue);

        final decoded = await (await ui.instantiateImageCodec(round)).getNextFrame();
        expect(decoded.image.width, 192);
        expect(decoded.image.height, 192);
      }
    });
  });

  testWidgets('rejects bytes that are not an image (caller then draws initials)', (tester) async {
    await tester.runAsync(() async {
      await expectLater(ChatNotification.roundPhoto(Uint8List.fromList(List.filled(64, 7))), throwsA(anything));
    });
  });
}
