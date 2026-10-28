import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_contact_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_pool_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DiscoveryContact extends TalentContactDataSource {
  int targetCalls = 0, sessionCalls = 0;
  final sends = <(int, String)>[];
  int? requestedTalent;
  Completer<void>? sendGate;
  Completer<TalentContactTarget>? targetGate;
  bool missingIdentity = false;
  ApiException? sendError;
  Map<String, dynamic>? session;
  @override
  Future<TalentContactTarget> loadTarget(int talentId) async {
    targetCalls++;
    requestedTalent = talentId;
    if (missingIdentity) throw const FormatException('候选人未关联可沟通账号');
    return targetGate?.future ??
        const TalentContactTarget(userId: 99, name: '合成候选人', avatar: '');
  }

  @override
  Future<Map<String, dynamic>?> findSession(TalentContactTarget target) async {
    sessionCalls++;
    return session;
  }

  @override
  Future<Map<String, dynamic>> sendGreeting(
    TalentContactTarget target,
    String text,
  ) async {
    sends.add((target.userId, text));
    await sendGate?.future;
    if (sendError != null) throw sendError!;
    return {'sessionId': 8, 'peerId': target.userId, 'peerName': target.name};
  }
}

class DiscoveryPool {
  final calls = <Map<String, Object?>>[];
  bool optionsFail = false;
  final rows = List.generate(
    25,
    (i) => <String, dynamic>{
      'talentId': i + 11,
      'name': '合成候选人${i + 11}',
      'status': 2,
      'tags': 'Java',
      'jobDirection': '合成Java方向',
      'archiveSource': 3,
    },
  );
  TalentPoolDataSource get source => TalentPoolDataSource(
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
          return rows
              .where(
                (r) =>
                    (status == null || r['status'] == status) &&
                    (direction == null || r['jobDirection'] == direction) &&
                    (archiveSource == null ||
                        r['archiveSource'] == archiveSource) &&
                    (tag == null || r['tags'] == tag),
              )
              .skip((pageNum - 1) * pageSize)
              .take(pageSize)
              .toList();
        },
    optionsLoader: () async {
      if (optionsFail) throw const ApiException('合成选项失败');
      return {
        'directions': ['合成Java方向', '合成产品方向'],
        'tags': ['Java'],
      };
    },
  );
}

