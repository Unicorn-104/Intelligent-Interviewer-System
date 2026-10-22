import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/message_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JdHttpFixture http;
  late MessageDataSource source;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    http = JdHttpFixture();
    source = MessageDataSource(client: http.client);
  });
  tearDown(() => http.close());
  test('招聘者头像读取当前登录账号资料，不使用会话对方身份', () async {
    http.adapter.body = {
      'code': 200,
      'data': {
        'userId': 99,
        'nickName': '招聘者测试',
        'avatar': '/profile/synthetic-recruiter.png',
      },
    };
    final profile = await source.loadRecruiterProfile();
    final request = http.adapter.requests.single;
    expect(request.path, '/system/user/profile');
    expect(request.method, 'GET');
    expect(profile.id, 99);
    expect(profile.name, '招聘者测试');
    expect(profile.avatar, '/profile/synthetic-recruiter.png');
    expect(source.avatarUrl(profile.avatar), endsWith(profile.avatar));
  });
  test('招聘者资料缺失或登录失效时不伪造身份', () async {
    http.adapter.body = {'code': 200, 'data': {}};
    await expectLater(source.loadRecruiterProfile(), throwsFormatException);
    final calls = http.adapter.requests.length;
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(
      source.loadRecruiterProfile(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
    );
    expect(http.adapter.requests.length, calls);
  });
  test('复用现有会话接口，准确读取peerName、lastMessageAt和unread', () async {
    http.adapter.body = {
      'code': 200,
      'data': [
        {
          'sessionId': 8,
          'peerId': 12,
          'peerName': '合成候选人',
          'peerAvatar': '/profile/a.png',
          'lastMessage': '合成消息',
          'lastMessageAt': '2026-10-18 09:30:00',
          'unread': 3,
        },
      ],
    };
    final rows = await source.loadSessions();
    expect(http.adapter.requests.single.path, '/system/im/sessions');
    expect(rows.single.name, '合成候选人');
    expect(rows.single.unread, 3);
    expect(messageClock(rows.single.time), '09:30');
  });
  test('聊天历史isMine字段和发送接口保持原参数，不发送伪造senderId', () async {
    http.adapter.body = {
      'code': 200,
      'data': [
        {
          'messageId': 2,
          'isMine': false,
          'type': 1,
          'content': '后发合成消息',
          'sendTime': '2026-10-18 09:31',
        },
        {
          'messageId': 1,
          'isMine': true,
          'type': 1,
          'content': '先发合成消息',
          'sendTime': '2026-10-18 09:30',
        },
      ],
    };
    final rows = await source.loadMessages(8);
    expect(rows.map((row) => row.id), [1, 2]);
    expect(rows.first.mine, isTrue);
    http.adapter.body = {'code': 200, 'sessionId': 8};
    await source.send(8, '合成发送');
    final request = http.adapter.requests.last;
    expect(request.path, '/system/im/messages');
    expect(request.method, 'POST');
    expect(request.data, {'sessionId': 8, 'type': 1, 'content': '合成发送'});
  });
  test('系统通知读取真实分页及未读总数，已读接口与IM互不替换', () async {
    http.adapter.body = {
      'code': 200,
      'data': [
        {
          'messageId': 4,
          'title': '合成通知',
          'content': '合成内容',
          'isRead': 0,
          'createdAt': '2026-10-18 09:30',
        },
      ],
      'unreadCount': 7,
    };
    final slice = await source.loadNotifications(beforeId: 9);
    expect(slice.unreadCount, 7);
    expect(slice.items.single.isRead, isFalse);
    expect(http.adapter.requests.last.queryParameters, {
      'limit': 50,
      'beforeId': 9,
    });
    http.adapter.body = {'code': 200};
    await source.readSession(8);
    await source.readAllSessions();
    await source.readNotification(4);
    await source.readAllNotifications();
    expect(http.adapter.requests.skip(1).map((r) => r.path), [
      '/system/im/sessions/8/read',
      '/system/im/read-all',
      '/system/im/notifications/4/read',
      '/system/im/notifications/read-all',
    ]);
    expect(
      http.adapter.requests.skip(1).every((r) => r.method == 'PUT'),
      isTrue,
    );
  });
  test('无登录态不得发请求，业务失败不伪造空会话', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(source.loadSessions(), throwsA(isA<ApiException>()));
    expect(http.adapter.requests, isEmpty);
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    http.adapter.body = {'code': 403, 'msg': '合成权限不足'};
    await expectLater(
      source.loadSessions(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 403)),
    );
    http.adapter.body = {
      'code': 200,
      'data': [
        {'sessionId': null, 'unread': 0},
      ],
    };
    await expectLater(source.loadSessions(), throwsFormatException);
  });
  test('通知格式错误和历史缺失归属标记必须报错，时间无偏移按UTC8展示', () async {
    http.adapter.body = {'code': 200, 'data': []};
    await expectLater(source.loadNotifications(), throwsFormatException);
    http.adapter.body = {
      'code': 200,
      'data': [
        {'messageId': 1, 'content': '无归属消息'},
      ],
    };
    await expectLater(source.loadMessages(8), throwsFormatException);
    expect(messageTime('2026-10-18 09:30'), DateTime.utc(2026, 10, 18, 1, 30));
    expect(
      messageDate(
        messageTime('2026-10-17 09:30'),
        now: DateTime.utc(2026, 10, 18, 2),
      ),
      '昨天',
    );
  });
  test('快捷回复仅使用服务端内容，去重且不自动发送', () async {
    http.adapter.body = {
      'code': 200,
      'data': [
        {'id': 1, 'content': '合成回复'},
        {'id': 2, 'content': '合成回复'},
        {'id': 3, 'content': ''},
      ],
    };
    expect((await source.loadQuickReplies()).map((r) => r.id), [1, 2]);
    expect(http.adapter.requests.single.path, '/system/im/quick-replies');
  });
}
