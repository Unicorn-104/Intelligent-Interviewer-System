import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/interviews/data/conference_api.dart';
import 'package:intelligent_interviewer/features/interviews/data/conference_media.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/conference_controller.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/conference_screen.dart';
import 'package:intelligent_interviewer/features/messages/domain/interview_invitation.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'package:intelligent_interviewer/features/messages/presentation/interview_invitation_card.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

const token = 'synthetic-room-token-123456';
const invitationText =
    '【面试邀请·AI技术面试·AI+单面试官】 示例科技 Java开发工程师 视频面试，请点击链接进入：https://example.org:8445/conference-join?token=$token';
const session = AuthSession(
  token: 'synthetic-auth',
  userId: 12,
  userName: 'test',
  nickName: '测试',
);

class RealHttpOverrides extends HttpOverrides {}

class FakeMedia extends ConferenceMedia {
  bool available = false, online = false;
  int connections = 0, releases = 0;
  @override
  bool get connected => online;
  @override
  bool get cameraOn => available;
  @override
  bool get microphoneOn => available;
  @override
  Future<void> checkDevices() async {
    available = true;
    changed();
  }

  @override
  Future<void> connect(Map<String, dynamic> credentials) async {
    connections++;
    online = true;
    changed();
  }

  @override
  Future<void> release() async {
    releases++;
    online = false;
    available = false;
    changed();
  }
}

class FakeApi extends ConferenceApi {
  FakeApi() : super(ApiClient(), session.token);
  int mode = 2, status = 0, answers = 0, starts = 0, joins = 0;
  bool valid = true,
      failConsent = false,
      failFinish = false,
      failAnswer = false,
      permitted = true;
  Completer<Map<String, dynamic>>? joinGate;
  final reports = <Map<String, dynamic>>[];
  Map<String, dynamic> get info => {
    'sessionId': 7,
    'role': permitted ? 'CANDIDATE' : 'OBSERVER',
    'candidateUserId': 12,
    'mode': mode,
    'status': status,
    'positionTitle': 'Java开发工程师',
    'companyName': '示例科技',
    'appointmentStartAt': '2026-10-28 10:00:00',
    'interviewerName': '测试面试官',
  };
  @override
  Future<Map<String, dynamic>> verify(String roomToken) async => {
    'valid': valid,
    'reason': valid ? null : 'finished',
  };
  @override
  Future<Map<String, dynamic>> join(String roomToken) async {
    joins++;
    return joinGate == null ? info : joinGate!.future;
  }

  @override
  Future<Map<String, dynamic>> context(int id) async => info;
  @override
  Future<void> consent(int id, bool accepted) async {
    if (failConsent) throw const ApiException('synthetic');
  }

  @override
  Future<void> participant(int id, Map<String, dynamic> state) async {
    reports.add(state);
  }

  @override
  Future<Map<String, dynamic>> start(int id) async {
    starts++;
    status = 1;
    return info;
  }

  @override
  Future<Map<String, dynamic>> waiting(int id) async => {
    'sessionStatus': status,
    'peerReady': true,
    'peerName': '测试面试官',
  };
  @override
  Future<Map<String, dynamic>> livekit(int id) async => {
    'url': 'wss://example.org',
    'token': 'synthetic-video-token',
  };
  @override
  Future<void> media(
    int id, {
    required bool camera,
    required bool microphone,
  }) async {}
  @override
  Future<Map<String, dynamic>> asrStatus(int id) async => {'enabled': false};
  @override
  Future<Map<String, dynamic>> progress(int id) async => {
    'sessionStatus': status,
    'answeredCount': answers,
    'currentQuestionNo': answers + 1,
    'totalQuestionNo': 3,
    'question': {'topic': '请介绍一次项目经历'},
  };
  @override
  Future<List<Map<String, dynamic>>> captions(int id, int after) async => [
    {'sequence': 1, 'role': 2, 'content': '请开始回答'},
    {'sequence': 2, 'role': 3, 'content': '测试回答'},
  ];
  @override
  Future<void> heartbeat(int id) async {}
  @override
  Future<Map<String, dynamic>> answer(int id, String content) async {
    if (failAnswer) throw const ApiException('synthetic timeout');
    answers++;
    return progress(id);
  }

  @override
  Future<Map<String, dynamic>> finish(int id) async {
    if (failFinish) throw const ApiException('synthetic timeout');
    status = 2;
    return result(id);
  }

  @override
  Future<Map<String, dynamic>> result(int id) async => {
    'status': status,
    'durationSeconds': 90,
    'answeredCount': answers,
    'totalQuestionNo': 3,
    'reportStatus': 'generating',
  };
}