void main() {
  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    DiscoveryPool pool,
    DiscoveryContact contact, {
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
          source: pool.source,
          contactSource: contact,
          chatBuilder: (session) => Scaffold(
            appBar: AppBar(title: const Text('合成聊天页')),
            body: Text('合成会话${session['sessionId']} 对方${session['peerId']}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('方向和状态作为草稿编辑，确定才查询，移除的条件不再发送', (tester) async {
    final pool = DiscoveryPool();
    await mount(tester, pool, DiscoveryContact());
    await tap(tester, 'talent-filter-open');
    await tap(tester, 'talent-filter-direction-合成Java方向');
    await tap(tester, 'talent-filter-category-1');
    await tap(tester, 'talent-filter-status-2');
    expect(find.text('候选人标签'), findsNothing);
    expect(find.text('归档来源'), findsNothing);
    expect(pool.calls, hasLength(1));
    await tap(tester, 'talent-filter-apply');
    expect(pool.calls.last, {
      'keyword': '',
      'tag': null,
      'direction': '合成Java方向',
      'archiveSource': null,
      'status': 2,
      'pageNum': 1,
      'pageSize': 20,
    });
    expect(find.byTooltip('筛选(2)'), findsOneWidget);
    final more = find.byKey(const Key('talent-load-more'));
    await tester.scrollUntilVisible(
      more,
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('talent-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tap(tester, 'talent-load-more');
    expect(pool.calls.last['pageNum'], 2);
    final footer = find.text('已加载 25 位候选人');
    await tester.scrollUntilVisible(
      footer,
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('talent-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(footer, findsOneWidget);
    await tap(tester, 'talent-filter-open');
    await tap(tester, 'talent-filter-clear');
    expect(pool.calls, hasLength(3));
    await tap(tester, 'talent-filter-close');
    expect(find.byTooltip('筛选(2)'), findsOneWidget);
    await tap(tester, 'talent-clear');
    expect(pool.calls.last['direction'], isNull);
    expect(pool.calls.last['archiveSource'], isNull);
    expect(pool.calls.last['status'], isNull);
    expect(pool.calls.last['pageNum'], 1);
  });

  testWidgets('从嵌套页面打开筛选时覆盖底部导航，关闭恢复原页面', (tester) async {
    final pool = DiscoveryPool();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: const SizedBox(
            key: Key('synthetic-bottom-navigation'),
            height: 64,
            child: Center(child: Text('合成底部导航')),
          ),
          body: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => TalentPage(source: pool.source),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('synthetic-bottom-navigation')).hitTestable(),
      findsOneWidget,
    );
    await tap(tester, 'talent-filter-open');
    expect(
      find.byKey(const Key('synthetic-bottom-navigation')).hitTestable(),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('talent-filter-close'))).dy,
      lessThan(16),
    );
    final apply = tester.getRect(find.byKey(const Key('talent-filter-apply')));
    expect(
      apply.bottom,
      greaterThan(
        tester
            .getRect(find.byKey(const Key('synthetic-bottom-navigation')))
            .top,
      ),
    );
    await tap(tester, 'talent-filter-close');
    expect(
      find.byKey(const Key('synthetic-bottom-navigation')).hitTestable(),
      findsOneWidget,
    );
    expect(pool.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('筛选选项失败可重试，不清空列表，不自动应用任何条件', (tester) async {
    final pool = DiscoveryPool()..optionsFail = true;
    await mount(tester, pool, DiscoveryContact());
    await tap(tester, 'talent-filter-open');
    expect(find.textContaining('筛选选项暂不可用'), findsOneWidget);
    pool.optionsFail = false;
    await tester.tap(find.text('重试读取筛选项'));
    await tester.pumpAndSettle();
    expect(find.text('合成Java方向'), findsOneWidget);
    await tap(tester, 'talent-filter-close');
    expect(find.byKey(const Key('talent-card-11')), findsOneWidget);
    expect(pool.calls, hasLength(1));
  });

  testWidgets('主动联系不自动发送，首次招呼语发送一次后用真实用户进入聊天', (tester) async {
    final contact = DiscoveryContact()..sendGate = Completer<void>();
    await mount(tester, DiscoveryPool(), contact);
    await tap(tester, 'talent-contact-11');
    expect(contact.requestedTalent, 11);
    expect(contact.sends, isEmpty);
    await tester.enterText(
      find.byKey(const Key('talent-contact-input')),
      '合成主动联系内容',
    );
    await tester.tap(find.byKey(const Key('talent-contact-send')));
    await tester.pump();
    expect(contact.sends, [(99, '合成主动联系内容')]);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('talent-contact-send')))
          .onPressed,
      isNull,
    );
    contact.sendGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('合成会话8 对方99'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('talent-card-11')), findsOneWidget);
    expect(contact.sends, hasLength(1));
  });

  testWidgets('已有会话复用，不发送重复招呼语；未关联账号不能打开错误聊天', (tester) async {
    final contact = DiscoveryContact()
      ..session = {'sessionId': 9, 'peerId': 99};
    await mount(tester, DiscoveryPool(), contact);
    await tap(tester, 'talent-contact-11');
    expect(find.byKey(const Key('talent-contact-input')), findsNothing);
    await tap(tester, 'talent-contact-continue');
    expect(find.text('合成会话9 对方99'), findsOneWidget);
    expect(contact.sends, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    contact.missingIdentity = true;
    await tap(tester, 'talent-contact-11');
    expect(find.textContaining('未关联可沟通账号'), findsOneWidget);
    expect(find.byKey(const Key('talent-contact-send')), findsNothing);
    expect(find.byKey(const Key('talent-contact-continue')), findsNothing);
  });

  testWidgets('发送超时锁定重发，刷新找到会话后由HR进入核对，不自动重试', (tester) async {
    final contact = DiscoveryContact()..sendError = const ApiException('合成超时');
    await mount(tester, DiscoveryPool(), contact);
    await tap(tester, 'talent-contact-11');
    await tester.enterText(
      find.byKey(const Key('talent-contact-input')),
      '合成网络待核对内容',
    );
    await tap(tester, 'talent-contact-send');
    expect(find.textContaining('发送结果待核对'), findsOneWidget);
    expect(find.byKey(const Key('talent-contact-send')), findsNothing);
    contact.session = {'sessionId': 8, 'peerId': 99};
    await tap(tester, 'talent-contact-retry');
    expect(contact.sends, hasLength(1));
    await tap(tester, 'talent-contact-continue');
    expect(find.text('合成会话8 对方99'), findsOneWidget);
    expect(contact.sends, hasLength(1));
  });

  testWidgets('读取候选人期间关闭弹层，迟到结果不会setState', (tester) async {
    final contact = DiscoveryContact()
      ..targetGate = Completer<TalentContactTarget>();
    await mount(tester, DiscoveryPool(), contact);
    await tap(tester, 'talent-contact-11');
    await tap(tester, 'talent-contact-close');
    contact.targetGate!.complete(
      const TalentContactTarget(userId: 99, name: '合成候选人', avatar: ''),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(contact.sends, isEmpty);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('人才筛选与沟通在$size大字号和键盘下可用', (tester) async {
      final pool = DiscoveryPool();
      await mount(tester, pool, DiscoveryContact(), size: size, scale: 2);
      expect(tester.takeException(), isNull, reason: 'list');
      await tap(tester, 'talent-filter-open');
      for (var i = 0; i < 6; i++) {
        await tap(tester, 'talent-filter-category-$i');
        expect(tester.takeException(), isNull, reason: 'category$i');
      }
      await tap(tester, 'talent-filter-category-4');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const Key('talent-filter-city')),
        '合成城市',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'filter keyboard');
      tester.view.resetViewInsets();
      await tap(tester, 'talent-filter-close');
      await tap(tester, 'talent-contact-11');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      await tester.enterText(
        find.byKey(const Key('talent-contact-input')),
        '合成输入内容',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'contact keyboard');
      await tester.ensureVisible(find.byKey(const Key('talent-contact-send')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
