import 'package:enterprise_recruiter/api/talent_api.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_contact_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_pool_data_source.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JdHttpFixture http;
  late TalentContactDataSource contact;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    http = JdHttpFixture();
    contact = TalentContactDataSource(client: http.client);
  });
  tearDown(() => http.close());

  test('所有支持条件传到已有接口，状态分页不再仅扫描前3页', () async {
    final calls = <Map<String, Object?>>[];
    final source = TalentPoolDataSource(
      advancedLoader:
          ({
            keyword,
            tag,
            direction,
            archiveSource,
            status,
            minimumEducation,
            experienceRange,
            city,
            cityType,
            loginWithinDays,
            required pageNum,
            required pageSize,
          }) async {
            calls.add({
              'keyword': keyword,
              'tag': tag,
              'direction': direction,
              'archiveSource': archiveSource,
              'status': status,
              'pageNum': pageNum,
              'pageSize': pageSize,
            });
            return List.generate(
              pageNum == 4 ? 1 : 20,
              (index) => <String, dynamic>{
                'talentId': (pageNum - 1) * 20 + index + 1,
                'status': 1,
                'jobDirection': '合成Java方向',
                'archiveSource': 3,
                'tags': 'Java',
              },
            );
          },
    );
    for (var page = 1; page <= 4; page++) {
      final result = await source.load(
        keyword: ' 合成 ',
        tag: ' Java ',
        direction: ' 合成Java方向 ',
        archiveSource: 3,
        status: 1,
        pageNum: page,
      );
      expect(result.nextPage, page + 1);
      expect(result.hasMore, page < 4);
      expect(result.limited, isFalse);
      expect(result.scannedPages, 1);
    }
    expect(calls.last, {
      'keyword': '合成',
      'tag': 'Java',
      'direction': '合成Java方向',
      'archiveSource': 3,
      'status': 1,
      'pageNum': 4,
      'pageSize': 20,
    });
  });

  test('筛选参数按契约发送，无当前企业信息或伪造用户归属参数', () async {
    http.adapter.body = {
      'code': 200,
      'rows': [
        {'talentId': 11},
      ],
    };
    final rows = await searchAdvancedTalentPool(
      client: http.client,
      keyword: '合成',
      tag: 'Java',
      direction: '合成方向',
      archiveSource: 3,
      status: 1,
      pageNum: 2,
      pageSize: 20,
    );
    expect(rows.single['talentId'], 11);
    final request = http.adapter.requests.single;
    expect(request.path, '/enterprise/talent/list');
    expect(request.queryParameters, {
      'keyword': '合成',
      'tag': 'Java',
      'direction': '合成方向',
      'archiveSource': 3,
      'status': 1,
      'pageNum': 2,
      'pageSize': 20,
    });
    http.adapter.body = {
      'code': 200,
      'data': {
        'directions': ['合成方向', '合成方向'],
        'tags': ['Java'],
      },
    };
    final options = TalentPoolOptions.fromJson(
      await loadTalentPoolOptions(client: http.client),
    );
    expect(options.directions, ['合成方向']);
    expect(options.tags, ['Java']);
    expect(http.adapter.requests.last.path, '/enterprise/talent/options');
  });

  test('无效响应和旧服务忽略筛选条件时明确报错，不冒充匹配结果', () async {
    http.adapter.body = {'code': 200};
    await expectLater(
      searchAdvancedTalentPool(client: http.client, pageNum: 1, pageSize: 20),
      throwsFormatException,
    );
    expect(
      () => TalentPoolOptions.fromJson({
        'directions': [],
        'tags': [null],
      }),
      throwsFormatException,
    );
    final source = TalentPoolDataSource(
      advancedLoader:
          ({
            keyword,
            tag,
            direction,
            archiveSource,
            status,
            minimumEducation,
            experienceRange,
            city,
            cityType,
            loginWithinDays,
            required pageNum,
            required pageSize,
          }) async => [
            {'talentId': 11, 'status': 2, 'jobDirection': '不匹配'},
          ],
    );
    await expectLater(source.load(status: 1), throwsFormatException);
    await expectLater(source.load(direction: '目标方向'), throwsFormatException);
    await expectLater(source.load(archiveSource: 3), throwsFormatException);
    await expectLater(source.load(status: 10), throwsFormatException);
    await expectLater(source.load(archiveSource: -1), throwsFormatException);
    await expectLater(source.load(pageNum: 0), throwsFormatException);
  });

  test('联系账号只来自真实人才详情，绝不能把talentId作为peerId', () async {
    http.adapter.body = {
      'code': 200,
      'data': {
        'talentId': 11,
        'userId': 99,
        'name': '合成候选人',
        'avatar': '/profile/synthetic.png',
      },
    };
    final target = await contact.loadTarget(11);
    expect(target.userId, 99);
    expect(target.userId, isNot(11));
    expect(http.adapter.requests.single.path, '/enterprise/talent/11');
    http.adapter.body = {'code': 200, 'sessionId': 8};
    final session = await contact.sendGreeting(target, '  合成招呼语  ');
    expect(session, {
      'sessionId': 8,
      'peerId': 99,
      'peerName': '合成候选人',
      'peerAvatar': '/profile/synthetic.png',
    });
    expect(http.adapter.requests.last.path, '/system/im/messages');
    expect(http.adapter.requests.last.data, {
      'peerId': 99,
      'type': 1,
      'content': '合成招呼语',
    });
  });

  test('同名会话只按真实peerId精确匹配，没有会话时不会自动发送', () async {
    const target = TalentContactTarget(userId: 99, name: '同名合成候选人', avatar: '');
    http.adapter.body = {
      'code': 200,
      'data': [
        {'sessionId': 8, 'peerId': 11, 'peerName': target.name, 'unread': 0},
        {'sessionId': 9, 'peerId': 99, 'peerName': '合成姓名已更新', 'unread': 0},
      ],
    };
    final session = await contact.findSession(target);
    expect(session!['sessionId'], 9);
    expect(http.adapter.requests.single.method, 'GET');
    http.adapter.body = {'code': 200, 'data': []};
    expect(await contact.findSession(target), isNull);
    expect(http.adapter.requests.every((row) => row.method == 'GET'), isTrue);
    http.adapter.body = {
      'code': 200,
      'data': [
        {'sessionId': 8, 'peerId': 99, 'peerName': target.name, 'unread': 0},
        {'sessionId': 9, 'peerId': 99, 'peerName': target.name, 'unread': 0},
      ],
    };
    await expectLater(contact.findSession(target), throwsFormatException);
  });

  test('资料错位、无账号、未登录、无会话编号或空招呼语均不会伪造成功', () async {
    http.adapter.body = {
      'code': 200,
      'data': {'talentId': 12, 'userId': 99},
    };
    await expectLater(contact.loadTarget(11), throwsFormatException);
    http.adapter.body = {
      'code': 200,
      'data': {'talentId': 11},
    };
    await expectLater(contact.loadTarget(11), throwsFormatException);
    const target = TalentContactTarget(userId: 99, name: '合成候选人', avatar: '');
    final calls = http.adapter.requests.length;
    await expectLater(contact.sendGreeting(target, ' '), throwsFormatException);
    expect(http.adapter.requests.length, calls);
    http.adapter.body = {'code': 200};
    await expectLater(
      contact.sendGreeting(target, '合成招呼语'),
      throwsFormatException,
    );
    FlutterSecureStorage.setMockInitialValues({});
    final before = http.adapter.requests.length;
    await expectLater(
      contact.loadTarget(11),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
    );
    await expectLater(
      contact.sendGreeting(target, '合成招呼语'),
      throwsA(isA<ApiException>()),
    );
    expect(http.adapter.requests.length, before);
  });
}