ConferenceController controller(FakeApi api, FakeMedia media) =>
    ConferenceController(
      api: api,
      media: media,
      userId: 12,
      roomToken: token,
      pollInterval: Duration.zero,
    );

Future<void> prepare(ConferenceController c) async {
  await c.load();
  await c.check();
  c.confirmSpeaker(true);
  await c.setConsent(true);
}

void main() {
  test(
    'legacy invitation extracts room token and does not use message host as API origin',
    () {
      final card = InterviewInvitation.parse(invitationText)!;
      expect(card.token, token);
      expect(card.description, '示例科技 Java开发工程师');
      expect(card.title, 'AI技术面试·AI+单面试官');
      final message = ChatMessage.fromJson({
        'type': 1,
        'content': invitationText,
      });
      expect(message.interviewInvitation, isNotNull);
      expect(
        InterviewInvitation.parse(
          '普通聊天 https://example.org/conference-join?token=$token',
        ),
        isNull,
      );
      expect(
        InterviewInvitation.parse(
          invitationText.replaceFirst('/conference-join', '/untrusted'),
        ),
        isNull,
      );
      expect(
        InterviewInvitation.parse('$invitationText&token=duplicate-value-1234'),
        isNull,
      );
      expect(
        InterviewInvitation.parse(
          invitationText.replaceFirst('example.org', 'user:pass@example.org'),
        ),
        isNull,
      );
      expect(
        InterviewInvitation.parse(invitationText.replaceFirst(token, 'bad')),
        isNull,
      );
    },
  );

  test(
    'conference HTTP calls use authenticated existing endpoints and expected bodies',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(
        httpClient: HttpOverrides.runWithHttpOverrides(
          () => HttpClient(),
          RealHttpOverrides(),
        ),
        baseUrl: 'http://127.0.0.1:${server.port}',
      );
      final seen = <String>[];
      server.listen((request) async {
        expect(request.headers.value('authorization'), 'Bearer synthetic-auth');
        final path = request.uri.path;
        seen.add('${request.method} $path');
        if (path.endsWith('/verify')) {
          expect(request.uri.queryParameters['token'], token);
        }
        if (request.method != 'GET') {
          final text = await utf8.decoder.bind(request).join();
          final body = text.isEmpty ? {} : jsonDecode(text) as Map;
          if (path.endsWith('/join')) expect(body['token'], token);
          if (path.endsWith('/consent')) expect(body['consent'], 1);
          if (path.endsWith('/participant-state')) {
            expect(body['ready'], 1);
            expect(body['bandwidthKbps'], isNull);
          }
          if (path.endsWith('/answers')) {
            expect(body['content'], '合成回答');
            expect(body['answerType'], 1);
          }
          if (path.endsWith('/finish')) expect(body['endReason'], 'normal');
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 200,
            'data': path.endsWith('/captions') ? [] : {'sessionId': 7},
          }),
        );
        await request.response.close();
      });
      try {
        final api = ConferenceApi(client, session.token);
        await api.verify(token);
        await api.join(token);
        await api.context(7);
        await api.consent(7, true);
        await api.participant(7, {'ready': 1});
        await api.waiting(7);
        await api.start(7);
        await api.livekit(7);
        await api.progress(7);
        await api.captions(7, 2);
        await api.heartbeat(7);
        await api.answer(7, '合成回答');
        await api.finish(7);
        await api.result(7);
        expect(
          seen,
          containsAll([
            'POST /system/conference/link/join',
            'PUT /system/conference/session/7/participant-state',
            'GET /system/conference/livekit-token/7',
            'POST /system/conference/session/7/answers',
            'POST /system/conference/session/7/finish',
          ]),
        );
      } finally {
        client.close();
        await server.close(force: true);
      }
    },
  );

  test('invalid or finished invitation never joins or opens devices', () async {
    final api = FakeApi()..valid = false;
    final media = FakeMedia();
    final c = controller(api, media);
    await c.load();
    expect(c.phase, ConferencePhase.invalid);
    expect(api.joins, 0);
    expect(media.available, false);
    c.dispose();
    api.client.close();
  });
  test('non candidate cannot use invitation to join a room', () async {
    final api = FakeApi()..permitted = false;
    final c = controller(api, FakeMedia());
    await c.load();
    expect(c.phase, ConferencePhase.invalid);
    expect(c.id, isNull);
    c.dispose();
    api.client.close();
  });
  test(
    'late invitation response after closing does not reopen or access media',
    () async {
      final api = FakeApi()..joinGate = Completer<Map<String, dynamic>>();
      final media = FakeMedia();
      final c = controller(api, media);
      final load = c.load();
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      api.joinGate!.complete(api.info);
      await load;
      expect(c.id, isNull);
      expect(media.connections, 0);
      api.client.close();
    },
  );
  test('consent failure blocks entry and never marks ready', () async {
    final api = FakeApi()..failConsent = true;
    final c = controller(api, FakeMedia());
    await prepare(c);
    expect(c.canEnter, false);
    await c.enter();
    expect(api.starts, 0);
    expect(api.reports.every((r) => r['ready'] == 0), true);
    c.dispose();
    api.client.close();
  });
  test(
    'hybrid waits for HR and follows server start, deduplicates captions, follows finish',
    () async {
      final api = FakeApi();
      final media = FakeMedia();
      final c = controller(api, media);
      await prepare(c);
      expect(c.canEnter, true);
      await c.enter();
      expect(c.phase, ConferencePhase.waiting);
      expect(api.starts, 0);
      expect(media.available, false);
      api.status = 1;
      await c.poll();
      expect(c.phase, ConferencePhase.meeting);
      expect(media.connections, 1);
      await c.poll();
      await c.poll();
      expect(c.captions.length, 2);
      api.status = 2;
      await c.poll();
      expect(c.phase, ConferencePhase.ended);
      expect(media.connected, false);
      c.dispose();
      api.client.close();
    },
  );
  test(
    'AI starts explicitly and audio is released when app backgrounds',
    () async {
      final api = FakeApi()..mode = 1;
      final media = FakeMedia();
      final c = controller(api, media);
      await prepare(c);
      await c.enter();
      expect(api.starts, 1);
      expect(c.phase, ConferencePhase.meeting);
      await c.foreground(false);
      expect(media.connected, false);
      await c.foreground(true);
      expect(media.connections, 1); // No silent camera restart.
      await c.reconnect();
      expect(media.connections, 2);
      c.dispose();
      api.client.close();
    },
  );
  test(
    'ambiguous answer failure cannot submit again until confirmed progress advances',
    () async {
      final api = FakeApi()..mode = 1;
      final c = controller(api, FakeMedia());
      await prepare(c);
      await c.enter();
      await c.poll();
      api.failAnswer = true;
      expect(await c.answer('synthetic'), false);
      expect(c.answerUncertain, true);
      api.failAnswer = false;
      expect(await c.answer('synthetic'), false);
      expect(api.answers, 0);
      await c.confirmAnswerState();
      expect(c.answerUncertain, true);
      api.answers = 1;
      await c.confirmAnswerState();
      expect(c.answerUncertain, false);
      c.dispose();
      api.client.close();
    },
  );
  test(
    'finish failure retains meeting and media; successful finish releases tracks',
    () async {
      final api = FakeApi()..mode = 1;
      final media = FakeMedia();
      final c = controller(api, media);
      await prepare(c);
      await c.enter();
      api.failFinish = true;
      await c.finish();
      expect(c.phase, ConferencePhase.meeting);
      expect(media.connected, true);
      api.failFinish = false;
      await c.finish();
      expect(c.phase, ConferencePhase.ended);
      expect(media.connected, false);
      c.dispose();
      api.client.close();
    },
  );
  testWidgets(
    'invitation card hides raw link and token and fits narrow screens with text scaling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Center(
                child: SizedBox(
                  width: 230,
                  child: InterviewInvitationCard(
                    invitation: InterviewInvitation.parse(invitationText)!,
                    onTap: () => tapped = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('https://'), findsNothing);
      expect(find.textContaining(token), findsNothing);
      await tester.tap(find.text('查看安排 · 进入面试'));
      expect(tapped, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'preparation page uses verified job, consent gate, no PC host display',
    (tester) async {
      final api = FakeApi();
      final c = controller(api, FakeMedia());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ConferenceScreen(session: session, controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Java开发工程师'), findsOneWidget);
      expect(find.text('面试准备'), findsOneWidget);
      final enter = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '进入等候室'),
      );
      expect(enter.onPressed, isNull);
      expect(find.textContaining(token), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.client.close();
    },
  );
  testWidgets(
    'human-only meeting hides AI questions, captions and answer submission',
    (tester) async {
      final api = FakeApi()
        ..mode = 4
        ..status = 1;
      final c = controller(api, FakeMedia());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ConferenceScreen(session: session, controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await c.check();
      c.confirmSpeaker(true);
      await c.setConsent(true);
      await c.enter();
      await tester.pumpAndSettle();
      expect(c.phase, ConferencePhase.meeting);
      expect(find.text('实时字幕'), findsNothing);
      expect(find.text('文字作答'), findsNothing);
      expect(find.textContaining('AI 面试进行中'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.client.close();
    },
  );
}
