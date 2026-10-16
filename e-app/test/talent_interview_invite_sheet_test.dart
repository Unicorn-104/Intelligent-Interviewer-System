import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/talent_detail_fixture.dart';

Future<void> openInvite(
  WidgetTester tester,
  TalentFakeSource source, {
  bool withJob = true,
}) async {
  await pumpTalentWidget(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (context) => FractionallySizedBox(
            heightFactor: 0.9,
            child: TalentInterviewInviteSheet(
              candidateId: 11,
              candidateName: '合成候选人',
              source: source,
              job: withJob ? talentTestJob : null,
              clock: () => DateTime.utc(2026, 12, 31, 16),
            ),
          ),
        ),
        child: const Text('打开邀约'),
      ),
    ),
  );
  await tester.tap(find.text('打开邀约'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('取消二次确认不发任何新请求，保留选择并可重新确认', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    final queries = source.availabilityQueries.length;
    final peopleCalls = source.peopleCalls;
    final detailCalls = source.detailCalls;
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(source.availabilityQueries.length, queries);
    expect(source.invites, isEmpty);
    await tester.tap(find.byKey(const Key('invite-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TalentInterviewInviteSheet), findsOneWidget);
    expect(find.text('2027-01-02'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(source.availabilityQueries.length, queries);
    expect(source.peopleCalls, peopleCalls);
    expect(source.detailCalls, detailCalls);
    expect(source.invites, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('invite-submit')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(find.text('确认发送面试邀约？'), findsOneWidget);
    expect(source.availabilityQueries.length, queries);
    await tester.tap(find.byKey(const Key('invite-confirm-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('空面试人员列表显示空态，不伪造选项，禁止提交', (tester) async {
    final source = TalentFakeSource()..people = [];
    await openInvite(tester, source);
    expect(find.text('暂无可用面试官'), findsOneWidget);
    expect(find.byKey(const Key('invite-interviewer')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('invite-submit')))
          .onPressed,
      isNull,
    );
    expect(source.invites, isEmpty);
  });
  testWidgets('人才库进入须选择真实岗位，人员失败显示可重试错误', (tester) async {
    final source = TalentFakeSource()..peopleFail = true;
    await openInvite(tester, source, withJob: false);
    expect(find.byKey(const Key('invite-job')), findsOneWidget);
    expect(find.text('重试加载面试官'), findsOneWidget);
    source.peopleFail = false;
    await tester.tap(find.text('重试加载面试官'));
    await tester.pumpAndSettle();
    expect(source.peopleCalls, 2);
    await tester.tap(find.byKey(const Key('invite-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合成测试岗位').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-interviewer')), findsOneWidget);
  });
  testWidgets('忙闲失败不得视为空闲，重试后冲突时仍禁止提交', (tester) async {
    final source = TalentFakeSource()..availabilityFails = true;
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    expect(find.text('重试查询忙闲'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('invite-submit')))
          .onPressed,
      isNull,
    );
    expect(source.invites, isEmpty);
    source.availabilityFails = false;
    source.slots = [
      {
        'status': 0,
        'startTime': '2027-01-02 09:00:00',
        'endTime': '2027-01-02 10:30:00',
      },
    ];
    await tester.tap(find.text('重试查询忙闲'));
    await tester.pumpAndSettle();
    expect(find.text('所选时段面试官已被占用'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('invite-submit')))
          .onPressed,
      isNull,
    );
  });
  testWidgets('显式邀请前再次复核，重复点击只提交一次，时间为无偏移 UTC+8', (tester) async {
    final source = TalentFakeSource()
      ..invitePending = Completer<Map<String, dynamic>>();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    expect(find.text('当前查询未发现占用，提交时将再次核验'), findsOneWidget);
    final submit = find.byKey(const Key('invite-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('确认发送面试邀约？'), findsOneWidget);
    expect(
      find.text(
        '候选人：合成候选人\n岗位：合成测试岗位\n面试官：合成面试官\n时间：2027-01-02 09:30（UTC+8）\n时长：45 分钟',
      ),
      findsOneWidget,
    );
    expect(source.availabilityQueries.length, 1);
    expect(source.invites, isEmpty);
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(source.availabilityQueries.length, 2);
    expect(source.invites.length, 1);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(submit);
    await tester.pump();
    expect(source.invites.length, 1);
    expect(source.invites.single, {
      'candidateId': 11,
      'positionId': 7,
      'interviewerId': 19,
      'startTime': '2027-01-02 09:30:00',
      'durationMin': 45,
    });
    expect(source.availabilityQueries.last['to'], '2027-01-02 10:15:00');
    source.invitePending!.complete({'appointmentId': 101});
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });
  testWidgets('预检查后出现新占用不发邀约，缺少预约编号成功响应禁止重复提交', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    source.slots = [
      {
        'status': 0,
        'startTime': '2027-01-02 09:00:00',
        'endTime': '2027-01-02 10:30:00',
      },
    ];
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(source.invites, isEmpty);
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.invites, isEmpty);
    expect(find.text('所选时段面试官已被占用，请调整时间'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    source.slots = [];
    source.inviteResult = {};
    await tester.tap(find.text('打开邀约'));
    await tester.pumpAndSettle();
    await fillTalentInvite(tester);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(source.invites, isEmpty);
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.invites.length, 1);
    expect(find.textContaining('未返回预约编号'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('invite-submit')))
          .onPressed,
      isNull,
    );
  });
}
