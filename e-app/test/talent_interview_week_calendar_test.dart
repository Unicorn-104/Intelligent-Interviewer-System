import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_week_calendar.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> event(
  int id, {
  int day = 4,
  int hour = 9,
  int duration = 60,
}) => {
  'appointmentId': id,
  'candidateId': 11,
  'positionId': 7,
  'interviewerId': 19,
  'candidateName': '合成候选人$id',
  'positionTitle': '合成岗位',
  'stageName': '技术面试',
  'status': 0,
  'startTime': TalentUtc8.serverTime(
    TalentUtc8.fromSelection(DateTime(2027, 1, day), hour, 0),
  ),
  'endTime': TalentUtc8.serverTime(
    TalentUtc8.fromSelection(
      DateTime(2027, 1, day),
      hour,
      0,
    ).add(Duration(minutes: duration)),
  ),
};
Future<void> mountCalendar(
  WidgetTester tester, {
  required List<Map<String, dynamic>> rows,
  void Function(Map<String, dynamic>, DateTime, int)? onMove,
  ValueChanged<Map<String, dynamic>>? onOpen,
  bool editable = true,
  bool Function(Map<String, dynamic>)? canEdit,
  String? error,
  double width = 430,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TalentInterviewWeekCalendar(
            weekStart: DateTime(2027, 1, 4),
            today: DateTime(2027, 1, 4),
            appointments: rows,
            loading: false,
            error: error,
            onPrevious: () {},
            onNext: () {},
            onToday: () {},
            onRefresh: () {},
            onChooseDay: (_) {},
            onChooseTime: (_, _, _) {},
            canEdit: canEdit ?? (_) => editable,
            onOpen: onOpen ?? (_) {},
            onMove: onMove ?? (_, _, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('上边界拖动实时改变开始时间与高度，保持结束时间不变', (tester) async {
    final changes = <(DateTime, int)>[];
    await mountCalendar(
      tester,
      rows: [event(1)],
      onMove: (_, start, duration) => changes.add((start, duration)),
    );
    final surface = find.byKey(const ValueKey('interview-event-surface-1'));
    final original = tester.getRect(surface);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('interview-resize-start-1'))),
    );
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    final preview = tester.getRect(surface);
    expect(preview.top, closeTo(original.top + 24, .1));
    expect(preview.bottom, closeTo(original.bottom, .1));
    expect(find.textContaining('09:15—10:00'), findsOneWidget);
    expect(changes, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, [(TalentUtc8.parseServer('2027-01-04 09:15')!, 45)]);
    expect(tester.getRect(surface), original);
    await tester.drag(
      find.byKey(const ValueKey('interview-resize-start-1')),
      const Offset(0, -24),
      touchSlopY: 0,
    );
    await tester.pumpAndSettle();
    expect(changes.last, (TalentUtc8.parseServer('2027-01-04 08:45')!, 75));
  });

  testWidgets('下边界拖动实时改变结束时间与高度，保持开始时间不变', (tester) async {
    final changes = <(DateTime, int)>[];
    await mountCalendar(
      tester,
      rows: [event(1)],
      onMove: (_, start, duration) => changes.add((start, duration)),
    );
    final surface = find.byKey(const ValueKey('interview-event-surface-1'));
    final original = tester.getRect(surface);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('interview-resize-1'))),
    );
    await gesture.moveBy(const Offset(0, 48));
    await tester.pump();
    final preview = tester.getRect(surface);
    expect(preview.top, closeTo(original.top, .1));
    expect(preview.bottom, closeTo(original.bottom + 48, .1));
    expect(find.textContaining('09:00—10:30'), findsOneWidget);
    expect(changes, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, [(TalentUtc8.parseServer('2027-01-04 09:00')!, 90)]);
    await tester.drag(
      find.byKey(const ValueKey('interview-resize-1')),
      const Offset(0, -24),
      touchSlopY: 0,
    );
    await tester.pumpAndSettle();
    expect(changes.last, (TalentUtc8.parseServer('2027-01-04 09:00')!, 45));
  });

  testWidgets('取消拖动还原预览不保存，边界不能倒置或超过1440分钟', (tester) async {
    final changes = <(DateTime, int)>[];
    await mountCalendar(
      tester,
      rows: [event(1)],
      onMove: (_, start, duration) => changes.add((start, duration)),
    );
    final surface = find.byKey(const ValueKey('interview-event-surface-1'));
    final original = tester.getRect(surface);
    final handle = find.byKey(const ValueKey('interview-resize-start-1'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(tester.getRect(surface), original);
    await tester.drag(handle, const Offset(0, 144), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(changes.last, (TalentUtc8.parseServer('2027-01-04 09:59')!, 1));
    await tester.drag(handle, const Offset(0, -2400), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(changes.last.$2, 1440);
    expect(
      changes.last.$1.add(Duration(minutes: changes.last.$2)),
      TalentUtc8.parseServer('2027-01-04 10:00'),
    );
  });

  testWidgets('已开始的面试无上下手柄，拖动中到开始时间也不会保存', (tester) async {
    var editable = true;
    final changes = <int>[];
    await mountCalendar(
      tester,
      rows: [event(1)],
      canEdit: (_) => editable,
      onMove: (_, _, duration) => changes.add(duration),
    );
    final surface = find.byKey(const ValueKey('interview-event-surface-1'));
    final original = tester.getRect(surface);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('interview-resize-start-1'))),
    );
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    editable = false;
    await gesture.moveBy(const Offset(0, 24));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(tester.getRect(surface), original);
    expect(
      find.byKey(const ValueKey('interview-resize-start-1')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('interview-resize-1')), findsNothing);
    await mountCalendar(
      tester,
      rows: [event(2)..['status'] = 1],
      editable: false,
    );
    expect(
      find.byKey(const ValueKey('interview-resize-start-2')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('interview-resize-2')), findsNothing);
  });

  testWidgets('跨日面试只在真实起止边界显示手柄', (tester) async {
    await mountCalendar(tester, rows: [event(1, hour: 23, duration: 120)]);
    expect(
      find.byKey(const ValueKey('interview-resize-start-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('interview-resize-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('interview-calendar-day-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('interview-resize-start-1')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('interview-resize-1')), findsOneWidget);
  });

  testWidgets('数量按5/10边界分绿黄红，320dp无溢出', (tester) async {
    final rows = <Map<String, dynamic>>[];
    var id = 0;
    for (final (index, count) in [0, 5, 6, 10, 11, 1, 0].indexed) {
      for (var j = 0; j < count; j++) {
        rows.add(event(++id, day: 4 + index));
      }
    }
    await mountCalendar(tester, rows: rows, width: 320);
    for (final (index, color) in [
      AppColors.success,
      AppColors.success,
      AppColors.warning,
      AppColors.warning,
      AppColors.error,
      AppColors.success,
      AppColors.success,
    ].indexed) {
      final count = tester.widget<Text>(
        find.byKey(ValueKey('interview-calendar-count-$index')),
      );
      expect(count.data, '${[0, 5, 6, 10, 11, 1, 0][index]}');
      expect(count.style!.color, color);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('选择日期只展示当天，时长增长对应高度增长', (tester) async {
    await mountCalendar(
      tester,
      rows: [event(1), event(2, hour: 11, duration: 120), event(3, day: 5)],
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('interview-event-2'))).height,
      tester.getSize(find.byKey(const ValueKey('interview-event-1'))).height *
          2,
    );
    expect(find.byKey(const ValueKey('interview-event-3')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('interview-calendar-day-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('interview-event-1')), findsNothing);
    expect(find.byKey(const ValueKey('interview-event-3')), findsOneWidget);
  });
  testWidgets('点击查看、长按按15分钟移动、底边拖动调整时长', (tester) async {
    Map<String, dynamic>? opened;
    final moves = <(DateTime, int)>[];
    await mountCalendar(
      tester,
      rows: [event(1)],
      onOpen: (value) => opened = value,
      onMove: (_, start, duration) => moves.add((start, duration)),
    );
    final block = find.byKey(const ValueKey('interview-event-1'));
    await tester.tap(block);
    expect(opened?['appointmentId'], 1);
    final gesture = await tester.startGesture(tester.getCenter(block));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves.single.$1, TalentUtc8.parseServer('2027-01-04 09:15'));
    expect(moves.single.$2, 60);
    await tester.drag(
      find.byKey(const ValueKey('interview-resize-1')),
      const Offset(0, 48),
      touchSlopY: 0,
    );
    await tester.pumpAndSettle();
    expect(moves.last.$1, TalentUtc8.parseServer('2027-01-04 09:00'));
    expect(moves.last.$2, 90);
  });
  testWidgets('已完成只可查看，查询失败不显示虚假零场', (tester) async {
    final moves = <int>[];
    await mountCalendar(
      tester,
      rows: [event(1)..['status'] = 3],
      editable: false,
      onMove: (_, _, duration) => moves.add(duration),
    );
    expect(find.byKey(const ValueKey('interview-resize-1')), findsNothing);
    await tester.longPress(find.byKey(const ValueKey('interview-event-1')));
    expect(moves, isEmpty);
    await mountCalendar(tester, rows: [], error: '加载失败');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('interview-calendar-count-0')),
          )
          .data,
      '—',
    );
    expect(find.text('加载失败'), findsOneWidget);
  });
}
