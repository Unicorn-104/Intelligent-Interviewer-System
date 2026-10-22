import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/ai/data/ai_api.dart';
import 'package:intelligent_interviewer/features/ai/domain/ai_models.dart';
import 'package:intelligent_interviewer/features/ai/presentation/ai_chat_controller.dart';
import 'package:intelligent_interviewer/features/ai/presentation/ai_chat_screen.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/resume/data/resume_api.dart';
import 'package:intelligent_interviewer/features/resume/domain/app_resume.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

class FakeResumeApi extends ResumeApi {
  FakeResumeApi() : super(ApiClient());
  @override
  Future<List<AppResume>> list(String token) async => [];
}

class FakeAiApi extends AiApi {
  FakeAiApi() : super(ApiClient());
  final stream = StreamController<AiEvent>.broadcast();
  final requests = <String>[];
  final contents = <String>[];
  final resumeIds = <int?>[];
  final applicationIds = <int?>[];
  final actions = <String>[];
  final cursors = <int>[];
  bool failStart = false;
  bool failed = false;
  bool failBeforeSubscribe = false;
  Completer<Map<String, dynamic>>? pendingRun;
  bool active = false;
  bool completed = false;
  int creates = 0;
  int messageReads = 0;
  @override
  Future<AiSession> createSession(String token) async {
    creates++;
    return const AiSession('session', '新对话');
  }

  @override
  Future<Map<String, dynamic>> messages(
    String token,
    String id, {
    int? before,
  }) async {
    messageReads++;
    return {
      'items': [
        if (failed)
          {
            'role': 'user',
            'content': '请润色这段模拟文字',
            'runId': 'failed-run',
            'runStatus': 'FAILED',
          },
        if (completed)
          {
            'role': 'assistant',
            'content': '完整回答',
            'runId': 'run',
            'runStatus': 'COMPLETED',
          },
      ],
      'hasNext': false,
      'activeRunId': active ? 'run' : null,
    };
  }

  @override
  Future<Map<String, dynamic>> start(
    String token,
    String id, {
    required String content,
    required String requestId,
    int? resumeId,
    int? applicationId,
    String action = 'chat',
  }) async {
    requests.add(requestId);
    contents.add(content);
    resumeIds.add(resumeId);
    applicationIds.add(applicationId);
    actions.add(action);
    if (failStart) throw const ApiException('超时');
    active = !failBeforeSubscribe;
    failed = failBeforeSubscribe;
    return {'id': 'run', 'status': 'RUNNING'};
  }

  @override
  Future<Map<String, dynamic>> run(String token, String runId) async =>
      pendingRun != null
      ? await pendingRun!.future
      : {
          'id': runId,
          'status': 'FAILED',
          'resumeId': 5,
          'errorCode': 'CONNECTION_FAILED',
        };

  @override
  Stream<AiEvent> events(String token, String runId, int after) {
    cursors.add(after);
    return stream.stream;
  }

  @override
  Future<void> cancel(String token, String runId) async {
    active = false;
  }
}

