import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/job_detail_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_interviews_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_reschedule_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_time_editor.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_week_calendar.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'support/talent_detail_fixture.dart';

Map<String, dynamic> appointment({
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
  'stageName': '技术面试',
  'stageId': 21,
  'stageOrder': 1,
  'startTime': start,
  'endTime': '2030-01-03 11:00:00',
  'status': status,
};

class RescheduleSource extends TalentFakeSource {
  RescheduleSource() {
    plan = [appointment()];
    interviewPages = [
      [appointment()],
    ];
  }
  bool unknownResponse = false, timeout = false, calendarFailure = false;
  Completer<void>? saveGate;
  @override
  Future<List<Map<String, dynamic>>> loadInterviews({
    required int pageNum,
    int pageSize = 50,
    String? from,
    String? to,
  }) async {
    if (calendarFailure) throw const ApiException('合成日历失败');
    return super.loadInterviews(
      pageNum: pageNum,
      pageSize: pageSize,
      from: from,
      to: to,
    );
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
    await saveGate?.future;
    if (timeout) throw const ApiException('网络超时');
    if (unknownResponse) return {};
    final start = TalentUtc8.parseServer(newStartTime)!;
    final row = {
      ...plan.first,
      'startTime': newStartTime,
      'endTime': TalentUtc8.serverTime(
        start.add(Duration(minutes: durationMin!)),
      ),
      'interviewerId': interviewerId,
      'status': 0,
    };
    plan = [row];
    interviewPages = [
      [row],
    ];
    return row;
  }
}

class ListSource extends JobDetailDataSource {
  ListSource(this.actions, this.rows);
  final RescheduleSource actions;
  final List<Map<String, dynamic>> rows;
  int reads = 0;
  @override
  RescheduleSource get candidateActionsSource => actions;
  @override
  Future<List<Map<String, dynamic>>> loadInterviews({
    required int pageNum,
    int pageSize = 50,
    String? from,
    String? to,
  }) async {
    reads++;
    return pageNum == 1 ? rows : [];
  }
}

final clock = DateTime.utc(2030, 1, 2, 2);
Future<void> mount(
  WidgetTester tester,
  RescheduleSource source, {
  Size size = const Size(430, 1000),
  double scale = 1,
  bool list = false,
  List<Map<String, dynamic>>? rows,
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
          alwaysUse24HourFormat: true,
        ),
        child: child!,
      ),
      home: list
          ? JobInterviewsPage(
              positionId: 7,
              positionTitle: '合成岗位',
              now: () => clock,
              source: ListSource(source, rows ?? [appointment()]),
            )
          : Scaffold(
              body: TalentInterviewRescheduleSheet(
                appointment: appointment(),
                source: source,
                now: () => clock,
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('reschedule-edit')));
  await tester.pumpAndSettle();
  final time = find.byKey(const Key('appointment-edit-time'));
  await tester.ensureVisible(time);
  await tester.tap(time);
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
}

