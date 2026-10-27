import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/messages/data/message_api.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'package:intelligent_interviewer/screens/hr_chat_screen.dart';

class ReceiptApi extends MessageApi {
  ReceiptApi(super.client);
  List<ChatMessage> rows = [
    ChatMessage(
      messageId: 31,
      senderId: 9,
      content: '合成企业消息',
      mine: false,
      createdAt: DateTime(2026, 10, 26),
      deliveryStatus: 'received',
    ),
  ];
  final acks = <(int, int)>[];
  @override
  Future<List<ChatMessage>> fetchHrChat(String token, int sessionId) async =>
      rows;
  @override
  Future<bool> acknowledgeRead(String token, int sessionId, int id) async {
    acks.add((sessionId, id));
    return true;
  }
}

void main() {
  test('只接受真实服务端回执协议，缺失和未知状态不显示', () {
    for (final state in ['read', 'delivered', 'received']) {
      expect(
        ChatMessage.fromJson({'deliveryStatus': state}).deliveryStatus,
        state,
      );
    }
    expect(ChatMessage.fromJson({}).deliveryStatus, isNull);
    expect(
      ChatMessage.fromJson({'deliveryStatus': 'pretend-read'}).deliveryStatus,
      isNull,
    );
  });
  testWidgets('求职者前台显示消息后确认原消息ID，后台和离开后停止确认', (tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    final api = ReceiptApi(client);
    await tester.pumpWidget(
      MaterialApp(
        home: HrChatScreen(
          session: const AuthSession(
            token: 'synthetic',
            userId: 12,
            userName: 'synthetic',
            nickName: '合成求职者',
          ),
          conversation: AppMessage(
            sourceId: 8,
            category: AppMessageCategory.hr,
            title: '合成企业',
            content: '',
            occurredAt: DateTime(2026),
            unreadCount: 1,
          ),
          messageApi: api,
          pollInterval: const Duration(seconds: 8),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.acks, [(8, 31)]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    api.rows = [
      ChatMessage(
        messageId: 32,
        senderId: 9,
        content: '新的合成消息',
        mine: false,
        createdAt: DateTime(2026),
        deliveryStatus: 'received',
      ),
    ];
    await tester.pump(const Duration(seconds: 8));
    expect(api.acks, [(8, 31)]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.acks.last, (8, 32));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 16));
    expect(api.acks.length, 2);
    expect(tester.takeException(), isNull);
  });
}
