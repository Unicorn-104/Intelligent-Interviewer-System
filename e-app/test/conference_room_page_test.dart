import 'package:enterprise_recruiter/features/enterprise/conference/conference_room_engine.dart';
import 'package:enterprise_recruiter/features/enterprise/conference/conference_room_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> roomSession({String role = 'HR'}) => {
  'sessionId': 101,
  'appointmentId': 202,
  'candidateUserId': 104,
  'candidateName': '张三',
  'positionTitle': 'Flutter 工程师',
  'companyName': '示例科技',
  'interviewerId': 5,
  'primaryInterviewerId': 5,
  'interviewerName': '李面试官',
  'mode': 2,
  'status': 1,
  'role': role,
  'appointmentStartAt': '2026-10-28 20:00',
  'appointmentEndAt': '2026-10-28 20:30',
  'interviewers': [
    {'userId': 5, 'userName': '李面试官', 'isPrimary': 1, 'joinStatus': 1},
  ],
};

class FakeConferenceEngine extends ConferenceRoomEngine {
  FakeConferenceEngine({this.connectError});

  final Object? connectError;
  ConferenceRoomState _state = const ConferenceRoomState(
    stage: ConferenceRoomStage.connecting,
  );
  int connects = 0;
  int disconnects = 0;
  int flips = 0;
  String? connectUrl;
  String? connectToken;
  bool? connectCanPublish;
  final List<bool> micCalls = [];
  final List<bool> cameraCalls = [];

  @override
  ConferenceRoomState get state => _state;

  void emit(ConferenceRoomState next) {
    _state = next;
    notifyListeners();
  }

  @override
  Future<void> connect({
    required String url,
    required String token,
    required bool canPublish,
  }) async {
    connects++;
    connectUrl = url;
    connectToken = token;
    connectCanPublish = canPublish;
    if (connectError != null) throw connectError!;
    emit(
      ConferenceRoomState(
        stage: ConferenceRoomStage.connected,
        localIdentity: 'u5',
        micEnabled: true,
        cameraEnabled: true,
        canPublish: canPublish,
      ),
    );
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    micCalls.add(enabled);
    emit(
      ConferenceRoomState(
        stage: _state.stage,
        localIdentity: _state.localIdentity,
        localVideoTrack: _state.localVideoTrack,
        remotes: _state.remotes,
        micEnabled: enabled,
        cameraEnabled: _state.cameraEnabled,
        canPublish: _state.canPublish,
      ),
    );
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraCalls.add(enabled);
    emit(
      ConferenceRoomState(
        stage: _state.stage,
        localIdentity: _state.localIdentity,
        localVideoTrack: _state.localVideoTrack,
        remotes: _state.remotes,
        micEnabled: _state.micEnabled,
        cameraEnabled: enabled,
        canPublish: _state.canPublish,
      ),
    );
  }

  @override
  Future<void> flipCamera() async {
    flips++;
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    emit(
      ConferenceRoomState(
        stage: ConferenceRoomStage.closed,
        canPublish: _state.canPublish,
      ),
    );
  }
}

class RoomHarness {
  RoomHarness({FakeConferenceEngine? engine})
    : engines = [engine ?? FakeConferenceEngine()];

  final List<FakeConferenceEngine> engines;
  int tokenCalls = 0;
  int joinCalls = 0;
  int heartbeatCalls = 0;
  final List<(int, Map<String, Object?>?)> finishCalls = [];
  Object? tokenError;
  Map<String, dynamic>? lastSession;

  FakeConferenceEngine get engine => engines.last;

  ConferenceRoomEngine factory() {
    if (engines.length > 1 || tokenCalls > 0) {
      engines.add(FakeConferenceEngine());
    }
    return engines.last;
  }
}

