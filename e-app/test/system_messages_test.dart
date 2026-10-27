import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/system_notifications_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/chat_composer.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/message_center_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/system_message_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/system_message_icon.dart';

import 'message_center_page_test.dart' show FakeMessageSource, mountMessages;
import 'support/fake_enterprise_ai_source.dart';

SystemMessage notice(
  int id,
  String title,
  String content, {
  bool read = false,
}) => SystemMessage.fromJson({
  'messageId': id,
  'title': title,
  'content': content,
  'isRead': read,
  'createdAt': '2026-10-26 12:00:00',
});

void main() {
  setUpAll(() async {
    final font = File(
      '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/msyh.ttc',
    );
    if (await font.exists()) {
      await (FontLoader(
        'PreviewSans',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    }
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final icon = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icon.exists()) {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(icon.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });

  testWidgets('系统消息无通知也固定置顶，真实空态且无回复功能', (tester) async {
    final source = FakeMessageSource()..notices = [];
    await mountMessages(tester, source);
    final system = find.byKey(const Key('messages-system'));
    expect(system, findsOneWidget);
    expect(find.text('面试提醒、投递动态、报告通知'), findsOneWidget);
    expect(
      tester.getTopLeft(system).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('message-session-8'))).dy,
      ),
    );
    await tester.tap(system);
    await tester.pumpAndSettle();
    expect(find.text('暂无系统消息'), findsOneWidget);
    expect(find.text('系统通知无需回复'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ChatComposer), findsNothing);
    expect(source.sends, isEmpty);
    expect(source.readNotices, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('点击系统消息入口直接显示铃铛气泡全文，时间在框外，无列表卡片', (tester) async {
    const content = '候选人：合成候选人\n岗位：客户端开发工程师\n面试将于14:00开始，请提前做好准备。';
    final source = FakeMessageSource()
      ..notices = [notice(21, '面试即将开始', content)];
    await mountMessages(tester, source);
    await tester.tap(find.byKey(const Key('messages-system')));
    await tester.pumpAndSettle();
    expect(find.byType(SystemMessageDetailPage), findsNothing);
    expect(find.byType(SystemMessageIcon), findsOneWidget);
    expect(find.text(content), findsOneWidget);
    expect(tester.widget<Text>(find.text(content)).maxLines, isNull);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Card), findsNothing);
    final body = tester.getRect(
      find.byKey(const ValueKey('system-notice-body-21')),
    );
    final icon = tester.getRect(find.byType(SystemMessageIcon));
    final time = tester.getRect(
      find.byKey(const ValueKey('system-notice-time-21')),
    );
    expect(icon.right, lessThan(body.left));
    expect(time.top, greaterThan(body.bottom));
    expect(time.left, closeTo(body.left, .01));
    expect(find.text('系统通知无需回复'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(source.readNotices, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('嵌套导航从入口打开系统气泡页覆盖底部主导航，返回恢复', (tester) async {
    final source = FakeMessageSource()..notices = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: const SizedBox(
            key: Key('app-tabs'),
            height: 60,
            child: Text('首页 岗位 消息 我的'),
          ),
          body: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => MessageCenterPage(
                source: source,
                assistantSource: FakeEnterpriseAiSource(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-tabs')), findsOneWidget);
    await tester.tap(find.byKey(const Key('messages-system')));
    await tester.pumpAndSettle();
    expect(find.byType(SystemNotificationsPage), findsOneWidget);
    expect(find.byKey(const Key('app-tabs')), findsNothing);
    expect(find.text('系统通知无需回复'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-tabs')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('通知入口展示最新摘要与未读，不需要先有普通聊天', (tester) async {
    final source = FakeMessageSource()
      ..sessions = []
      ..notices = [notice(21, '面试报告已生成', '合成报告内容')];
    await mountMessages(tester, source);
    expect(find.text('系统消息'), findsOneWidget);
    expect(find.text('面试报告已生成'), findsOneWidget);
    expect(find.byKey(const Key('messages-system')), findsOneWidget);
    expect(source.readNotices, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('点击通知只标记该条已读，展示正文且没有发送入口', (tester) async {
    final source = FakeMessageSource()
      ..notices = [
        notice(21, '面试即将开始', '候选人：合成候选人\n岗位：合成岗位\n面试将于今天14:00开始，请提前做好准备。'),
        notice(20, '收到新的简历投递', '合成投递通知'),
      ];
    await mountMessages(tester, source);
    await tester.tap(find.byKey(const Key('messages-system')));
    await tester.pumpAndSettle();
    expect(source.readNotices, isEmpty);
    await tester.tap(find.byKey(const ValueKey('system-message-21')));
    await tester.pumpAndSettle();
    expect(source.readNotices, [21]);
    expect(find.byType(SystemMessageDetailPage), findsOneWidget);
    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('系统通知无需回复'), findsOneWidget);
    expect(find.byType(SystemMessageIcon), findsOneWidget);
    expect(find.byKey(const Key('system-notice-time')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('system-notice-time'))).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('system-notice-bubble'))).dy,
      ),
    );
    expect(find.textContaining('面试将于今天14:00开始'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(source.sends, isEmpty);
    expect(source.notices.last.isRead, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('系统消息页面轮询可收到新通知，后台停止且销毁不再请求', (tester) async {
    final source = FakeMessageSource()..notices = [];
    await tester.pumpWidget(
      MaterialApp(home: SystemNotificationsPage(source: source)),
    );
    await tester.pumpAndSettle();
    final before = source.noticeCalls;
    source.notices = [notice(21, '收到新的简历投递', '合成投递内容')];
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(source.noticeCalls, greaterThan(before));
    expect(find.text('收到新的简历投递'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = source.noticeCalls;
    await tester.pump(const Duration(seconds: 30));
    expect(source.noticeCalls, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(source.noticeCalls, greaterThan(paused));
    await tester.pumpWidget(const SizedBox());
    final disposed = source.noticeCalls;
    await tester.pump(const Duration(seconds: 60));
    expect(source.noticeCalls, disposed);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('通知入口与详情在$size大字号下可读且无回复框', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FakeMessageSource()
        ..notices = [notice(21, '面试即将开始', '合成长通知内容 ' * 20)];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: SystemNotificationsPage(source: source),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('面试即将开始'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('详情返回保留列表且已读请求不重复提交', (tester) async {
    final source = FakeMessageSource()
      ..notices = [notice(21, '面试提醒', '合成通知正文')];
    await mountMessages(tester, source);
    await tester.tap(find.byKey(const Key('messages-system')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('system-message-21')));
    await tester.pumpAndSettle();
    expect(source.readNotices, [21]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SystemNotificationsPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('system-message-21')));
    await tester.pumpAndSettle();
    expect(source.readNotices, [21]);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('生成系统消息入口和通知页合成预览', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = FakeMessageSource()
      ..notices = [
        notice(
          23,
          '面试即将开始',
          '候选人：合成候选人\n岗位：Flutter开发工程师\n面试将于今天14:00开始，请提前做好准备。',
        ),
        notice(22, '面试报告已生成', '候选人：合成候选人\n岗位：客户端开发工程师\n面试报告已生成，请前往面试复核页面查看。'),
        notice(
          21,
          '收到新的简历投递',
          '候选人：合成求职者\n岗位：产品经理\n已向该岗位投递简历，请前往岗位候选人列表查看。',
          read: true,
        ),
      ];
    Future<void> snapshot(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('notice-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/system-notice-preview').create(recursive: true);
        await File('build/system-notice-preview/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final theme = AppTheme.light.copyWith(
      textTheme: AppTheme.light.textTheme.apply(fontFamily: 'PreviewSans'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: const ValueKey('notice-preview'),
          child: MessageCenterPage(
            source: source,
            assistantSource: FakeEnterpriseAiSource(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await snapshot('entry');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: const ValueKey('notice-preview'),
          child: SystemNotificationsPage(source: source),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await snapshot('notices');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: const ValueKey('notice-preview'),
          child: SystemMessageDetailPage(message: source.notices.first),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await snapshot('detail');
    await tester.pumpWidget(const SizedBox());
  });
}
