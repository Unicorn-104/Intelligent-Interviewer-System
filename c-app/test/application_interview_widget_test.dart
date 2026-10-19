import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/applications/data/application_api.dart';
import 'package:intelligent_interviewer/features/applications/presentation/application_screen.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/interviews/data/interview_api.dart';
import 'package:intelligent_interviewer/features/interviews/domain/interview_schedule.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/interview_calendar.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/interview_controller.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/interview_detail_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

const session = AuthSession(
  token: 'synthetic-session',
  userId: 1,
  userName: 'synthetic',
  nickName: '测试',
);

class ScenarioClient extends ApiClient {
  bool failList = false;
  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    paths.add(path);
    final uri = Uri.parse(path);
    if (uri.path == '/agent/v1/applications/7') {
      return {
        'data': {
          'id': 7,
          'jobTitle': '客户端开发工程师',
          'companyName': '示例科技',
          'status': 'interview',
          'statusText': '已约面',
          'timeline': [
            {
              'stage': 'submitted',
              'state': 'done',
              'title': '已投递',
              'description': '简历已提交，等待企业处理',
              'occurredAt': '2026-10-14T09:00:00+08:00',
            },
            {
              'stage': '2',
              'state': 'current',
              'title': '面试中',
              'description': '请关注面试安排',
              'occurredAt': '2026-10-15T09:00:00+08:00',
            },
          ],
        },
      };
    }
    if (uri.path == '/agent/v1/applications') {
      if (failList) throw const ApiException('连接超时，请重试');
      return {
        'data': {
          'items': uri.queryParameters['status'] == 'closed'
              ? <Object>[]
              : [
                  {
                    'id': 7,
                    'jobTitle': '客户端开发工程师',
                    'companyName': '示例科技',
                    'status': 'interview',
                    'statusText': '已约面',
                    'appliedAt': '2026-10-14T09:00:00+08:00',
                  },
                ],
          'page': 1,
          'size': 10,
          'total': uri.queryParameters['status'] == 'closed' ? 0 : 1,
          'hasNext': false,
        },
      };
    }
    if (uri.path == '/system/conference/session/9') {
      return {
        'data': {
          'sessionId': 9,
          'roundNo': 2,
          'totalRounds': 3,
          'mode': 2,
          'interviewerName': '示例面试官',
        },
      };
    }
    return {
      'data': [
        {
          'appointmentId': 12,
          'sessionId': 9,
          'positionTitle': '客户端开发工程师',
          'companyName': '示例科技',
          'startAt': '2026-10-15 14:30',
          'endAt': '2026-10-15 15:15',
          'statusText': '待面试',
          'mode': 2,
        },
        {
          'appointmentId': 13,
          'positionTitle': '移动端研发工程师',
          'companyName': '示例企业',
          'startAt': '2026-10-16 09:00',
          'endAt': '2026-10-16 10:00',
          'statusText': '待面试',
          'mode': 3,
        },
      ],
    };
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['CAPP_CAPTURE_UI_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    // Optional local captures use the host font; CI tests need no OS assets.
    if (Platform.environment['CAPP_CAPTURE_UI_DIR'] == null) return;
    final windows = Platform.environment['WINDIR'];
    if (windows == null) return;
    final font = File('$windows/Fonts/msyh.ttc');
    if (!await font.exists()) return;
    final bytes = ByteData.sublistView(await font.readAsBytes());
    for (final family in ['Roboto', 'Microsoft YaHei']) {
      final loader = FontLoader(family)..addFont(Future.value(bytes));
      await loader.load();
    }
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('calendar and details fit width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = ScenarioClient();
      final controller = InterviewController(
        InterviewApi(client),
        session.token,
        now: () => DateTime(2026, 10, 15, 8),
      );
      await controller.load();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 1.5 : 1),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      InterviewCalendar(
                        controller: controller,
                        onOpen: (item) async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => InterviewDetailScreen(
                                session: session,
                                appointment: item,
                                api: InterviewApi(client),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2026-10-15 · 1 场面试'), findsOneWidget);
      await capture(tester, boundary, 'interview-calendar-${width.toInt()}');
      await tester.tap(find.text('展开月历'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('16'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      expect(find.text('2026-10-16 · 1 场面试'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Return to the current day, then open a real session-backed detail.
      controller.select(DateTime(2026, 10, 15));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('客户端开发工程师').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('客户端开发工程师').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('客户端开发工程师').first);
      await tester.pumpAndSettle();
      expect(find.text('第 2 轮 / 共 3 轮'), findsOneWidget);
      expect(client.paths, contains('/system/conference/session/9'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      client.close();
    });
  }

  testWidgets(
    'application screen retries, opens timeline and filters empty records',
    (tester) async {
      final client = ScenarioClient()..failList = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ApplicationScreen(
            session: session,
            api: ApplicationApi(client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('投递记录加载失败'), findsOneWidget);
      client.failList = false;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.text('客户端开发工程师'), findsOneWidget);
      await tester.tap(find.text('查看投递进度'));
      await tester.pumpAndSettle();
      expect(find.text('面试中'), findsOneWidget);
      expect(find.text('2026-10-14 09:00'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('已结束'));
      await tester.pumpAndSettle();
      expect(find.text('暂无投递记录'), findsOneWidget);
      expect(client.paths.last, contains('status=closed'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    },
  );

  testWidgets(
    'appointments without session IDs do not query invented details',
    (tester) async {
      final client = ScenarioClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: InterviewDetailScreen(
            session: session,
            appointment: const InterviewSchedule(
              appointmentId: 4,
              positionTitle: '测试岗位',
              companyName: '示例企业',
              statusText: '待确认',
            ),
            api: InterviewApi(client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('面试场次待确认'), findsOneWidget);
      expect(client.paths, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    },
  );
}