Future<RoomHarness> mountRoom(
  WidgetTester tester, {
  String role = 'HR',
  Object? tokenError,
  Object? connectError,
  Map<String, dynamic>? session,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final harness = RoomHarness(
    engine: FakeConferenceEngine(connectError: connectError),
  );
  harness.tokenError = tokenError;
  final data = session ?? roomSession(role: role);
  harness.lastSession = data;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-room'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConferenceRoomPage(
                  session: data,
                  loadToken: (sessionId) async {
                    harness.tokenCalls++;
                    if (harness.tokenError != null) throw harness.tokenError!;
                    return {
                      'url': 'ws://livekit.test',
                      'token': 'jwt-$sessionId',
                      'room': 'INTERVIEW-$sessionId',
                      'identity': 'u5',
                    };
                  },
                  finish: (sessionId, {payload}) async {
                    harness.finishCalls.add((sessionId, payload));
                  },
                  join: (sessionId) async {
                    harness.joinCalls++;
                    return {'sessionId': sessionId};
                  },
                  heartbeat: (sessionId) async {
                    harness.heartbeatCalls++;
                  },
                  engineFactory: harness.factory,
                ),
              ),
            ),
            child: const Text('打开会议室'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-room')));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('HR 入会：登记面试官、换取令牌并连接 LiveKit 展示候场界面', (tester) async {
    final harness = await mountRoom(tester);
    expect(harness.joinCalls, 1);
    expect(harness.tokenCalls, 1);
    expect(harness.engine.connects, 1);
    expect(harness.engine.connectUrl, 'ws://livekit.test');
    expect(harness.engine.connectToken, 'jwt-101');
    expect(harness.engine.connectCanPublish, isTrue);
    expect(harness.heartbeatCalls, 1);
    expect(find.text('已进入会议室，等待候选人加入…'), findsOneWidget);
    expect(find.text('Flutter 工程师'), findsOneWidget);
    expect(find.text('张三 · AI+单面试官'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('conference-toggle-mic')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('conference-toggle-camera')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('conference-members')), findsOneWidget);
    expect(find.byKey(const ValueKey('conference-more')), findsOneWidget);
    expect(find.byKey(const ValueKey('conference-end')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('麦克风与摄像头开关调用引擎并切换按钮文案', (tester) async {
    final harness = await mountRoom(tester);
    expect(find.text('静音'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conference-toggle-mic')));
    await tester.pumpAndSettle();
    expect(harness.engine.micCalls, [false]);
    expect(find.text('解除静音'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conference-toggle-camera')));
    await tester.pumpAndSettle();
    expect(harness.engine.cameraCalls, [false]);
    expect(find.text('开启视频'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conference-flip-camera')));
    await tester.pumpAndSettle();
    expect(harness.engine.flips, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('成员面板展示本人、候选人与其他面试官的加入状态', (tester) async {
    await mountRoom(tester);
    await tester.tap(find.byKey(const ValueKey('conference-members')));
    await tester.pumpAndSettle();
    expect(find.text('会议成员（1）'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('我 · 李面试官'),
      ),
      findsOneWidget,
    );
    expect(find.text('候选人 · 未加入'), findsOneWidget);
    expect(find.text('主面试官 · 已加入'), findsOneWidget);
    expect(find.text('未加入'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('会议信息面板展示岗位、企业与场次', (tester) async {
    await mountRoom(tester);
    await tester.tap(find.byKey(const ValueKey('conference-more')));
    await tester.pumpAndSettle();
    expect(find.text('会议信息'), findsOneWidget);
    expect(find.text('应聘岗位'), findsOneWidget);
    expect(find.text('示例科技'), findsOneWidget);
    expect(find.text('AI+单面试官'), findsWidgets);
    expect(find.text('#101'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('观察者只旁听：不登记面试官、不发布音视频', (tester) async {
    final harness = await mountRoom(tester, role: 'OBSERVER');
    expect(harness.joinCalls, 0);
    expect(harness.engine.connectCanPublish, isFalse);
    expect(find.text('旁听中'), findsOneWidget);
    expect(find.byKey(const ValueKey('conference-toggle-mic')), findsNothing);
    expect(
      find.byKey(const ValueKey('conference-toggle-camera')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('令牌获取失败展示错误并可重试进入会议', (tester) async {
    final harness = await mountRoom(
      tester,
      tokenError: const FormatException('视频会议服务未配置'),
    );
    expect(find.text('无法进入视频会议'), findsOneWidget);
    expect(find.text('进入视频会议失败：视频会议服务未配置'), findsOneWidget);
    expect(harness.engine.connects, 0);
    harness.tokenError = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(harness.tokenCalls, 2);
    expect(harness.engines.length, 2);
    expect(harness.engine.connects, 1);
    expect(find.text('已进入会议室，等待候选人加入…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('连接失败展示断线原因并允许返回', (tester) async {
    final harness = await mountRoom(
      tester,
      connectError: const FormatException('信令握手超时'),
    );
    expect(find.text('无法进入视频会议'), findsOneWidget);
    expect(find.text('进入视频会议失败：信令握手超时'), findsOneWidget);
    expect(harness.engine.disconnects, 1);
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('打开会议室'), findsOneWidget);
    expect(find.byType(ConferenceRoomPage), findsNothing);
  });

  testWidgets('结束面试：二次确认后提交结束、断开连接并返回', (tester) async {
    final harness = await mountRoom(tester);
    await tester.tap(find.byKey(const ValueKey('conference-end')));
    await tester.pumpAndSettle();
    expect(find.text('确认结束本次面试？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conference-confirm-end')));
    await tester.pumpAndSettle();
    expect(harness.finishCalls, hasLength(1));
    expect(harness.finishCalls.single.$1, 101);
    expect(harness.finishCalls.single.$2, {'endReason': 'normal'});
    expect(harness.engine.disconnects, 1);
    expect(find.text('打开会议室'), findsOneWidget);
    expect(find.byType(ConferenceRoomPage), findsNothing);
  });

  testWidgets('离开会议不结束面试：直接断开连接返回', (tester) async {
    final harness = await mountRoom(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('离开会议'), findsOneWidget);
    expect(find.text('结束面试'), findsOneWidget);
    await tester.tap(find.text('离开会议'));
    await tester.pumpAndSettle();
    expect(harness.finishCalls, isEmpty);
    expect(harness.engine.disconnects, 1);
    expect(find.text('打开会议室'), findsOneWidget);
  });

  testWidgets('会议计时与心跳周期性推进', (tester) async {
    final harness = await mountRoom(tester);
    await tester.pump(const Duration(seconds: 65));
    expect(find.text('01:05'), findsOneWidget);
    expect(harness.heartbeatCalls, greaterThanOrEqualTo(5));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
