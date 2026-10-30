import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_invite_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/talent_detail_fixture.dart';

/// 时钟固定为 2027-01-01 00:00（UTC+8，周四）；初始周为 2026-12-28 起。
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
    use24HourFormat: true,
  );
  await tester.tap(find.text('打开邀约'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> interview({
  int appointmentId = 501,
  String start = '2027-01-01 09:00:00',
  String end = '2027-01-01 10:00:00',
  int status = 0,
}) => {
  'appointmentId': appointmentId,
  'candidateName': '其他候选人',
  'stageName': '技术面试',
  'positionTitle': '其他岗位',
  'status': status,
  'startTime': start,
  'endTime': end,
};

void main() {
  testWidgets('单页整合：阶段列表、日历、时间轴与面试时间设置同屏展示', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    expect(find.text('邀请面试'), findsOneWidget);
    expect(find.byKey(const Key('invite-step-indicator')), findsOneWidget);
    expect(find.text('① 设置面试时间'), findsOneWidget);
    expect(find.text('② 确认邀请'), findsOneWidget);
    expect(find.byKey(const Key('invite-candidate-card')), findsOneWidget);
    expect(find.text('求职者：合成候选人'), findsOneWidget);
    expect(find.textContaining('应聘岗位：合成测试岗位'), findsOneWidget);
    expect(find.byKey(const Key('invite-match-score')), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    expect(find.byKey(const Key('invite-stage-0')), findsOneWidget);
    expect(find.text('招聘流程阶段（1）'), findsOneWidget);
    expect(find.textContaining('在线笔试 · 45分钟'), findsOneWidget);
    expect(find.text('待安排面试时间'), findsOneWidget);
    expect(find.byKey(const Key('invite-week-strip')), findsOneWidget);
    expect(find.text('查看排期，避免冲突'), findsOneWidget);
    expect(find.byKey(const Key('invite-timeline')), findsOneWidget);
    expect(find.byKey(const Key('invite-time-editor')), findsOneWidget);
    expect(find.text('面试时间设置'), findsOneWidget);
    expect(find.text('45分钟 · 来自岗位招聘流程配置'), findsOneWidget);
    expect(find.text('待选择开始时间'), findsOneWidget);
    // 时长不允许在弹窗中修改。
    expect(find.byKey(const Key('invite-duration-increment')), findsNothing);
    expect(find.byKey(const Key('invite-duration-decrement')), findsNothing);
    // 未设置时间前不允许进入下一步。
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNull,
    );
    expect(source.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('40分钟阶段17:30开始自动计算18:10结束，时长来自流程配置', (tester) async {
    final source = TalentFakeSource()
      ..workflow = {
        'template': {'name': '合成流程'},
        'stages': [
          {
            'stageId': 31,
            'name': '在线笔试',
            'type': 1,
            'configJson': '{"duration":40}',
          },
        ],
      };
    await openInvite(tester, source);
    expect(find.text('40分钟 · 来自岗位招聘流程配置'), findsOneWidget);
    await fillTalentInvite(tester, hour: 17, minute: 30);
    expect(find.text('2027-01-01'), findsOneWidget);
    expect(find.text('17:30'), findsOneWidget);
    expect(find.text('2027-01-01 18:10'), findsOneWidget);
    expect(find.byKey(const Key('invite-cross-day')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('跨天排期23:40开始次日00:20结束，次日日历可见延续', (tester) async {
    final source = TalentFakeSource()
      ..workflow = {
        'template': {'name': '合成流程'},
        'stages': [
          {
            'stageId': 31,
            'name': '在线笔试',
            'type': 1,
            'configJson': '{"duration":40}',
          },
        ],
      };
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 9, minute: 0);
    await pickInviteTimeField(tester, 23, 40);
    expect(find.text('23:40'), findsOneWidget);
    expect(find.text('2027-01-02 00:20'), findsOneWidget);
    expect(find.byKey(const Key('invite-cross-day')), findsOneWidget);
    expect(find.text('跨天面试'), findsOneWidget);
    // 次日日历：当天列表显示延续部分，时间轴显示跨日延续块。
    final day2 = find.byKey(const Key('invite-week-day-5'));
    await tester.ensureVisible(day2);
    await tester.tap(day2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-draft-row')), findsOneWidget);
    expect(find.textContaining('23:40–00:20'), findsOneWidget);
    expect(find.textContaining('延续自前一日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击时间轴自动同步手动时间设置区（同一份状态）', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 9, minute: 30);
    expect(find.text('2027-01-01'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('2027-01-01 10:15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动修改日期同步日历选中日与周范围', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 9, minute: 30);
    await pickInviteDateField(tester, '15');
    expect(find.text('2027-01-15'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.textContaining('1月11日 – 1月17日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('前一天开始的跨天面试在次日日历中可见', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [
          interview(
            start: '2026-12-29 23:40:00',
            end: '2026-12-30 00:20:00',
          ),
        ],
      ];
    await openInvite(tester, source);
    // 2026-12-29（周内第2天）显示 1 场。
    expect(
      find.descendant(
        of: find.byKey(const Key('invite-week-day-1')),
        matching: find.text('1场'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('invite-week-day-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12月30日 · 1场面试'), findsOneWidget);
    // 当天列表与时间轴事件块各展示一次。
    expect(find.textContaining('23:40–00:20'), findsWidgets);
    expect(find.textContaining('其他候选人'), findsOneWidget);
  });

  testWidgets('已有面试冲突时提示并禁止提交，改选无冲突时段后恢复', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [interview()],
      ];
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 8, minute: 30);
    expect(find.byKey(const Key('invite-conflict')), findsOneWidget);
    expect(find.text('该时间段已有面试安排，请选择其他时间'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNull,
    );
    // 改选 11:00 后恢复。
    await fillTalentInvite(tester, hour: 11, minute: 0);
    expect(find.byKey(const Key('invite-conflict')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNotNull,
    );
    expect(source.invites, isEmpty);
  });

  testWidgets('跨天冲突检测覆盖完整时间区间', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [
          interview(
            start: '2027-01-02 00:00:00',
            end: '2027-01-02 00:30:00',
          ),
        ],
      ]
      ..workflow = {
        'template': {'name': '合成流程'},
        'stages': [
          {
            'stageId': 31,
            'name': '在线笔试',
            'type': 1,
            'configJson': '{"duration":40}',
          },
        ],
      };
    await openInvite(tester, source);
    await pickInviteTimeField(tester, 23, 40);
    expect(find.byKey(const Key('invite-conflict')), findsOneWidget);
    expect(find.text('该时间段已有面试安排，请选择其他时间'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNull,
    );
  });

  testWidgets('阶段切换保留各自临时排期，时长各自独立', (tester) async {
    final source = TalentFakeSource()
      ..workflow = {
        'template': {'name': '多阶段流程'},
        'stages': [
          {
            'stageId': 31,
            'name': '在线笔试',
            'type': 1,
            'required': 1,
            'configJson': '{"duration":30}',
          },
          {
            'stageId': 32,
            'name': 'HR 综合面试',
            'type': 3,
            'configJson': '{"duration":45}',
          },
        ],
      };
    await openInvite(tester, source);
    expect(find.text('招聘流程阶段（2）'), findsOneWidget);
    expect(find.text('必选'), findsOneWidget);
    await fillTalentInvite(tester, hour: 9, minute: 30);
    // 切换第二阶段：默认时长45分钟、时间未设置。
    final stage1 = find.byKey(const Key('invite-stage-1'));
    await tester.ensureVisible(stage1);
    await tester.tap(stage1);
    await tester.pumpAndSettle();
    expect(find.text('45分钟 · 来自岗位招聘流程配置'), findsOneWidget);
    expect(find.text('请选择时间'), findsOneWidget);
    await fillTalentInvite(tester, hour: 11, minute: 0);
    // 回到第一阶段：09:30 仍在。
    final stage0 = find.byKey(const Key('invite-stage-0'));
    await tester.ensureVisible(stage0);
    await tester.tap(stage0);
    await tester.pumpAndSettle();
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('30分钟 · 来自岗位招聘流程配置'), findsOneWidget);
    // 再回第二阶段：11:00 仍在（时间轴小时刻度也有「11:00」，限定在时间设置卡片内断言）。
    final stage1Again = find.byKey(const Key('invite-stage-1'));
    await tester.ensureVisible(stage1Again);
    await tester.tap(stage1Again);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('invite-time-field')),
        matching: find.text('11:00'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('480分钟等超过240分钟的阶段时长不被截断', (tester) async {
    final source = TalentFakeSource()
      ..workflow = {
        'template': {'name': '合成流程'},
        'stages': [
          {
            'stageId': 31,
            'name': '编程实操',
            'type': 4,
            'configJson': '{"duration":480}',
          },
        ],
      };
    await openInvite(tester, source);
    expect(find.text('480分钟 · 来自岗位招聘流程配置'), findsOneWidget);
    await fillTalentInvite(tester, hour: 9, minute: 0);
    expect(find.text('2027-01-01 17:00'), findsOneWidget);
    expect(find.byKey(const Key('invite-cross-day')), findsNothing);
    expect(find.byKey(const Key('invite-duration-increment')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('阶段时长缺失时提示完善招聘流程并禁止提交', (tester) async {
    final source = TalentFakeSource()
      ..workflow = {
        'template': {'name': '合成流程'},
        'stages': [
          {'stageId': 31, 'name': '在线笔试', 'type': 1},
        ],
      };
    await openInvite(tester, source);
    expect(find.text('未配置时长'), findsWidgets);
    expect(find.byKey(const Key('invite-duration-missing')), findsOneWidget);
    expect(find.text('该阶段未配置面试时长，请先在岗位详情完善招聘流程'), findsOneWidget);
    await fillTalentInvite(tester, hour: 9, minute: 30);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNull,
    );
    expect(source.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('下一步进入确认页展示面试方式与起止时间，确认后发送阶段批量邀约', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    final queries = source.availabilityQueries.length;
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-confirm-candidate')), findsOneWidget);
    expect(find.text('面试安排汇总'), findsOneWidget);
    expect(find.byKey(const Key('invite-confirm-stage-0')), findsOneWidget);
    expect(find.textContaining('面试方式：在线笔试'), findsOneWidget);
    expect(find.textContaining('2027-01-01 09:30'), findsOneWidget);
    expect(find.textContaining('2027-01-01 10:15'), findsOneWidget);
    expect(find.textContaining('时长 45 分钟'), findsOneWidget);
    expect(find.text('待发送'), findsOneWidget);
    expect(source.stageInvites, isEmpty);
    expect(source.availabilityQueries.length, greaterThan(queries));
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.stageInvites, hasLength(1));
    expect(source.stageInvites.single.map((row) => row['stageId']), [31]);
    expect(source.stageInvites.single.first['startTime'], '2027-01-01 09:30:00');
    expect(source.stageInvites.single.first['durationMin'], 45);
    expect(source.invites, isEmpty);
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  testWidgets('确认页展示跨天标识，各阶段顺序校验不通过时阻止发送', (tester) async {
    final source = TalentFakeSource()
      ..workflow = {
        'template': {'name': '多阶段流程'},
        'stages': [
          {
            'stageId': 31,
            'name': '在线笔试',
            'type': 1,
            'configJson': '{"duration":30}',
          },
          {
            'stageId': 32,
            'name': 'HR 综合面试',
            'type': 3,
            'configJson': '{"duration":40}',
          },
        ],
      };
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 9, minute: 30);
    final stage1 = find.byKey(const Key('invite-stage-1'));
    await tester.ensureVisible(stage1);
    await tester.tap(stage1);
    await tester.pumpAndSettle();
    await fillTalentInvite(tester, hour: 9, minute: 45);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-confirm-error')), findsOneWidget);
    expect(
      find.textContaining('后一阶段不能早于前一阶段结束时间'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-confirm-send'))).onPressed,
      isNull,
    );
    // 调整第二阶段时间后再确认发送。
    await tester.tap(find.byKey(const Key('invite-confirm-cancel')));
    await tester.pumpAndSettle();
    final stage1Again = find.byKey(const Key('invite-stage-1'));
    await tester.ensureVisible(stage1Again);
    await tester.tap(stage1Again);
    await tester.pumpAndSettle();
    await fillTalentInvite(tester, hour: 11, minute: 0);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.stageInvites, hasLength(1));
    expect(source.stageInvites.single.map((row) => row['stageId']), [31, 32]);
    expect(source.stageInvites.single.last['startTime'], '2027-01-01 11:00:00');
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  testWidgets('已安排阶段可保存调整走改期接口，只读安排仅可查看', (tester) async {
    final source = TalentFakeSource()
      ..plan = [
        {
          'appointmentId': 901,
          'stageId': 31,
          'candidateId': 11,
          'positionId': 7,
          'interviewerId': 19,
          'interviewerName': '合成面试官',
          'status': 0,
          'startTime': '2027-01-02 09:00:00',
          'endTime': '2027-01-02 09:45:00',
        },
      ]
      ..workflow = {
        'template': {'name': '单阶段流程'},
        'stages': [
          {
            'stageId': 31,
            'name': '在线笔试',
            'type': 1,
            'configJson': '{"duration":30}',
          },
        ],
      };
    await openInvite(tester, source);
    expect(find.text('已安排'), findsOneWidget);
    expect(find.textContaining('2027-01-02 09:00'), findsOneWidget);
    // 改期到 11:00 并保存调整（时长保持原预约，不随改期调整）。
    await fillTalentInvite(tester, hour: 11, minute: 0, selectInterviewer: false);
    expect(find.byKey(const Key('invite-stage-save')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-stage-save')));
    await tester.pumpAndSettle();
    expect(source.reschedules, hasLength(1));
    expect(source.reschedules.single['newStartTime'], '2027-01-02 11:00:00');
    expect(source.reschedules.single['durationMin'], isNull);
    expect(find.text('面试安排已更新'), findsOneWidget);
    // 只读安排：状态 3 已完成。
    source.plan = [
      {
        'appointmentId': 902,
        'stageId': 31,
        'candidateId': 11,
        'positionId': 7,
        'interviewerId': 19,
        'interviewerName': '合成面试官',
        'status': 3,
        'startTime': '2027-01-01 09:00:00',
        'endTime': '2027-01-01 09:45:00',
      },
    ];
    await tester.tap(find.byKey(const Key('invite-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开邀约'));
    await tester.pumpAndSettle();
    expect(find.textContaining('仅可查看'), findsOneWidget);
    expect(find.byKey(const Key('invite-stage-save')), findsNothing);
  });

  testWidgets('提交中防重复点击，成功后关闭弹窗', (tester) async {
    final source = TalentFakeSource()
      ..stageInvitePending = Completer<List<Map<String, dynamic>>>();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(source.stageInvites, hasLength(1));
    final send = find.byKey(const Key('invite-confirm-send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(send);
    await tester.pump();
    expect(source.stageInvites, hasLength(1));
    source.stageInvitePending!.complete([
      {
        'stageId': 31,
        'appointmentId': 101,
        'status': 0,
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  testWidgets('确认页提交时发现新占用则留在确认页提示，不发送', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    source.slots = [
      {
        'status': 0,
        'startTime': '2027-01-01 09:00:00',
        'endTime': '2027-01-01 10:30:00',
      },
    ];
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.stageInvites, isEmpty);
    expect(find.text('所选时段面试官已被占用，请调整时间'), findsOneWidget);
    expect(find.byType(TalentInterviewInviteSheet), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-confirm-send'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('invite-confirm-cancel')));
    await tester.pumpAndSettle();
    source.slots = [];
    await fillTalentInvite(tester, hour: 11, minute: 0);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.stageInvites, hasLength(1));
    expect(source.stageInvites.single.first['startTime'], '2027-01-01 11:00:00');
  });

  testWidgets('面试官忙闲占用时冲突提示并禁止提交', (tester) async {
    final source = TalentFakeSource()
      ..slots = [
        {
          'status': 0,
          'startTime': '2027-01-01 09:00:00',
          'endTime': '2027-01-01 10:30:00',
        },
      ];
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 8, minute: 30);
    expect(find.byKey(const Key('invite-conflict')), findsOneWidget);
    expect(find.text('所选时段面试官已被占用'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNull,
    );
  });

  testWidgets('空面试人员列表显示空态，禁止提交', (tester) async {
    final source = TalentFakeSource()..people = [];
    await openInvite(tester, source);
    expect(find.text('暂无可用面试官'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
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
    expect(find.byKey(const Key('invite-stage-0')), findsOneWidget);
  });

  testWidgets('周历切周与回到今天刷新日历，日期格展示当日场次', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [
          interview(
            start: '2026-12-29 10:00:00',
            end: '2026-12-29 10:45:00',
          ),
        ],
      ];
    await openInvite(tester, source);
    expect(find.byKey(const Key('invite-week-day-1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('invite-week-day-1')),
        matching: find.text('1场'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('invite-week-day-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12月29日 · 1场面试'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-week-next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1月4日 – 1月10日'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-week-today')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12月28日 – 1月3日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动到底部后标题和关闭按钮固定可用', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    final title = find.text('邀请面试');
    final close = find.byKey(const Key('invite-close'));
    final titleRect = tester.getRect(title);
    final closeRect = tester.getRect(close);
    final scroll = find
        .descendant(
          of: find.byKey(const Key('invite-content-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final state = tester.state<ScrollableState>(scroll);
    expect(state.position.maxScrollExtent, greaterThan(0));
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getRect(title), titleRect);
    expect(tester.getRect(close), closeRect);
    expect(close.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('邀请面试弹窗在 $size 及键盘场景下无溢出', (tester) async {
      await openInvite(tester, TalentFakeSource());
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final timeline = find.byKey(const Key('invite-timeline'));
      await tester.ensureVisible(timeline);
      await tester.pumpAndSettle();
      final editor = find.byKey(const Key('invite-time-editor'));
      await tester.ensureVisible(editor);
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 120 : 260,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('未分析适配度时展示占位，不影响邀请流程', (tester) async {
    final source = TalentFakeSource()
      ..match = const TalentMatchData(requiredSkills: []);
    await openInvite(tester, source);
    expect(find.byKey(const Key('invite-match-score')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