Future<void> saveEditor(WidgetTester tester) async {
  final button = find.text('保存调整');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('已开始完成取消点击改期只显示自动关闭提示，未来面试打开日历', (tester) async {
    final source = RescheduleSource();
    await mount(tester, source, list: true, rows: [appointment(status: 3)]);
    await tester.tap(
      find.byKey(const ValueKey('job-interview-reschedule-101')),
    );
    await tester.pumpAndSettle();
    expect(find.text('仅未开始且未取消的面试可以改期'), findsOneWidget);
    expect(find.byType(TalentInterviewRescheduleSheet), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('job-reschedule-hint')), findsNothing);
    expect(source.reschedules, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, source, list: true);
    await tester.tap(
      find.byKey(const ValueKey('job-interview-reschedule-101')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewWeekCalendar), findsOneWidget);
    expect(find.text('面试改期'), findsOneWidget);
    expect(source.reschedules, isEmpty);
  });
  for (final item in [
    (0, '2030-01-02 10:00:00'),
    (1, '2030-01-01 10:00:00'),
    (2, '2030-01-03 10:00:00'),
  ]) {
    testWidgets('面试状态${item.$1}和时间${item.$2}不满足未开始限制时不打开改期', (tester) async {
      final source = RescheduleSource();
      await mount(
        tester,
        source,
        list: true,
        rows: [appointment(status: item.$1, start: item.$2)],
      );
      await tester.tap(
        find.byKey(const ValueKey('job-interview-reschedule-101')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TalentInterviewRescheduleSheet), findsNothing);
      expect(find.text('仅未开始且未取消的面试可以改期'), findsOneWidget);
      expect(source.reschedules, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('job-reschedule-hint')), findsNothing);
    });
  }

  testWidgets('周日历显示真实当日安排，调整确认前无写入，成功回读且不伪报通知已发', (tester) async {
    final source = RescheduleSource();
    await mount(tester, source);
    expect(find.byType(TalentInterviewWeekCalendar), findsOneWidget);
    expect(find.text('合成候选人 · 技术面试'), findsOneWidget);
    await choose(tester);
    await saveEditor(tester);
    expect(find.text('确认面试改期？'), findsOneWidget);
    expect(source.reschedules, isEmpty);
    await tester.tap(find.byKey(const Key('reschedule-confirm')));
    await tester.pumpAndSettle();
    expect(source.reschedules, hasLength(1));
    expect(source.reschedules.single['newStartTime'], '2030-01-03 12:30:00');
    expect(source.reschedules.single['durationMin'], 60);
    expect(source.availabilityQueries.length, 2);
    expect(source.interviewQueries.length, 2);
    expect(find.text('面试已改期'), findsOneWidget);
    expect(find.textContaining('通知已发送'), findsNothing);
  });
  testWidgets('候选人或面试官冲突阻止改期并保留编辑弹窗', (tester) async {
    final source = RescheduleSource()
      ..slots = [
        {
          'slotId': 72,
          'status': 0,
          'startTime': '2030-01-03 12:00:00',
          'endTime': '2030-01-03 14:00:00',
        },
      ];
    await mount(tester, source);
    await choose(tester);
    await saveEditor(tester);
    expect(find.text('时间冲突'), findsOneWidget);
    expect(find.textContaining('面试官在该时段已被占用'), findsWidgets);
    expect(find.byType(TalentInterviewTimeEditor), findsOneWidget);
    expect(source.reschedules, isEmpty);
  });
  testWidgets('忽略原预约自己的旧时段，另一个阶段时间限制保留', (tester) async {
    final source = RescheduleSource()
      ..slots = [
        {
          'slotId': 71,
          'status': 0,
          'startTime': '2030-01-03 12:00:00',
          'endTime': '2030-01-03 14:00:00',
        },
      ];
    await mount(tester, source);
    await choose(tester);
    await saveEditor(tester);
    expect(find.text('确认面试改期？'), findsOneWidget);
    expect(source.reschedules, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    source.plan.add({
      ...appointment(),
      'appointmentId': 102,
      'stageOrder': 2,
      'stageId': 22,
      'startTime': '2030-01-03 12:00:00',
      'endTime': '2030-01-03 12:15:00',
    });
    await choose(tester);
    await saveEditor(tester);
    expect(find.text('时间冲突'), findsOneWidget);
    expect(find.textContaining('各阶段须按招聘流程先后安排'), findsWidgets);
    expect(source.reschedules, isEmpty);
  });
  testWidgets('确认前原预约被改动则阻止写入，忙闲失败不等于空闲', (tester) async {
    final source = RescheduleSource()..availabilityFails = true;
    await mount(tester, source);
    await choose(tester);
    await saveEditor(tester);
    expect(source.reschedules, isEmpty);
    expect(find.byType(TalentInterviewTimeEditor), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-stage-close')));
    await tester.pumpAndSettle();
    source.availabilityFails = false;
    await choose(tester);
    await saveEditor(tester);
    source.plan[0] = {...source.plan[0], 'status': 3};
    await tester.tap(find.byKey(const Key('reschedule-confirm')));
    await tester.pumpAndSettle();
    expect(source.reschedules, isEmpty);
    expect(find.text('预约已变更或已开始，请关闭后刷新列表'), findsOneWidget);
  });
  testWidgets('结果未知时禁止重发并允许关闭核对，保存中禁止重复和关闭', (tester) async {
    final source = RescheduleSource()..unknownResponse = true;
    await mount(tester, source);
    await choose(tester);
    await saveEditor(tester);
    source.saveGate = Completer<void>();
    await tester.tap(find.byKey(const Key('reschedule-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(source.reschedules, hasLength(1));
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('reschedule-close')))
          .onPressed,
      isNull,
    );
    source.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('改期已响应但结果不完整'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('reschedule-edit')))
          .onPressed,
      isNull,
    );
    expect(source.reschedules, hasLength(1));
  });
  testWidgets('提交超时不自动重发并阻止再次保存', (tester) async {
    final source = RescheduleSource()..timeout = true;
    await mount(tester, source);
    await choose(tester);
    await saveEditor(tester);
    await tester.tap(find.byKey(const Key('reschedule-confirm')));
    await tester.pumpAndSettle();
    expect(source.reschedules, hasLength(1));
    expect(find.text('改期结果尚未确认，请返回列表核对，避免重复提交'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('reschedule-edit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('日历读取失败禁止编辑可重试', (tester) async {
    final source = RescheduleSource()..calendarFailure = true;
    await mount(tester, source);
    expect(find.text('合成日历失败'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('reschedule-edit')))
          .onPressed,
      isNull,
    );
    source.calendarFailure = false;
    await tester.tap(find.byTooltip('刷新日历'));
    await tester.pumpAndSettle();
    expect(find.text('合成日历失败'), findsNothing);
  });
  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('改期日历在$size下无溢出', (tester) async {
      await mount(tester, RescheduleSource(), size: size);
      expect(find.byType(TalentInterviewWeekCalendar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
