import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_invite_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
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
  testWidgets('固定标题与步骤指示器，阶段概览展示求职者卡与适配度', (tester) async {
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
    expect(find.text('面试阶段（1）'), findsOneWidget);
    expect(find.text('待安排面试时间'), findsOneWidget);
    expect(find.text('设置时间'), findsOneWidget);
    expect(find.byKey(const Key('invite-week-strip')), findsOneWidget);
    expect(find.text('查看排期，避免冲突'), findsOneWidget);
    // 未设置时间前不允许进入下一步。
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNull,
    );
    expect(source.invites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未分析适配度时展示占位，不影响邀请流程', (tester) async {
    final source = TalentFakeSource()
      ..match = const TalentMatchData(requiredSkills: []);
    await openInvite(tester, source);
    expect(find.byKey(const Key('invite-match-score')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('时间轴选择面试时间：面试官弹层搜索选择、保存后概览展示时间', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await tester.tap(find.byKey(const Key('invite-stage-edit-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-detail-title')), findsOneWidget);
    expect(find.textContaining('第 1 / 1 阶段'), findsOneWidget);
    expect(find.byKey(const Key('invite-timeline')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-interviewer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('interviewer-search')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('interviewer-search')),
      '合成',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('合成面试官 · 技术部'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('interviewer-option-19')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('interviewer-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('面试官：合成面试官'), findsOneWidget);
    await fillTalentInvite(tester);
    expect(find.byKey(const Key('invite-detail-title')), findsNothing);
    expect(find.textContaining('2027-01-01 09:30'), findsOneWidget);
    expect(find.textContaining('合成面试官 · 45分钟'), findsOneWidget);
    expect(source.invites, isEmpty);
    // 已设置时间后下一步可用。
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('取消保存丢弃临时选择，阶段保持原状态', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester, save: false);
    expect(find.byKey(const Key('invite-slot-info')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-stage-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('待安排面试时间'), findsOneWidget);
    expect(find.textContaining('2027-01-01 09:30'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-submit'))).onPressed,
      isNull,
    );
    expect(source.invites, isEmpty);
  });

  testWidgets('与已有面试冲突时高亮提示并禁止保存', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [
          {
            'appointmentId': 501,
            'candidateName': '其他候选人',
            'stageName': '技术面试',
            'positionTitle': '其他岗位',
            'status': 0,
            'startTime': '2027-01-01 09:00:00',
            'endTime': '2027-01-01 10:00:00',
          },
        ],
      ];
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 8, minute: 30, save: false);
    expect(find.byKey(const Key('invite-conflict')), findsOneWidget);
    expect(find.text('该时间段已有面试安排，请选择其他时间'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-stage-save'))).onPressed,
      isNull,
    );
    // 改选无冲突时段后恢复。
    final timeline = find.byKey(const Key('invite-timeline'));
    await tester.ensureVisible(timeline);
    final scrollable = find
        .descendant(of: timeline, matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo((11 * 60 - 60) * 56 / 60);
    await tester.pumpAndSettle();
    final rect = tester.getRect(timeline);
    await tester.tapAt(Offset(rect.left + 120, rect.top + 58));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-conflict')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-stage-save'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('面试官忙闲占用时保存被拦截并提示', (tester) async {
    final source = TalentFakeSource()
      ..slots = [
        {
          'status': 0,
          'startTime': '2027-01-01 09:00:00',
          'endTime': '2027-01-01 10:30:00',
        },
      ];
    await openInvite(tester, source);
    await fillTalentInvite(tester, hour: 8, minute: 30, save: false);
    // 忙闲已加载：时间轴直接提示冲突。
    expect(find.byKey(const Key('invite-conflict')), findsOneWidget);
    expect(find.text('所选时段面试官已被占用'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-stage-save'))).onPressed,
      isNull,
    );
  });

  testWidgets('时长步进器修改结束时间并重新校验冲突', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [
          {
            'appointmentId': 501,
            'candidateName': '其他候选人',
            'stageName': '技术面试',
            'status': 0,
            'startTime': '2027-01-01 10:00:00',
            'endTime': '2027-01-01 10:30:00',
          },
        ],
      ];
    await openInvite(tester, source);
    await fillTalentInvite(tester, save: false);
    // 09:30 + 45 分钟 → 10:15，与 10:00-10:30 冲突。
    expect(find.byKey(const Key('invite-conflict')), findsOneWidget);
    // 减到 25 分钟 → 09:30-09:55 不再冲突。
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('invite-duration-decrement')));
      await tester.pumpAndSettle();
    }
    expect(find.text('25 分钟'), findsOneWidget);
    expect(find.byKey(const Key('invite-conflict')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-stage-save'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('下一步进入确认页，确认邀请才调用接口并关闭弹窗', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    final queries = source.availabilityQueries.length;
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-confirm-candidate')), findsOneWidget);
    expect(find.text('面试安排汇总'), findsOneWidget);
    expect(find.byKey(const Key('invite-confirm-stage-0')), findsOneWidget);
    expect(find.textContaining('2027-01-01 09:30'), findsOneWidget);
    expect(find.text('待发送'), findsOneWidget);
    expect(source.invites, isEmpty);
    expect(source.availabilityQueries.length, greaterThan(queries));
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.invites, hasLength(1));
    expect(source.invites.single, {
      'candidateId': 11,
      'positionId': 7,
      'interviewerId': 19,
      'startTime': '2027-01-01 09:30:00',
      'durationMin': 45,
    });
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  testWidgets('确认页返回修改不发邀请，可再次进入确认', (tester) async {
    final source = TalentFakeSource();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    final queries = source.availabilityQueries.length;
    await tester.tap(find.byKey(const Key('invite-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-stage-0')), findsOneWidget);
    expect(source.invites, isEmpty);
    expect(source.availabilityQueries.length, queries);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-confirm-send')), findsOneWidget);
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
    expect(source.invites, isEmpty);
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
    expect(source.invites, hasLength(1));
    expect(source.invites.single['startTime'], '2027-01-01 11:00:00');
  });

  testWidgets('按招聘流程阶段分别排期，确认后发送阶段ID批量邀约', (tester) async {
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
    expect(find.text('面试阶段（2）'), findsOneWidget);
    expect(find.text('必选'), findsOneWidget);
    await fillTalentInvite(tester);
    await tester.tap(find.byKey(const Key('invite-stage-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 2 / 2 阶段'), findsOneWidget);
    await fillTalentInvite(tester, hour: 9, minute: 45, save: false);
    // 后一阶段 09:45 早于前一阶段结束时间 10:00（09:30+30），保存仍允许，
    // 顺序校验在确认页执行。
    await tester.tap(find.byKey(const Key('invite-stage-save')));
    await tester.pumpAndSettle();
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
    // 调整第二阶段时间后再确认。
    await tester.tap(find.byKey(const Key('invite-confirm-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-stage-1')));
    await tester.pumpAndSettle();
    await fillTalentInvite(tester, hour: 11, minute: 0);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pumpAndSettle();
    expect(source.stageInvites, hasLength(1));
    expect(source.stageInvites.single.map((row) => row['stageId']), [31, 32]);
    expect(source.invites, isEmpty);
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  testWidgets('已安排阶段可改期，历史安排只读', (tester) async {
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
    await tester.tap(find.byKey(const Key('invite-stage-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-detail-title')), findsOneWidget);
    expect(find.byKey(const Key('invite-slot-info')), findsOneWidget);
    // 改期到 11:00 并保存。
    await fillTalentInvite(tester, hour: 11, minute: 0);
    expect(source.reschedules, hasLength(1));
    expect(source.reschedules.single['newStartTime'], '2027-01-02 11:00:00');
    expect(find.byKey(const Key('invite-detail-title')), findsNothing);
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
    await tester.tap(find.byKey(const Key('invite-stage-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('仅可查看'), findsOneWidget);
    expect(find.byKey(const Key('invite-stage-save')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('invite-stage-save'))).onPressed,
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

  testWidgets('提交中防重复点击，成功后关闭弹窗', (tester) async {
    final source = TalentFakeSource()
      ..invitePending = Completer<Map<String, dynamic>>();
    await openInvite(tester, source);
    await fillTalentInvite(tester);
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-confirm-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(source.invites, hasLength(1));
    final send = find.byKey(const Key('invite-confirm-send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(send);
    await tester.pump();
    expect(source.invites, hasLength(1));
    source.invitePending!.complete({'appointmentId': 101});
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('邀请面试弹窗在 $size 及键盘场景下无溢出', (tester) async {
      await openInvite(tester, TalentFakeSource());
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-stage-edit-0')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 120 : 260,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-stage-cancel')));
      await tester.pumpAndSettle();
    });
  }

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

  testWidgets('周历切周与回到今天刷新日历，日期格展示当日场次', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [
          {
            'appointmentId': 501,
            'candidateName': '其他候选人',
            'stageName': '技术面试',
            'status': 0,
            'startTime': '2026-12-29 10:00:00',
            'endTime': '2026-12-29 10:45:00',
          },
        ],
      ];
    await openInvite(tester, source);
    // 时钟为 2027-01-01（UTC+8 周四），初始周为 2026-12-28 起。
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
}
