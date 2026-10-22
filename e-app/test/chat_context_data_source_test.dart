import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/core/network/enterprise_api_client.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/message_data_source.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class Routes implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  late Object Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> detail(int id, List<Map<String, dynamic>> candidates) => {
  'code': 200,
  'data': {
    'job': {'posId': id, 'title': '合成岗位$id', 'education': 3},
    'candidates': candidates,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Routes routes;
  late Dio dio;
  late MessageDataSource source;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test',
    });
    routes = Routes();
    dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'))
      ..httpClientAdapter = routes;
    source = MessageDataSource(client: EnterpriseApiClient(dio: dio));
  });
  tearDown(() => dio.close(force: true));

  test('按对方userId关联岗位和talId，同名求职者不混淆，多岗位保留全部', () async {
    routes.respond = (r) {
      if (r.path.endsWith('/list')) {
        return {
          'code': 200,
          'rows': [
            {'posId': 7},
            {'posId': 8},
          ],
          'total': 2,
        };
      }
      return detail(int.parse(r.path.split('/').last), [
        {'talId': 12, 'userId': 99, 'name': '合成同名'},
        {'talId': 42, 'userId': 12, 'name': '合成同名'},
      ]);
    };
    final context = await source.loadChatContext({
      'peerId': 12,
      'peerName': '合成同名',
    });
    expect(context.jobs.map((j) => j.id), [7, 8]);
    expect(context.talent!['talentId'], 42);
    expect(context.jobs.every((j) => j.talent['talentId'] == 42), isTrue);
    expect(context.jobs.first.requirements, '本科');
    expect(routes.requests.every((r) => r.method == 'GET'), isTrue);
    expect(routes.requests.length, 3);
  });

  test('岗位列表完整分页并去重，不只匹配第一页或默认第一个岗位', () async {
    routes.respond = (r) {
      if (r.path.endsWith('/list')) {
        return {
          'code': 200,
          'rows': [
            {'posId': r.queryParameters['pageNum'] == 1 ? 7 : 8},
          ],
          'total': 2,
        };
      }
      final id = int.parse(r.path.split('/').last);
      return detail(
        id,
        id == 8
            ? [
                {'talId': 42, 'userId': 12},
              ]
            : [],
      );
    };
    final context = await source.loadChatContext({'peerId': 12});
    expect(context.jobs.single.id, 8);
    expect(routes.requests.take(2).map((r) => r.queryParameters['pageNum']), [
      1,
      2,
    ]);
    expect(routes.requests.first.queryParameters['pageSize'], 50);
  });

  test('没有流程关联时读取企业人才库详情校验userId，不把peerId当talentId', () async {
    routes.respond = (r) => switch (r.path) {
      '/system/enterprise/jobs/list' => {'code': 200, 'rows': [], 'total': 0},
      '/enterprise/talent/list' => {
        'code': 200,
        'rows': [
          {'talentId': 12, 'name': '合成同名'},
          {'talentId': 42, 'name': '合成同名'},
        ],
        'total': 2,
      },
      '/enterprise/talent/12' => {
        'code': 200,
        'data': {'talentId': 12, 'userId': 99},
      },
      '/enterprise/talent/42' => {
        'code': 200,
        'data': {'talentId': 42, 'userId': 12},
      },
      _ => throw StateError('Unexpected request'),
    };
    final context = await source.loadChatContext({
      'peerId': 12,
      'peerName': '合成同名',
    });
    expect(context.jobs, isEmpty);
    expect(context.talent!['talentId'], 42);
    expect(routes.requests[1].queryParameters['keyword'], '合成同名');
  });

  test('多人才记录不任意选人，岗位选择后才能确定对应talentId', () async {
    routes.respond = (r) {
      if (r.path.endsWith('/list')) {
        return {
          'code': 200,
          'rows': [
            {'posId': 7},
            {'posId': 8},
          ],
          'total': 2,
        };
      }
      final id = int.parse(r.path.split('/').last);
      return detail(id, [
        {'talId': id + 100, 'userId': 12},
      ]);
    };
    final context = await source.loadChatContext({'peerId': 12});
    expect(context.talent, isNull);
    expect(context.jobs.map((j) => j.talent['talentId']), [107, 108]);
  });

  test('无关联返回真实空态，失败不伪装成空数据', () async {
    routes.respond = (_) => {'code': 200, 'rows': [], 'total': 0};
    final context = await source.loadChatContext({'peerId': 12});
    expect(context.jobs, isEmpty);
    expect(context.talent, isNull);
    routes.respond = (_) => {'code': 500, 'msg': '合成读取失败'};
    await expectLater(
      source.loadChatContext({'peerId': 12}),
      throwsA(isA<ApiException>()),
    );
  });

  test('无登录态、无peerId不发送请求，拒绝缺失候选编号及错位岗位数据', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(
      source.loadChatContext({'peerId': 12}),
      throwsA(isA<ApiException>()),
    );
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test',
    });
    await expectLater(source.loadChatContext({}), throwsFormatException);
    expect(routes.requests, isEmpty);
    routes.respond = (r) => r.path.endsWith('/list')
        ? {
            'code': 200,
            'rows': [
              {'posId': 7},
            ],
            'total': 1,
          }
        : detail(7, [
            {'userId': 12},
          ]);
    await expectLater(
      source.loadChatContext({'peerId': 12}),
      throwsFormatException,
    );
    routes.respond = (r) => r.path.endsWith('/list')
        ? {
            'code': 200,
            'rows': [
              {'posId': 7},
            ],
            'total': 1,
          }
        : detail(8, [
            {'talId': 42, 'userId': 12},
          ]);
    await expectLater(
      source.loadChatContext({'peerId': 12}),
      throwsFormatException,
    );
  });
}
