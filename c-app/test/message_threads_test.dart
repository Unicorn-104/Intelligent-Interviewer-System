import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/messages/data/message_api.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'package:intelligent_interviewer/features/messages/domain/message_page.dart';
import 'package:intelligent_interviewer/screens/messages_screen.dart';
import 'package:intelligent_interviewer/screens/message_detail_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';
import 'company_test_support.dart' show session;

AppMessage row(
  int id, {
  AppMessageCategory category = AppMessageCategory.company,
  String? title,
}) => AppMessage(
  sourceId: id,
  category: category,
  title: title ?? '合成企业 · 企业动态',
  content: '发布了新的岗位 $id',
  occurredAt: DateTime(2026, 10, 28),
  unreadCount: 1,
  threadType: category == AppMessageCategory.hr
      ? 'HR'
      : category == AppMessageCategory.company
      ? 'COMPANY'
      : 'INTERVIEW',
  threadId: category == AppMessageCategory.hr
      ? 9
      : category == AppMessageCategory.company
      ? 7
      : 11,
  messageCount: 3,
  targetUrl: '/companies/7?positionId=$id',
);

class FakeThreads extends MessageApi {
  FakeThreads(super.client);
  final reads = <List<int>>[];
  final requests = <int?>[];
  final unread = <String, int>{'HR': 1, 'COMPANY': 3, 'SYSTEM': 2};
  bool failLoad = false;
  bool failRead = false;
  int legacyReadCalls = 0;

  @override
  Future<MessagePage> fetchThreads(String token, {AppMessage? before}) async {
    if (failLoad) throw const ApiException('消息服务暂时不可用，请稍后重试');
    return MessagePage(
      items: [
        row(30, category: AppMessageCategory.hr, title: '合成企业 HR · 招聘者'),
        row(29, title: '合成企业 · 企业动态'),
        row(
          28,
          category: AppMessageCategory.system,
          title: '合成企业 · 工程师 · 面试通知',
        ),
      ],
      hasMore: false,
      unreadCounts: Map.of(unread),
    );
  }

  @override
  Future<MessagePage> fetchEvents(
    String token,
    AppMessage thread, {
    int? beforeId,
  }) async {
    requests.add(beforeId);
    return MessagePage(
      items: beforeId == null
          ? [row(30, title: '发布工程师岗位'), row(20, title: '发布设计师岗位')]
          : [row(10, title: '发布测试岗位')],
      hasMore: beforeId == null,
    );
  }

  @override
  Future<void> markEventsRead(
    String token,
    AppMessage thread,
    List<int> ids,
  ) async {
    reads.add(List.of(ids));
    if (failRead) throw const ApiException('未读状态更新失败，请重试');
  }

  @override
  Future<void> markRead(String token, AppMessage message) async {
    legacyReadCalls++;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('中文窄屏统一消息列表与通知卡片预览', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in {
      'ReviewChinese': 'C:/Windows/Fonts/msyh.ttc',
      'MaterialIcons':
          'E:/Env/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(entry.value);
      if (file.existsSync()) {
        final loader = FontLoader(entry.key);
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
        await loader.load();
      }
    }
    final client = ApiClient();
    addTearDown(client.close);
    final api = FakeThreads(client);
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(
          textTheme: AppTheme.light.textTheme.apply(
            fontFamily: 'ReviewChinese',
          ),
          chipTheme: AppTheme.light.chipTheme.copyWith(
            labelStyle: const TextStyle(fontFamily: 'ReviewChinese'),
          ),
          appBarTheme: AppTheme.light.appBarTheme.copyWith(
            titleTextStyle: const TextStyle(
              fontFamily: 'ReviewChinese',
              fontSize: 18,
              color: AppColors.body,
            ),
          ),
        ),
        builder: (_, child) => RepaintBoundary(key: captureKey, child: child!),
        home: MessagesScreen(
          session: session,
          onUnreadChanged: (_) {},
          messageApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/message-layout-review/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('company-threads-synthetic');
    await tester.tap(find.text('合成企业 · 企业动态'));
    await tester.pumpAndSettle();
    await capture('company-history-synthetic');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('同页显示HR、企业、面试通知，企业历史逐页保留', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient();
    addTearDown(client.close);
    final api = FakeThreads(client);
    var unread = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MessagesScreen(
          session: session,
          onUnreadChanged: (value) => unread = value,
          messageApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(unread, 6);
    expect(find.text('合成企业 HR · 招聘者'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('合成企业 · 工程师 · 面试通知'), findsOneWidget);
    await tester.tap(find.text('合成企业 · 企业动态'));
    await tester.pumpAndSettle();
    expect(find.text('发布工程师岗位'), findsOneWidget);
    expect(find.text('发布设计师岗位'), findsOneWidget);
    expect(find.text('企业发布记录，最新动态在前'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('event-20'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('event-30'))).dy),
    );
    expect(api.legacyReadCalls, 0);
    expect(api.reads, [
      [30, 20],
    ]);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('查看岗位'), findsNWidgets(2));
    await tester.ensureVisible(find.text('加载更早记录'));
    await tester.tap(find.text('加载更早记录'));
    await tester.pumpAndSettle();
    expect(api.requests, [null, 20]);
    expect(api.reads, [
      [30, 20],
      [10],
    ]);
    expect(find.byKey(const ValueKey('event-10')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('event-10'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('event-20'))).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('统一列表加载失败后可重试恢复所有类型', (tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    final api = FakeThreads(client)..failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          session: session,
          onUnreadChanged: (_) {},
          messageApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('消息加载失败'), findsOneWidget);
    api.failLoad = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('消息加载失败'), findsNothing);
    expect(find.text('合成企业 HR · 招聘者'), findsOneWidget);
    expect(find.text('合成企业 · 企业动态'), findsOneWidget);
    expect(find.text('合成企业 · 工程师 · 面试通知'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('已读请求失败仍显示通知并允许重试', (tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    final api = FakeThreads(client)..failRead = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MessageDetailScreen(
          message: row(30),
          session: session,
          messageApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('发布工程师岗位'), findsOneWidget);
    expect(find.text('未读状态更新失败，请重试'), findsOneWidget);
    api.failRead = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('未读状态更新失败，请重试'), findsNothing);
    expect(api.reads.length, 2);
    expect(tester.takeException(), isNull);
  });
}
