import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_interview_preview.dart';
import 'package:enterprise_recruiter/features/enterprise/schedule/interview_appointment_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'enterprise_home_page_test.dart' show mount, inHome;
import 'support/home_fixture.dart';

class CalendarFixture extends HomeFixture {
  DateTime? clock;
  @override
  DateTime get now => clock ?? super.now;
  Future<List<HomeInterview>> Function(DateTime)? loader;

  @override
  Future<List<HomeInterview>> loadInterviewsOn(DateTime day) {
    if (loader == null) return super.loadInterviewsOn(day);
    calendarCalls++;
    calendarDates.add(day);
    return loader!(day);
  }
}

Future<void> tapCalendar(WidgetTester tester, String key) async {
  final target = inHome(find.byKey(ValueKey(key)));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

void main() {
  testWidgets('默认选中今天，点日期查询当天，今天按钮恢复当前日期', (tester) async {
    final source = HomeFixture();
    await mount(tester, source);
    expect(source.calendarDates.single, DateTime(2030, 1, 2));
    expect(find.text('2030-01-02'), findsOneWidget);
    expect(find.text('4 场面试'), findsOneWidget);
    await tapCalendar(tester, 'home-calendar-day-2030-01-03');
    expect(source.calendarDates.last, DateTime(2030, 1, 3));
    expect(find.text('2030-01-03'), findsOneWidget);
    expect(find.text('4 场面试'), findsOneWidget);
    final row = tester.widget<HomeInterviewPreview>(
      inHome(find.byType(HomeInterviewPreview)).first,
    );
    expect(row.interview.timeLabel, '01-03 10:00');
    await tapCalendar(tester, 'home-calendar-today');
    expect(source.calendarDates.last, DateTime(2030, 1, 2));
    expect(find.text('2030-01-02'), findsOneWidget);
    expect(find.text('4 场面试'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('周切换、月历展开与跨月日期选择都查询所选日期', (tester) async {
    final source = HomeFixture();
    await mount(tester, source);
    await tapCalendar(tester, 'home-calendar-next');
    expect(source.calendarDates.last, DateTime(2030, 1, 9));
    await tapCalendar(tester, 'home-calendar-previous');
    expect(source.calendarDates.last, DateTime(2030, 1, 2));
    await tapCalendar(tester, 'home-calendar-expand');
    expect(find.byTooltip('收起月历'), findsOneWidget);
    await tapCalendar(tester, 'home-calendar-day-2030-01-31');
    await tapCalendar(tester, 'home-calendar-next');
    expect(source.calendarDates.last, DateTime(2030, 2, 28));
    await tapCalendar(tester, 'home-calendar-day-2030-02-14');
    expect(find.text('2030-02-14'), findsOneWidget);
    expect(find.text('4 场面试'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('快速切日期时旧响应不覆盖当前日期，错误可重试且不伪造零场', (tester) async {
    final source = CalendarFixture();
    await mount(tester, source);
    final oldRequest = Completer<List<HomeInterview>>();
    source.loader = (day) async {
      if (day.day == 3) return oldRequest.future;
      throw const ApiException('连接超时，请稍后重试');
    };
    await tapCalendar(tester, 'home-calendar-day-2030-01-03');
    await tapCalendar(tester, 'home-calendar-day-2030-01-04');
    expect(find.text('连接超时，请检查网络后重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-calendar-count')), findsNothing);
    oldRequest.complete([]);
    await tester.pump();
    expect(find.text('连接超时，请检查网络后重试'), findsOneWidget);
    expect(find.text('当日无面试，可切换日期查看安排'), findsNothing);
    source.loader = (_) async => [];
    final retry = inHome(find.text('重试'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(source.calendarDates.last, DateTime(2030, 1, 4));
    expect(find.text('2030-01-04'), findsOneWidget);
    expect(find.text('0 场面试'), findsOneWidget);
    expect(find.text('当日无面试，可切换日期查看安排'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('刷新保留日期，未来面试禁用，开始后直接使用预留会议回调', (tester) async {
    final source = CalendarFixture();
    Map<String, dynamic>? started;
    await mount(
      tester,
      source,
      onStartInterview: (interview) async {
        started = interview.raw;
      },
    );
    await tapCalendar(tester, 'home-calendar-day-2030-01-03');
    final beforeRefresh = source.calendarCalls;
    await tapCalendar(tester, 'home-calendar-refresh');
    expect(source.calendarCalls, beforeRefresh + 1);
    expect(source.calendarDates.last, DateTime(2030, 1, 3));
    final row = tester.widget<HomeInterviewPreview>(
      inHome(find.byType(HomeInterviewPreview)).first,
    );
    final start = inHome(
      find.byKey(ValueKey('home-interview-${row.interview.id}')),
    );
    expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
    source.clock = DateTime.utc(2030, 1, 3, 2);
    await tapCalendar(tester, 'home-calendar-refresh');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(start).onPressed, isNotNull);
    final beforeStart = source.calendarCalls;
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(started, row.interview.raw);
    expect(find.byType(InterviewAppointmentDetailPage), findsNothing);
    expect(source.calendarCalls, beforeStart + 1);
    expect(source.calendarDates.last, DateTime(2030, 1, 3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('未接会议时信息不完整只提示原因，不打开详情或演示工作台', (tester) async {
    final source = CalendarFixture()..clock = DateTime.utc(2030, 1, 2, 2);
    await mount(tester, source);
    final row = tester.widget<HomeInterviewPreview>(
      inHome(find.byType(HomeInterviewPreview)).first,
    );
    final start = inHome(
      find.byKey(ValueKey('home-interview-${row.interview.id}')),
    );
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('面试信息不完整，无法发起面试邀请'), findsOneWidget);
    expect(find.byType(InterviewAppointmentDetailPage), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(HomeInterviewPreview).first))
          .canPop(),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final sample in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(900, 420), 1.0),
  ]) {
    testWidgets('月历在 ${sample.$1}、字号倍率 ${sample.$2} 不溢出', (tester) async {
      await mount(tester, HomeFixture(), size: sample.$1, textScale: sample.$2);
      await tapCalendar(tester, 'home-calendar-expand');
      final endOfMonth = inHome(
        find.byKey(const ValueKey('home-calendar-day-2030-01-31')),
      );
      await tester.ensureVisible(endOfMonth);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(endOfMonth);
      await tester.pump();
      expect(find.text('2030-01-31'), findsOneWidget);
      expect(find.text('4 场面试'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
