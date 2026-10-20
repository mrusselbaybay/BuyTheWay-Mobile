import 'package:buytheway/screens/driver/chat/chat_models.dart';
import 'package:buytheway/screens/driver/chat/driver_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg(String id, {String? localId, MessageStatus status = MessageStatus.sent}) => ChatMessage(
      id: id,
      senderRole: 'courier',
      text: 'hello',
      sentAt: DateTime(2026, 10, 20),
      status: status,
      localId: localId,
    );

void main() {
  test('replaces the optimistic message with the server copy', () {
    final list = [_msg('a'), _msg('local-1', localId: 'local-1', status: MessageStatus.sending)];
    settleSentMessage(list, 'local-1', _msg('srv-9'));
    expect(list.map((m) => m.id), ['a', 'srv-9']);
  });

  test('never leaves two copies when the poll delivered the message first', () {
    final list = [_msg('a'), _msg('local-1', localId: 'local-1', status: MessageStatus.sending), _msg('srv-9')];
    settleSentMessage(list, 'local-1', _msg('srv-9'));
    expect(list.map((m) => m.id), ['a', 'srv-9']);
  });

  test('adds the real message once if the optimistic one is gone', () {
    final list = [_msg('a')];
    settleSentMessage(list, 'local-1', _msg('srv-9'));
    settleSentMessage(list, 'local-1', _msg('srv-9'));
    expect(list.map((m) => m.id), ['a', 'srv-9']);
  });

  test('leaves other pending messages alone (rapid double send)', () {
    final list = [_msg('local-1', localId: 'local-1'), _msg('local-2', localId: 'local-2')];
    settleSentMessage(list, 'local-1', _msg('srv-1'));
    expect(list.map((m) => m.id), ['srv-1', 'local-2']);
  });
}
