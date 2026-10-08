import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';

void main() {
  test('parses a real HR message payload', () {
    final message = AppMessage.fromJson({
      'sourceId': 18,
      'category': 'HR',
      'title': '示例企业 HR',
      'content': '请确认面试时间',
      'occurredAt': '2026-09-29 10:30:00',
      'unreadCount': 2,
      'avatarUrl': '/profile/avatar/hr.png',
    });

    expect(message.sourceId, 18);
    expect(message.category, AppMessageCategory.hr);
    expect(message.unreadCount, 2);
    expect(message.occurredAt.year, 2026);
    expect(message.avatarUrl, '/profile/avatar/hr.png');
  });

  test('unknown message categories fall back to system notifications', () {
    final message = AppMessage.fromJson({
      'sourceId': '7',
      'category': 'UNKNOWN',
      'title': '通知',
      'content': '内容',
      'unreadCount': '1',
    });

    expect(message.category, AppMessageCategory.system);
    expect(message.unreadCount, 1);
  });

  test('parses an HR chat message and its direction', () {
    final message = ChatMessage.fromJson({
      'messageId': 23,
      'senderId': 2,
      'content': '感谢邀请，我会准时参加面试。',
      'mine': true,
      'createdAt': '2026-09-29 10:43:53',
    });

    expect(message.messageId, 23);
    expect(message.mine, isTrue);
    expect(message.createdAt.minute, 43);
  });
}