void main() {
  test(
    'output limit ends streaming with a specific actionable error',
    () async {
      final api = FakeAiApi()..active = true;
      final controller = AiChatController(api, 'synthetic-token', 'session');
      addTearDown(() async {
        controller.dispose();
        api.client.close();
        await api.stream.close();
      });
      await controller.load();
      api.stream.add(const AiEvent(1, 'delta', {'text': '模拟未完成回答'}));
      await Future<void>.delayed(Duration.zero);
      expect(controller.draft, '模拟未完成回答');
      api.active = false;
      api.stream.add(
        const AiEvent(2, 'done', {
          'status': 'FAILED',
          'errorCode': 'OUTPUT_LIMIT',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.busy, isFalse);
      expect(controller.error, '回答已达到长度上限，请将问题拆分后重试');
      expect(
        controller.messages.where((message) => message.role == 'assistant'),
        isEmpty,
      );
    },
  );

  test(
    'failed history restores reason and regenerates original question',
    () async {
      final api = FakeAiApi()..failed = true;
      final controller = AiChatController(api, 'synthetic-token', 'session');
      addTearDown(() async {
        controller.dispose();
        api.client.close();
        await api.stream.close();
      });
      await controller.load();
      expect(controller.error, 'AI 服务连接失败，请检查网络后重新生成');
      expect(controller.canRetry, true);
      final pending = Completer<Map<String, dynamic>>();
      api.pendingRun = pending;
      final retry = controller.retry();
      expect(await controller.retry(), false);
      pending.complete({'status': 'FAILED', 'resumeId': 5});
      expect(await retry, true);
      expect(api.contents, ['请润色这段模拟文字']);
      expect(api.resumeIds, [5]);
      expect(api.creates, 0);
      expect(controller.error, isNull);
      expect(controller.canRetry, false);
    },
  );

  test(
    'failure before stream subscription remains visible and retryable',
    () async {
      final api = FakeAiApi()..failBeforeSubscribe = true;
      final controller = AiChatController(api, 'synthetic-token', null);
      addTearDown(() async {
        controller.dispose();
        api.client.close();
        await api.stream.close();
      });
      expect(await controller.send('请润色这段模拟文字', 5), true);
      expect(controller.error, 'AI 服务连接失败，请检查网络后重新生成');
      expect(controller.canRetry, true);
      api.failBeforeSubscribe = false;
      expect(await controller.retry(), true);
      expect(api.requests, hasLength(2));
      expect(api.requests[0], isNot(api.requests[1]));
      expect(api.creates, 1);
      expect(api.cursors, [0]);
    },
  );

  test('retry ignores metadata arriving after disposal', () async {
    final api = FakeAiApi()..failed = true;
    final controller = AiChatController(api, 'synthetic-token', 'session');
    await controller.load();
    api.pendingRun = Completer<Map<String, dynamic>>();
    final retry = controller.retry();
    controller.dispose();
    api.pendingRun!.complete({'status': 'FAILED', 'resumeId': 5});
    expect(await retry, false);
    expect(api.requests, isEmpty);
    api.client.close();
    await api.stream.close();
  });

  testWidgets('failed answer offers regeneration and starts a new run', (
    tester,
  ) async {
    final api = FakeAiApi()..failed = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AiChatScreen(
          api: api,
          conversation: const AiSession('session', 'test'),
          session: const AuthSession(
            token: 'synthetic-token',
            userId: 17,
            userName: 'test',
            nickName: 'test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('重新生成'), findsOneWidget);
    expect(find.text('刷新'), findsNothing);
    await tester.tap(find.text('重新生成'));
    await tester.pump();
    expect(api.requests, hasLength(1));
    expect(api.contents.single, '请润色这段模拟文字');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.client.close();
    await api.stream.close();
  });

  test(
    'new chat is local until first send and does not require a resume',
    () async {
      final api = FakeAiApi();
      final controller = AiChatController(api, 'synthetic-token', null);
      addTearDown(() async {
        controller.dispose();
        api.client.close();
        await api.stream.close();
      });
      await controller.load();
      expect(api.creates, 0);
      expect(api.messageReads, 0);
      expect(await controller.send('你好，解释一下什么是递归', null), true);
      expect(api.creates, 1);
      expect(api.requests, hasLength(1));
    },
  );

  testWidgets('assistant opens directly with composer and optional shortcuts', (
    tester,
  ) async {
    final api = FakeAiApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AiChatScreen(
          embedded: true,
          api: api,
          session: const AuthSession(
            token: 'synthetic-token',
            userId: 17,
            userName: 'test',
            nickName: 'test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('想聊什么，直接输入…'), findsOneWidget);
    expect(find.text('岗位推荐'), findsOneWidget);
    expect(find.text('换一换'), findsOneWidget);
    expect(api.creates, 0);
    expect(api.messageReads, 0);
    await tester.tap(find.text('换一换'));
    await tester.pump();
    expect(find.text('给我解释一个技术概念'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.client.close();
    await api.stream.close();
  });
  testWidgets('chat fits narrow large-text screen and shows persisted answer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeAiApi()..completed = true;
    final resumeApi = FakeResumeApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: AiChatScreen(
          session: const AuthSession(
            token: 'synthetic-token',
            userId: 17,
            userName: 'test',
            nickName: 'test',
          ),
          conversation: const AiSession('session', 'test'),
          api: api,
          resumeApi: resumeApi,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('完整回答'), findsOneWidget);
    expect(find.byTooltip('发送'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.client.close();
    await api.stream.close();
  });
  test(
    'SSE decoder handles UTF8 chunks, heartbeat and multiline payload',
    () async {
      final bytes = utf8.encode(
        ':keepalive\n\nid: 9\nevent: delta\ndata: {"text":\ndata: "你好"}\n\n',
      );
      final chunks = bytes.map((byte) => [byte]);
      final events = await decodeAiEvents(
        Stream.fromIterable(
          chunks,
        ).transform(utf8.decoder).transform(const LineSplitter()),
      ).toList();
      expect(events, hasLength(1));
      expect(events.single.id, 9);
      expect(events.single.type, 'delta');
      expect(events.single.data['text'], '你好');
    },
  );

  test('resuming stream does not duplicate events and loading ends', () async {
    final api = FakeAiApi()..active = true;
    final controller = AiChatController(api, 'synthetic-token', 'session');
    addTearDown(() async {
      controller.dispose();
      api.client.close();
      await api.stream.close();
    });
    await controller.load();
    expect(controller.loading, false);
    api.stream.add(const AiEvent(1, 'delta', {'text': '你好'}));
    await Future<void>.delayed(Duration.zero);
    expect(controller.draft, '你好');
    await controller.reconnect();
    expect(api.cursors, [0, 1]);
    api.stream.add(const AiEvent(1, 'delta', {'text': '你好'}));
    api.stream.add(const AiEvent(2, 'delta', {'text': '世界'}));
    await Future<void>.delayed(Duration.zero);
    expect(controller.draft, '你好世界');
    api.active = false;
    api.completed = true;
    api.stream.add(const AiEvent(3, 'done', {'status': 'COMPLETED'}));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.busy, false);
    expect(controller.messages.single.content, '完整回答');
    expect(controller.draft, isEmpty);
  });

  test(
    'ambiguous send failure reuses requestId and blocks duplicate send',
    () async {
      final api = FakeAiApi()..failStart = true;
      final controller = AiChatController(api, 'synthetic-token', 'session');
      addTearDown(() async {
        controller.dispose();
        api.client.close();
        await api.stream.close();
      });
      expect(await controller.send('相同问题', 5), false);
      api.failStart = false;
      expect(await controller.send('相同问题', 5), true);
      expect(api.requests[0], api.requests[1]);
      expect(controller.sending, false);
      expect(await controller.send('不应重复', 5), false);
      expect(api.requests, hasLength(2));
      await controller.stop();
      expect(controller.busy, false);
    },
  );

  test('dispose ignores late stream callbacks', () async {
    final api = FakeAiApi()..active = true;
    final controller = AiChatController(api, 'synthetic-token', 'session');
    await controller.load();
    controller.dispose();
    api.stream.add(const AiEvent(1, 'delta', {'text': 'late'}));
    await Future<void>.delayed(Duration.zero);
    expect(controller.draft, isEmpty);
    api.client.close();
    await api.stream.close();
  });
}
