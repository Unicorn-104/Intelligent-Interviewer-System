import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_interview_preview.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HomeInterview appointment(int status) => HomeInterview(
  raw: {
    'appointmentId': 21,
    'candidateName': '合成候选人',
    'positionTitle': '合成岗位',
    'interviewerName': '合成面试官',
    'startTime': '2030-01-02 10:00',
    'endTime': '2030-01-02 10:45',
    'meetingUrl': 'https://meeting.example.com/synthetic',
  },
  startTime: DateTime.utc(2030, 1, 2, 2),
  status: status,
);

void main() {
  final begin = DateTime.utc(2030, 1, 2, 2);
  for (final status in [0, 1, 2, 3, -1]) {
    test('预约状态 $status 的开始条件和结束边界', () {
      final interview = appointment(status);
      expect(
        interview.canStartAt(begin.subtract(const Duration(microseconds: 1))),
        isFalse,
      );
      expect(interview.canStartAt(begin), status == 0 || status == 1);
      expect(
        interview.canStartAt(begin.add(const Duration(minutes: 44))),
        status == 0 || status == 1,
      );
      expect(
        interview.canStartAt(begin.add(const Duration(minutes: 45))),
        isFalse,
      );
    });
  }

  testWidgets('到点自动启用，到结束自动禁用，不主动进入会议', (tester) async {
    final clock = tester.binding.clock.now();
    final before = begin.subtract(const Duration(seconds: 1));
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeInterviewPreview(
            interview: appointment(1),
            now: () => before.add(tester.binding.clock.now().difference(clock)),
            onOpen: () => opened++,
          ),
        ),
      ),
    );
    final start = find.byKey(const ValueKey('home-interview-21'));
    expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<OutlinedButton>(start).onPressed, isNotNull);
    expect(opened, 0);
    await tester.tap(find.byKey(const ValueKey('home-interview-action-21')));
    expect(opened, 1);
    await tester.pump(const Duration(minutes: 45));
    expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
    expect(find.text('已失效'), findsOneWidget);
    expect(find.text('已确认'), findsNothing);
    expect(find.text('面试已失效'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-interview-action-21')));
    await tester.pumpAndSettle();
    expect(find.text('面试已失效'), findsOneWidget);
    expect(opened, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('右上状态和颜色随真实预约状态变化，卡片含完整资料', (tester) async {
    for (final sample in [
      (0, '待面试', AppColors.warning),
      (1, '已确认', AppColors.interactive),
      (2, '已取消', AppColors.textMuted),
      (3, '已完成', AppColors.success),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeInterviewPreview(
              interview: appointment(sample.$1),
              now: () => begin,
              onOpen: () {},
            ),
          ),
        ),
      );
      expect(find.text(sample.$2), findsOneWidget);
      expect(find.text('面试官：合成面试官'), findsOneWidget);
      expect(find.text('开始时间：2030-01-02 10:00'), findsOneWidget);
      expect(find.text('结束时间：2030-01-02 10:45'), findsOneWidget);
      expect(
        find.text('会议链接：https://meeting.example.com/synthetic'),
        findsNothing,
      );
      expect(find.text('查看面试'), findsNothing);
      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((value) => value.gradient != null);
      expect(
        decoration.gradient!.colors.first,
        sample.$3.withValues(alpha: .16),
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320dp 卡片字号 $scale 不溢出，未到时间禁止开始', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(36),
                child: HomeInterviewPreview(
                  interview: appointment(0),
                  now: () => begin.subtract(const Duration(minutes: 5)),
                  onOpen: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('home-interview-21')),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('未到时间仅显示小型轻提示，两秒自动消失且不进入会议', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeInterviewPreview(
            interview: appointment(0),
            now: () => begin.subtract(const Duration(minutes: 10)),
            onOpen: () => opened++,
          ),
        ),
      ),
    );
    final start = find.byKey(const ValueKey('home-interview-21'));
    expect(find.text('到预约时间后可开始'), findsNothing);
    expect(find.textContaining('meeting.example.com'), findsNothing);
    expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('home-interview-action-21')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('知道了'), findsNothing);
    expect(find.text('确定'), findsNothing);
    final hint = find.byKey(const ValueKey('home-interview-hint'));
    expect(tester.getSize(hint).width, lessThanOrEqualTo(280));
    expect(tester.getSize(hint).height, lessThan(70));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(tester.getCenter(hint).dx, closeTo(screen.center.dx, 1));
    expect(tester.getCenter(hint).dy, closeTo(screen.center.dy, 1));
    expect(
      Navigator.of(tester.element(find.byType(HomeInterviewPreview))).canPop(),
      isFalse,
    );
    expect(find.text('到预约时间后可开始'), findsOneWidget);
    expect(opened, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('到预约时间后可开始'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('常规宽度按钮靠右并与最后一行资料底部对齐', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: HomeInterviewPreview(
                interview: appointment(1),
                now: () => begin,
                onOpen: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final card = find.byType(HomeInterviewPreview);
    final start = find.byKey(const ValueKey('home-interview-21'));
    final end = find.text('结束时间：2030-01-02 10:45');
    expect(
      tester.getBottomRight(start).dx,
      closeTo(tester.getBottomRight(card).dx - 12, 1),
    );
    expect(
      tester.getBottomRight(start).dy,
      closeTo(tester.getBottomRight(end).dy, 1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('轻提示不拦截其他操作，重复点击不叠加，退出卡片即清理', (tester) async {
    var otherTapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              HomeInterviewPreview(
                interview: appointment(0),
                now: () => begin.subtract(const Duration(minutes: 10)),
                onOpen: () => fail('不得提前开始面试'),
              ),
              TextButton(
                onPressed: () => otherTapped++,
                child: const Text('其他操作'),
              ),
            ],
          ),
        ),
      ),
    );
    final action = find.byKey(const ValueKey('home-interview-action-21'));
    final hint = find.byKey(const ValueKey('home-interview-hint'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('其他操作'));
    await tester.pump();
    expect(otherTapped, 1);
    expect(hint, findsOneWidget);
    // The overlay must also pass pointer events through its visible surface.
    final overlay = tester.widget<IgnorePointer>(
      find.ancestor(of: hint, matching: find.byType(IgnorePointer)).first,
    );
    expect(overlay.ignoring, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(hint, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(hint, findsNothing);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(hint, findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final status in [0, 1, 2, 3, -1]) {
    test('预约状态 $status 仅未完成未取消的记录在结束后失效', () {
      final interview = appointment(status);
      final end = begin.add(const Duration(minutes: 45));
      expect(
        interview.isExpiredAt(end.subtract(const Duration(microseconds: 1))),
        isFalse,
      );
      expect(interview.isExpiredAt(end), status == 0 || status == 1);
      expect(
        interview.isExpiredAt(end.add(const Duration(days: 1))),
        status == 0 || status == 1,
      );
    });
  }

  test('缺少结束时间时不推测已失效，不修改原始预约状态', () {
    final interview = HomeInterview(
      raw: {'status': 0},
      startTime: begin,
      status: 0,
    );
    expect(interview.isExpiredAt(begin.add(const Duration(days: 1))), isFalse);
    expect(interview.status, 0);
  });

  testWidgets('过期面试资料卡整体呈灰色，已完成和取消保持原状态', (tester) async {
    final now = begin.add(const Duration(hours: 1));
    for (final status in [0, 1, 2, 3]) {
      var opened = 0;
      final interview = appointment(status);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeInterviewPreview(
              interview: interview,
              now: () => now,
              onOpen: () => opened++,
            ),
          ),
        ),
      );
      if (status == 0 || status == 1) {
        expect(find.text('已失效'), findsOneWidget);
        expect(find.text('待面试'), findsNothing);
        expect(
          tester.widget<Text>(find.text('合成候选人')).style!.color,
          AppColors.textMuted,
        );
        expect(
          tester.widget<Text>(find.text('合成岗位')).style!.color,
          AppColors.textMuted,
        );
        expect(
          tester.widget<Text>(find.text('面试官：合成面试官')).style!.color,
          AppColors.textMuted,
        );
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(avatar.backgroundColor, AppColors.background);
        expect((avatar.child! as Icon).color, AppColors.textMuted);
        final decoration = tester
            .widgetList<Container>(find.byType(Container))
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((value) => value.gradient != null);
        expect(
          decoration.gradient!.colors.first,
          AppColors.textMuted.withValues(alpha: .16),
        );
      } else {
        expect(find.text('已失效'), findsNothing);
        expect(find.text(status == 2 ? '已取消' : '已完成'), findsOneWidget);
      }
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('home-interview-21')),
            )
            .onPressed,
        isNull,
      );
      expect(interview.status, status);
      expect(opened, 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('岗位入口使用真实 positionId，不以预约ID替代且拒绝无效岗位ID', () {
    for (final invalid in [null, '', 'bad', 0, -1]) {
      final interview = HomeInterview(
        raw: {'appointmentId': 21, 'positionId': invalid},
        startTime: begin,
        status: 0,
      );
      expect(interview.positionId, isNull);
    }
    expect(
      HomeInterview(
        raw: {'appointmentId': 21, 'positionId': '108'},
        startTime: begin,
        status: 0,
      ).positionId,
      108,
    );
  });

  for (final minutes in [-10, 0, 60]) {
    testWidgets('卡片主体和开始按钮交互独立，时间偏移 $minutes 分钟', (tester) async {
      var jobOpened = 0;
      var meetingOpened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeInterviewPreview(
              interview: appointment(0),
              now: () => begin.add(Duration(minutes: minutes)),
              onViewJob: () => jobOpened++,
              onOpen: () => meetingOpened++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('合成岗位'));
      await tester.pump();
      expect(jobOpened, 1);
      expect(meetingOpened, 0);
      await tester.tap(find.byKey(const ValueKey('home-interview-action-21')));
      await tester.pumpAndSettle();
      expect(jobOpened, 1);
      expect(meetingOpened, minutes == 0 ? 1 : 0);
      if (minutes != 0) {
        expect(
          find.byKey(const ValueKey('home-interview-hint')),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test('候选人详情使用真实candidateId，缺失或无效时不以其他ID替代', () {
    for (final id in [null, '', 'bad', 0, -1]) {
      expect(
        HomeInterview(
          raw: {
            'candidateId': id,
            'appointmentId': 21,
            'positionId': 100,
            'userId': 999,
          },
          startTime: begin,
          status: 0,
        ).candidateId,
        isNull,
      );
    }
    expect(
      HomeInterview(
        raw: {'candidateId': '207', 'appointmentId': 21},
        startTime: begin,
        status: 0,
      ).candidateId,
      207,
    );
  });

  for (final minutes in [-10, 0, 60]) {
    testWidgets('头像、岗位卡片和开始面试分别触发独立入口，时间偏移 $minutes 分钟', (tester) async {
      var candidateOpened = 0;
      var jobOpened = 0;
      var meetingOpened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeInterviewPreview(
              interview: appointment(0),
              now: () => begin.add(Duration(minutes: minutes)),
              onViewCandidate: () => candidateOpened++,
              onViewJob: () => jobOpened++,
              onOpen: () => meetingOpened++,
            ),
          ),
        ),
      );
      final avatar = find.byKey(const ValueKey('home-interview-candidate-21'));
      expect(tester.getSize(avatar), const Size(44, 44));
      await tester.tap(avatar);
      await tester.pump();
      expect(candidateOpened, 1);
      expect(jobOpened, 0);
      expect(meetingOpened, 0);
      await tester.tap(find.text('合成岗位'));
      await tester.pump();
      expect(candidateOpened, 1);
      expect(jobOpened, 1);
      expect(meetingOpened, 0);
      await tester.tap(find.byKey(const ValueKey('home-interview-action-21')));
      await tester.pumpAndSettle();
      expect(candidateOpened, 1);
      expect(jobOpened, 1);
      expect(meetingOpened, minutes == 0 ? 1 : 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
