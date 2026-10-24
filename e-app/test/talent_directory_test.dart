import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_contact_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_discovery_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_pool_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_discovery_profile.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'support/jd_http_fixture.dart';

Map<String, dynamic> registeredProfile([int userId = 101]) => {
  'userId': userId, 'name': '合成注册求职者', 'avatar': '',
  'jobDirection': '合成Java岗位',
  'currentStatus': 2,
  'currentCity': '合成杭州',
  'targetCity': '合成上海',
  'highestEducation': 3, 'workMonths': 36, 'directoryVersion': 1,
  // 模拟旧服务夹带字段：公开模式必须去掉这些值，不依赖前端隐藏按钮。
  'talentId': 11, 'status': 6, 'matchedScore': 99, 'tags': ['内部标签'],
  'phone': '00000000000', 'email': 'synthetic@example.invalid', 'positionId': 7,
};

class DirectorySource extends TalentDiscoveryDataSource {
  final queries = <Map<String, Object?>>[];
  final details = <int>[];
  Object? failure;
  bool paging = false;
  Completer<Map<String, dynamic>>? detailGate;
  @override
  Future<TalentPoolOptions> loadOptions() async => const TalentPoolOptions(
    directions: ['合成Java岗位'],
    targetCities: ['合成上海'],
    searchFilterVersion: 2,
  );
  @override
  Future<TalentPoolResult> load({
    String? keyword,
    String? tag,
    int? status,
    String? direction,
    int? archiveSource,
    TalentPoolFilters extended = const TalentPoolFilters(),
    int pageNum = 1,
  }) async {
    queries.add({
      'keyword': keyword,
      'status': status,
      'direction': direction,
      'city': extended.city,
      'page': pageNum,
    });
    if (failure != null) throw failure!;
    return TalentPoolResult(
      rows: [registeredProfile(pageNum == 1 ? 101 : 102)],
      tags: const [],
      nextPage: pageNum + 1,
      hasMore: paging && pageNum == 1,
      limited: false,
      scannedPages: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> detail(int userId) async {
    details.add(userId);
    if (failure != null) throw failure!;
    return detailGate?.future ?? registeredProfile(userId);
  }
}

class DirectoryContact extends TalentContactDataSource {
  final users = <int>[];
  final talents = <int>[];
  final sends = <(int, String)>[];
  Map<String, dynamic>? session;
  @override
  Future<TalentContactTarget> loadUserTarget(int userId) async {
    users.add(userId);
    return TalentContactTarget(userId: userId, name: '合成注册求职者', avatar: '');
  }

  @override
  Future<TalentContactTarget> loadTarget(int talentId) async {
    talents.add(talentId);
    throw StateError('Directory must not resolve talentId');
  }

  @override
  Future<Map<String, dynamic>?> findSession(TalentContactTarget target) async =>
      session;
  @override
  Future<Map<String, dynamic>> sendGreeting(
    TalentContactTarget target,
    String text,
  ) async {
    sends.add((target.userId, text));
    return {'sessionId': 88, 'peerId': target.userId};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('平台人才发现接口', () {
    late JdHttpFixture http;
    late TalentDiscoveryDataSource source;
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'enterprise_access_token': 'synthetic-token',
      });
      http = JdHttpFixture();
      source = TalentDiscoveryDataSource(client: http.client);
    });
    tearDown(() => http.close());
    test('查询全站注册求职者接口，不传企业ID、招聘状态或talentId', () async {
      http.adapter.body = {
        'code': 200,
        'rows': [registeredProfile()],
        'total': 21,
      };
      final result = await source.load(
        keyword: ' Java ',
        status: 2,
        extended: const TalentPoolFilters(minimumEducation: 3, city: '合成上海'),
        pageNum: 1,
      );
      expect(result.hasMore, isTrue);
      expect(result.rows.single['userId'], 101);
      final request = http.adapter.requests.single;
      expect(request.path, '/enterprise/talent-discovery');
      expect(request.queryParameters['keyword'], 'Java');
      expect(request.queryParameters['currentStatus'], 2);
      expect(request.queryParameters.keys, isNot(contains('companyId')));
      expect(request.queryParameters.keys, isNot(contains('status')));
      expect(
        result.rows.single.keys.every(
          TalentDiscoveryDataSource.fields.contains,
        ),
        isTrue,
      );
      for (final key in [
        'talentId',
        'status',
        'matchedScore',
        'tags',
        'phone',
        'email',
        'positionId',
      ]) {
        expect(result.rows.single.containsKey(key), isFalse);
      }
    });
    test('详情仅按userId请求并剔除旧招聘字段，编号错位拒绝', () async {
      http.adapter.body = {'code': 200, 'data': registeredProfile()};
      final profile = await source.detail(101);
      expect(
        http.adapter.requests.single.path,
        '/enterprise/talent-discovery/101',
      );
      expect(profile['userId'], 101);
      expect(profile.containsKey('matchedScore'), isFalse);
      http.adapter.body = {'code': 200, 'data': registeredProfile(102)};
      await expectLater(source.detail(101), throwsFormatException);
    });
    test('发现接口未部署、旧格式或非法招聘状态不能回退到企业候选人列表', () async {
      http.adapter.body = {'code': 404, 'msg': '合成未部署'};
      await expectLater(source.load(), throwsA(isA<ApiException>()));
      expect(http.adapter.requests, hasLength(1));
      expect(http.adapter.requests.single.path, '/enterprise/talent-discovery');
      http.adapter.body = {
        'code': 200,
        'rows': [
          {'talentId': 11, 'userId': 101},
        ],
        'total': 1,
      };
      await expectLater(source.load(), throwsFormatException);
      final before = http.adapter.requests.length;
      await expectLater(source.load(status: 9), throwsFormatException);
      await expectLater(source.load(tag: '企业标签'), throwsFormatException);
      expect(http.adapter.requests.length, before);
    });
    test('未投递用户主动沟通直接核对userId，不读取企业人才详情', () async {
      final contact = TalentContactDataSource(client: http.client);
      http.adapter.body = {'code': 200, 'data': registeredProfile()};
      final target = await contact.loadUserTarget(101);
      expect(target.userId, 101);
      expect(
        http.adapter.requests.single.path,
        '/enterprise/talent-discovery/101',
      );
      http.adapter.body = {
        'code': 200,
        'data': [
          {'sessionId': 11, 'peerId': 11, 'peerName': target.name, 'unread': 0},
          {'sessionId': 88, 'peerId': 101, 'peerName': '合成其他昵称', 'unread': 0},
        ],
      };
      expect((await contact.findSession(target))!['sessionId'], 88);
      http.adapter.body = {'code': 200, 'sessionId': 88};
      await contact.sendGreeting(target, ' 合成招呼语 ');
      expect(http.adapter.requests.last.data, {
        'peerId': 101,
        'type': 1,
        'content': '合成招呼语',
      });
      expect(
        http.adapter.requests.where(
          (r) => r.path.startsWith('/enterprise/talent/'),
        ),
        isEmpty,
      );
    });
    test('用户去重与空结果按userId，不能混用talentId', () {
      final rows = mergeDiscoveryRows(
        [registeredProfile()],
        [registeredProfile(), registeredProfile(102)],
      );
      expect(rows.map((r) => r['userId']), [101, 102]);
      expect(
        () => mergeDiscoveryRows([], [
          {'talentId': 11},
        ]),
        throwsFormatException,
      );
    });
  });
  Future<void> mount(
    WidgetTester tester,
    DirectorySource source,
    DirectoryContact contact, {
    Size size = const Size(430, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: TalentPage(
          discovery: true,
          source: source,
          contactSource: contact,
          chatBuilder: (session) =>
              Scaffold(body: Text('合成用户会话${session['peerId']}')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void noJobBoundContent() {
    for (final text in [
      '通用评分',
      '已放弃',
      '已录用',
      '已淘汰',
      '当前轮次',
      '选择岗位后查看流程',
      '邀请面试',
      '内部标签',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
  }

  testWidgets('人才库展示注册用户和期望岗位，列表及详情不含评分流程或敏感联系方式', (tester) async {
    final source = DirectorySource();
    await mount(tester, source, DirectoryContact());
    expect(find.text('人才库'), findsOneWidget);
    expect(find.text('发现全站已注册求职者'), findsOneWidget);
    expect(find.byKey(const Key('discovery-user-101')), findsOneWidget);
    noJobBoundContent();
    expect(find.text('期望岗位：合成Java岗位'), findsOneWidget);
    await tap(tester, 'discovery-user-101');
    expect(find.byType(TalentDiscoveryProfilePage), findsOneWidget);
    expect(find.byType(TalentDetailPage), findsNothing);
    expect(source.details, [101]);
    expect(find.text('求职期望'), findsOneWidget);
    noJobBoundContent();
    expect(find.textContaining('00000000000'), findsNothing);
    expect(find.textContaining('synthetic@example.invalid'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('discovery-user-101')), findsOneWidget);
  });
  testWidgets('求职状态替换公司招聘状态，确认才向平台接口提交组合条件', (tester) async {
    final source = DirectorySource();
    await mount(tester, source, DirectoryContact());
    await tap(tester, 'talent-filter-open');
    expect(find.text('求职状态'), findsOneWidget);
    expect(find.text('招聘状态'), findsNothing);
    expect(find.byKey(const Key('talent-filter-status-9')), findsNothing);
    await tap(tester, 'talent-filter-category-1');
    await tap(tester, 'talent-filter-status-2');
    expect(source.queries, hasLength(1));
    await tap(tester, 'talent-filter-apply');
    expect(source.queries.last['status'], 2);
    expect(find.byTooltip('筛选(1)'), findsOneWidget);
    noJobBoundContent();
  });
  testWidgets('未投递用户可首次沟通，需人工确认；已有会话按真实账号直接进入', (tester) async {
    final contact = DirectoryContact();
    await mount(tester, DirectorySource(), contact);
    await tap(tester, 'discovery-contact-101');
    expect(contact.users, [101]);
    expect(contact.talents, isEmpty);
    expect(contact.sends, isEmpty);
    await tester.enterText(
      find.byKey(const Key('talent-contact-input')),
      '合成主动沟通',
    );
    await tap(tester, 'talent-contact-send');
    expect(contact.sends, [(101, '合成主动沟通')]);
    expect(find.text('合成用户会话101'), findsOneWidget);
  });
  testWidgets('详情主动沟通不出现邀请面试，已有会话直接复用', (tester) async {
    final contact = DirectoryContact()
      ..session = {'sessionId': 88, 'peerId': 101};
    await mount(tester, DirectorySource(), contact);
    await tap(tester, 'discovery-user-101');
    await tap(tester, 'discovery-profile-contact');
    expect(contact.users, [101]);
    expect(contact.talents, isEmpty);
    expect(contact.sends, isEmpty);
    await tap(tester, 'talent-contact-continue');
    expect(find.text('合成用户会话101'), findsOneWidget);
  });
  testWidgets('平台分页不要求人才ID，详情加载迟到响应在离开后不更新页面', (tester) async {
    final source = DirectorySource()..paging = true;
    await mount(tester, source, DirectoryContact());
    await tap(tester, 'talent-load-more');
    expect(source.queries.last['page'], 2);
    expect(find.byKey(const Key('discovery-user-102')), findsOneWidget);
    source.detailGate = Completer<Map<String, dynamic>>();
    await tester.tap(find.byKey(const Key('discovery-user-101')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    source.detailGate!.complete(registeredProfile());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('平台人才列表及基础详情在$size双倍字号无溢出', (tester) async {
      await mount(
        tester,
        DirectorySource(),
        DirectoryContact(),
        size: size,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tap(tester, 'discovery-user-101');
      await tester.scrollUntilVisible(
        find.byKey(const Key('discovery-profile-contact')),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('discovery-profile')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      noJobBoundContent();
    });
  }
  for (final configuration in [(320.0, 1.0), (390.0, 2.0), (900.0, 1.0)]) {
    testWidgets('人才卡片长字段在$configuration保持可读和独立沟通操作', (tester) async {
      var opens = 0, contacts = 0;
      final profile = registeredProfile()
        ..['name'] = '合成较长求职者姓名用于布局验证'
        ..['jobDirection'] = 'Java后端开发与分布式系统研发工程师'
        ..['targetCity'] = '合成杭州、上海、北京'
        ..['currentCity'] = '合成杭州'
        ..['schoolName'] = '用于合成测试的较长毕业院校名称'
        ..['major'] = '计算机科学与软件工程'
        ..['graduationYear'] = 2022
        ..['salaryNegotiable'] = 0
        ..['salaryMin'] = 8000
        ..['salaryMax'] = 12000;
      tester.view.physicalSize = Size(configuration.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(configuration.$2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DiscoveryTalentCard(
                  profile: profile,
                  contactEnabled: true,
                  onOpen: () => opens++,
                  onContact: () => contacts++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('期望岗位：Java后端开发与分布式系统研发工程师'), findsOneWidget);
      expect(find.text('期望城市：合成杭州、上海、北京'), findsOneWidget);
      noJobBoundContent();
      await tester.ensureVisible(
        find.byKey(const Key('discovery-contact-101')),
      );
      await tester.tap(find.byKey(const Key('discovery-contact-101')));
      await tester.pumpAndSettle();
      expect(contacts, 1);
      expect(opens, 0);
      await tester.tap(find.text('合成较长求职者姓名用于布局验证'));
      expect(opens, 1);
      expect(contacts, 1);
    });
  }
  test('期望薪资明确区分未填写、面议和人民币月薪区间', () {
    expect(discoverySalary({}), '期望薪资未填写');
    expect(discoverySalary({'salaryNegotiable': 1}), '薪资面议');
    expect(
      discoverySalary({
        'salaryNegotiable': 0,
        'salaryMin': 8000,
        'salaryMax': 12000,
      }),
      '8K–12K/月',
    );
    expect(
      discoverySalary({
        'salaryNegotiable': 0,
        'salaryMin': 8500,
        'salaryMax': 12500,
      }),
      '8500元–12500元/月',
    );
    expect(
      discoverySalary({'salaryNegotiable': 0, 'salaryMin': 0, 'salaryMax': 0}),
      '0元/月',
    );
    expect(
      discoverySalary({
        'salaryNegotiable': 0,
        'salaryMin': 12000,
        'salaryMax': 8000,
      }),
      '期望薪资未填写',
    );
    expect(discoverySchool({}), '毕业院校未填写');
  });
  testWidgets('卡片及详情展示真实毕业院校专业毕业年与本人期望薪资', (tester) async {
    final source = ExpectationSource();
    await mount(tester, source, DirectoryContact());
    expect(find.text('8K–12K/月'), findsOneWidget);
    expect(find.text('合成理工大学 · 软件工程 · 2022届'), findsOneWidget);
    await tap(tester, 'discovery-user-101');
    await tester.scrollUntilVisible(
      find.text('期望薪资：8K–12K/月'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('discovery-profile')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('期望薪资：8K–12K/月'), findsOneWidget);
    noJobBoundContent();
  });
}

class ExpectationSource extends DirectorySource {
  Map<String, dynamic> row() => registeredProfile()
    ..addAll({
      'schoolName': '合成理工大学',
      'major': '软件工程',
      'graduationYear': 2022,
      'salaryNegotiable': 0,
      'salaryMin': 8000,
      'salaryMax': 12000,
    });
  @override
  Future<TalentPoolResult> load({
    String? keyword,
    String? tag,
    int? status,
    String? direction,
    int? archiveSource,
    TalentPoolFilters extended = const TalentPoolFilters(),
    int pageNum = 1,
  }) async => TalentPoolResult(
    rows: [row()],
    tags: const [],
    nextPage: 2,
    hasMore: false,
    limited: false,
    scannedPages: 1,
  );
  @override
  Future<Map<String, dynamic>> detail(int userId) async => row();
}
