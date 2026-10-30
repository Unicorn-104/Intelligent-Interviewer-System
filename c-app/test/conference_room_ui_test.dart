import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/conference_controller.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/conference_room_view.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/conference_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

import 'conference_test.dart' show FakeApi, FakeMedia, controller, session;

class _Media extends FakeMedia {
  int flips = 0;
  bool mic = true, video = true;
  @override
  bool get microphoneOn => mic;
  @override
  bool get cameraOn => video;
  @override
  Future<void> toggleMicrophone() async {
    mic = !mic;
    changed();
  }

  @override
  Future<void> toggleCamera() async {
    video = !video;
    changed();
  }

  @override
  Future<void> flipCamera() async {
    flips++;
  }
}

void main() {
  Future<ConferenceController> mount(
    WidgetTester tester, {
    bool waiting = false,
    int mode = 2,
    _Media? media,
    double scale = 1,
  }) async {
    final api = FakeApi()..mode = mode;
    final c = controller(api, media ?? (_Media()..online = true));
    await c.load();
    c.phase = waiting ? ConferencePhase.waiting : ConferencePhase.meeting;
    c.progress = await api.progress(7);
    c.waiting = {
      'sessionStatus': 0,
      'participants': [
        {'userId': 12, 'role': 3, 'ready': 1},
        {'userId': 99, 'role': 'OBSERVER', 'ready': 1},
      ],
    };
    addTearDown(() {
      c.dispose();
      api.client.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: ConferenceRoomView(
            controller: c,
            session: session,
            onLeave: () {},
            onFinish: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets(
    'waiting preserves server readiness and disables media, no host controls',
    (tester) async {
      final c = await mount(tester, waiting: true);
      expect(find.text('尚未进入本场等候室'), findsOneWidget);
      expect(find.text('你已就绪，等待面试开始'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('conference-toggle-mic')));
      expect(c.media.microphoneOn, true);
      await tester.tap(find.byKey(const ValueKey('conference-more')));
      await tester.pumpAndSettle();
      expect(find.text('会议信息'), findsOneWidget);
      expect(find.text('结束面试'), findsNothing);
      expect(find.text('开始面试'), findsNothing);
      expect(find.text('邀请成员'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'meeting controls toggle media and camera flip with live feedback',
    (tester) async {
      final media = _Media()..online = true;
      await mount(tester, media: media);
      await tester.tap(find.byKey(const ValueKey('conference-toggle-mic')));
      await tester.pumpAndSettle();
      expect(media.microphoneOn, false);
      expect(find.text('解除静音'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('conference-flip-camera')));
      await tester.pumpAndSettle();
      expect(media.flips, 1);
      await tester.tap(find.byKey(const ValueKey('conference-toggle-camera')));
      await tester.pumpAndSettle();
      expect(find.text('开启视频'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('conference-flip-camera')));
      expect(media.flips, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'AI answer draft survives panels, takeover blocks submitting and finish closes panel',
    (tester) async {
      final c = await mount(tester);
      await tester.tap(find.textContaining('AI 面试 · 第'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '合成作答草稿');
      await tester.tap(find.byTooltip('关闭面板'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('AI 面试 · 第'));
      await tester.pumpAndSettle();
      expect(find.text('合成作答草稿'), findsOneWidget);
      c.progress['takeover'] = 1;
      c.changed();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交本题回答'))
            .onPressed,
        isNull,
      );
      c.phase = ConferencePhase.ended;
      c.changed();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'human-only meeting hides AI panels and fits narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, mode: 4, scale: 1.5);
      expect(
        find.byKey(const ValueKey('conference-self-preview')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('conference-members')));
      await tester.pumpAndSettle();
      expect(find.text('会议成员'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭面板'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('conference-more')));
      await tester.pumpAndSettle();
      expect(find.text('实时字幕'), findsNothing);
      expect(find.text('文字作答'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('landscape waiting room stays scrollable', (tester) async {
    tester.view.physicalSize = const Size(740, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, waiting: true);
    await tester.ensureVisible(find.byKey(const ValueKey('conference-more')));
    await tester.tap(find.byKey(const ValueKey('conference-more')));
    await tester.pumpAndSettle();
    expect(find.text('会议信息'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'answer panel handles keyboard and server finish returns to result',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final api = FakeApi()..mode = 1;
      final c = controller(api, _Media()..online = true);
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
      await c.poll();
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('AI 面试 · 第'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '合成回答');
      expect(tester.takeException(), isNull);
      await c.finish();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('感谢你的参与，请关注 HR 的后续通知。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.client.close();
    },
  );
}
