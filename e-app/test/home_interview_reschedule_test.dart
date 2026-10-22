import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_lists_page.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_page.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_section.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_reschedule_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_week_calendar.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'support/home_fixture.dart';
import 'support/talent_detail_fixture.dart';

final _clock = DateTime.utc(2030, 1, 3, 1);
Map<String, dynamic> _appointment({
  int status = 0,
  String start = '2030-01-03 10:00:00',
}) => {
  'appointmentId': 101,
  'candidateId': 11,
  'positionId': 7,
  'interviewerId': 19,
  'slotId': 71,
  'candidateName': '合成候选人',
  'positionTitle': '合成岗位',
  'stageId': 21,
  'stageOrder': 1,
  'stageName': '技术面试',
  'status': status,
  'startTime': start,
  'endTime': '2030-01-03 11:00:00',
};

class _Actions extends TalentFakeSource {
  _Actions(Map<String, dynamic> row) {
    plan = [row];
    interviewPages = [
      [row],
    ];
  }
  @override
  Future<Map<String, dynamic>> reschedule(
    int id, {
    required String newStartTime,
    int? durationMin,
    int? interviewerId,
  }) async {
    reschedules.add({
      'appointmentId': id,
      'newStartTime': newStartTime,
      'durationMin': durationMin,
      'interviewerId': interviewerId,
    });
    final start = TalentUtc8.parseServer(newStartTime)!;
    final row = {
      ...plan.first,
      'startTime': newStartTime,
      'endTime': TalentUtc8.serverTime(
        start.add(Duration(minutes: durationMin!)),
      ),
      'interviewerId': interviewerId,
    };
    plan = [row];
    interviewPages = [
      [row],
    ];
    return row;
  }
}

class _Source extends HomeFixture {
  _Source(Map<String, dynamic> row) : actions = _Actions(row);
  final _Actions actions;
  @override
  _Actions get candidateActionsSource => actions;
  @override
  DateTime get now => _clock;
  HomeInterview get item {
    final row = actions.plan.first;
    return HomeInterview(
      raw: row,
      startTime: TalentUtc8.parseServer(row['startTime'])!,
      status: row['status'] as int,
    );
  }

  @override
  Future<List<HomeInterview>> loadInterviewsOn(DateTime day) async {
    calendarCalls++;
    return [item];
  }

  @override
  Future<HomePageSlice<HomeInterview>> loadInterviews({
    int page = 1,
    int minimum = 3,
    DateTime? from,
  }) async {
    interviewCalls++;
    return HomePageSlice(page == 1 ? [item] : []);
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Source source, {
  bool more = false,
  Size size = const Size(430, 1000),
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
          alwaysUse24HourFormat: true,
        ),
        child: child!,
      ),
      home: more
          ? HomeInterviewsPage(
              source: source,
              from: _clock,
              onOpen: (_) async {},
              now: () => _clock,
            )
          : HomePage(
              dataSource: source,
              onNotifications: () {},
              onFeatures: () {},
              onInterviews: () {},
              onJobs: () {},
            ),
    ),
  );
  await tester.pumpAndSettle();
  final button = find.byKey(const ValueKey('job-interview-reschedule-101'));
  if (button.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      button,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 15,
    );
  }
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
}

Future<void> _changeTime(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('reschedule-edit')));
  await tester.pumpAndSettle();
  final edit = find.byKey(const Key('appointment-edit-time'));
  await tester.ensureVisible(edit);
  await tester.tap(edit);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), '12');
  await tester.enterText(fields.at(1), '30');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  final save = find.text('保存调整');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  for (final more in [false, true]) {
    final label = more ? '首页更多' : '首页';
    testWidgets('$label改期复用日历，确认后保存并刷新原列表', (tester) async {
      final source = _Source(_appointment());
      await _mount(tester, source, more: more);
      final reads = more ? source.interviewCalls : source.calendarCalls;
      await tester.tap(
        find.byKey(const ValueKey('job-interview-reschedule-101')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TalentInterviewRescheduleSheet), findsOneWidget);
      expect(find.byType(TalentInterviewWeekCalendar), findsOneWidget);
      expect(source.actions.reschedules, isEmpty);
      await _changeTime(tester);
      expect(find.text('确认面试改期？'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reschedule-confirm')));
      await tester.pumpAndSettle();
      expect(
        source.actions.reschedules.single['newStartTime'],
        '2030-01-03 12:30:00',
      );
      await tester.tap(find.byKey(const Key('reschedule-close')));
      await tester.pumpAndSettle();
      expect(find.byType(TalentInterviewRescheduleSheet), findsNothing);
      expect(
        more ? source.interviewCalls : source.calendarCalls,
        greaterThan(reads),
      );
      expect(find.textContaining('12:30'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
    for (final status in [2, 3]) {
      testWidgets('$label状态$status点击改期自动提示且不打开编辑', (tester) async {
        final source = _Source(_appointment(status: status));
        await _mount(tester, source, more: more);
        await tester.tap(
          find.byKey(const ValueKey('job-interview-reschedule-101')),
        );
        await tester.pumpAndSettle();
        expect(find.text('仅未开始且未取消的面试可以改期'), findsOneWidget);
        expect(find.byType(TalentInterviewRescheduleSheet), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('仅未开始且未取消的面试可以改期'), findsNothing);
        expect(source.actions.reschedules, isEmpty);
      });
    }
    testWidgets('$label已开始的面试不能改期', (tester) async {
      final source = _Source(_appointment(start: '2030-01-03 08:00:00'));
      await _mount(tester, source, more: more);
      await tester.tap(
        find.byKey(const ValueKey('job-interview-reschedule-101')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TalentInterviewRescheduleSheet), findsNothing);
      expect(find.text('仅未开始且未取消的面试可以改期'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
    testWidgets('$label改期仍阻止面试官时间冲突', (tester) async {
      final source = _Source(_appointment());
      source.actions.slots = [
        {
          'slotId': 72,
          'status': 0,
          'startTime': '2030-01-03 12:00:00',
          'endTime': '2030-01-03 14:00:00',
        },
      ];
      await _mount(tester, source, more: more);
      await tester.tap(
        find.byKey(const ValueKey('job-interview-reschedule-101')),
      );
      await tester.pumpAndSettle();
      await _changeTime(tester);
      expect(find.text('时间冲突'), findsOneWidget);
      expect(source.actions.reschedules, isEmpty);
    });
    testWidgets('${label}320dp及大字号的改期按钮无溢出', (tester) async {
      final source = _Source(_appointment());
      await _mount(
        tester,
        source,
        more: more,
        size: const Size(320, 740),
        scale: 1.6,
      );
      expect(
        find.byKey(const ValueKey('job-interview-reschedule-101')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('首页更多入口传递改期数据源', (tester) async {
    final source = _Source(_appointment());
    await _mount(tester, source);
    final section = find.ancestor(
      of: find.text('近期面试'),
      matching: find.byType(HomeSection),
    );
    final more = find.descendant(of: section, matching: find.text('更多'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byType(HomeInterviewsPage), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('job-interview-reschedule-101')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewRescheduleSheet), findsOneWidget);
  });
}
