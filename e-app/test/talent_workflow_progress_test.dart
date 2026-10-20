import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_detail_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_workflow_progress.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_workflow_progress.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

class ProgressSource extends TalentDetailDataSource {
  int reads = 0, plans = 0, sessionReads = 0;
  bool fails = false, sessionFails = false;
  int count = 2;
  Completer<Map<String, dynamic>>? gate;
  List<Map<String, dynamic>> appointments = [];
  Map<int, Map<String, dynamic>> sessions = {};
  @override
  Future<Map<String, dynamic>> loadWorkflow(int positionId) async {
    reads++;
    if (fails) throw StateError('synthetic');
    return await gate?.future ??
        {
          'stages': List.generate(
            count,
            (i) => {
              'stageId': i + 1,
              'name': '合成阶段${i + 1}',
              'sortOrder': i + 1,
            },
          ),
        };
  }

  @override
  Future<List<Map<String, dynamic>>> loadCandidatePlan(
    int candidateId,
    int positionId,
  ) async {
    plans++;
    return appointments;
  }

  @override
  Future<Map<String, dynamic>> loadWorkflowSession(int id) async {
    sessionReads++;
    if (sessionFails) throw StateError('synthetic');
    return sessions[id] ?? {};
  }
}

const job = TalentJobContext(
  positionId: 7,
  title: '合成岗位',
  currentStage: '合成阶段2',
);

Future<void> mount(
  WidgetTester tester,
  ProgressSource source, {
  double width = 430,
  double scale = 1,
  int revision = 0,
  TalentJobContext? context = job,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: TalentWorkflowProgress(
            candidateId: 11,
            job: context,
            source: source,
            revision: revision,
          ),
        ),
      ),
    ),
  );
  if (source.gate == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> appointment(
  int stage, {
  int status = 0,
  int candidate = 11,
  int position = 7,
  int? session,
}) => {
  'appointmentId': stage + 100,
  'candidateId': candidate,
  'positionId': position,
  'stageId': stage,
  'status': status,
  'startTime': '2020-01-01 09:00:00',
  'endTime': '2020-01-01 10:00:00',
  'sessionId': ?session,
};

void main() {
  test('参加进度只匹配实际阶段ID，完成记录不推断其他阶段已参加', () {
    final stages = talentWorkflowStages(
      workflow: {
        'stages': [
          {'stageId': 3, 'name': '第三阶段', 'sortOrder': 3},
          {'stageId': 1, 'name': '第一阶段', 'sortOrder': 1},
          {'stageId': 2, 'name': '第二阶段', 'sortOrder': 2},
        ],
      },
      appointments: [
        appointment(2, status: 3),
        appointment(1, status: 2),
        appointment(3, candidate: 99, status: 3),
        appointment(3, position: 99, status: 3),
      ],
      candidateId: 11,
      positionId: 7,
      sessions: {},
      currentStage: '第三阶段',
    );
    expect(stages.map((s) => s.id), [1, 2, 3]);
    expect(stages.map((s) => s.attended), [false, true, false]);
    expect(stages.last.current, isTrue);
  });

  test('已预约/已过期不算参加，会话须核对候选人岗位预约及实际开始', () {
    final workflow = {
      'stages': [
        for (var i = 1; i <= 5; i++) {'stageId': i, 'name': '阶段$i'},
      ],
    };
    final appointments = [
      for (var i = 1; i <= 5; i++) appointment(i, session: i + 200),
    ];
    Map<String, dynamic> session(int stage) => {
      'sessionId': stage + 200,
      'appointmentId': stage + 100,
      'candidateId': 11,
      'positionId': 7,
      'status': 2,
      'startAt': '2026-10-18 09:00:00',
    };
    final stages = talentWorkflowStages(
      workflow: workflow,
      appointments: appointments,
      candidateId: 11,
      positionId: 7,
      sessions: {
        201: session(1),
        202: {...session(2), 'candidateId': 99},
        203: {...session(3), 'appointmentId': 999},
        204: {...session(4), 'startAt': null},
        205: {...session(5), 'status': 3},
      },
    );
    expect(stages.map((s) => s.attended), [true, false, false, false, false]);
    final noSessions = talentWorkflowStages(
      workflow: workflow,
      appointments: appointments,
      candidateId: 11,
      positionId: 7,
      sessions: {},
    );
    expect(noSessions.every((s) => !s.attended), isTrue);
  });

  testWidgets('两阶段无需箭头省略，已参加节点和指向下一阶段的线为绿色', (tester) async {
    final source = ProgressSource()..appointments = [appointment(1, status: 3)];
    await mount(tester, source);
    expect(find.byKey(const Key('talent-flow-prev')), findsNothing);
    expect(find.byKey(const Key('talent-flow-next')), findsNothing);
    expect(find.text('...'), findsNothing);
    final line = tester.widget<Container>(
      find.byKey(const ValueKey('talent-flow-line-1')),
    );
    expect(line.color, AppColors.success);
    final node = tester.widget<Container>(
      find.byKey(const ValueKey('talent-flow-dot-1')),
    );
    expect(
      (node.decoration as BoxDecoration).color,
      AppColors.success.withValues(alpha: .12),
    );
    expect(find.text('合成阶段1'), findsOneWidget);
    expect(source.reads, 1);
    expect(source.plans, 1);
    expect(source.sessionReads, 0);
  });

  for (final count in [2, 6]) {
    testWidgets('$count个节点的两半连线实际占宽且首尾衔接，已完成阶段为绿线', (tester) async {
      final source = ProgressSource()
        ..count = count
        ..appointments = [appointment(1, status: 3)];
      await mount(tester, source, width: 320);
      final outgoing = find.byKey(const ValueKey('talent-flow-line-1'));
      final incoming = find.byKey(const ValueKey('talent-flow-line-in-2'));
      final dot1 = find.byKey(const ValueKey('talent-flow-dot-1'));
      final dot2 = find.byKey(const ValueKey('talent-flow-dot-2'));
      expect(tester.getSize(outgoing).width, greaterThan(20));
      expect(tester.getSize(incoming).width, greaterThan(20));
      expect(
        tester.getTopLeft(outgoing).dx,
        closeTo(tester.getCenter(dot1).dx, .1),
      );
      expect(
        tester.getTopRight(outgoing).dx,
        closeTo(tester.getTopLeft(incoming).dx, .1),
      );
      expect(
        tester.getTopRight(incoming).dx,
        closeTo(tester.getCenter(dot2).dx, .1),
      );
      expect(
        tester.getCenter(outgoing).dy,
        closeTo(tester.getCenter(dot1).dy, .1),
      );
      expect(
        tester.getCenter(incoming).dy,
        closeTo(tester.getCenter(dot2).dy, .1),
      );
      expect(tester.widget<Container>(outgoing).color, AppColors.success);
      expect(tester.widget<Container>(incoming).color, AppColors.success);
      if (count > 2) {
        expect(
          tester
              .widget<Container>(
                find.byKey(const ValueKey('talent-flow-line-2')),
              )
              .color,
          AppColors.hairline,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('溢出时省略号与方向按钮出现，点击及水平滚动可查看前后阶段', (tester) async {
    final source = ProgressSource()..count = 8;
    await mount(tester, source, width: 320);
    expect(find.byKey(const Key('talent-flow-prev')), findsNothing);
    expect(find.byKey(const Key('talent-flow-next')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('talent-flow-hidden-right')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('talent-flow-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('talent-flow-prev')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('talent-flow-hidden-left')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('talent-flow-scroll')),
      const Offset(-1500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('talent-flow-next')), findsNothing);
    expect(find.text('合成阶段8').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('talent-flow-prev')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('talent-flow-next')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('talent-flow-scroll')),
      const Offset(1500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('talent-flow-prev')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单阶段无连线，无岗位无请求，空流程不编造节点', (tester) async {
    final source = ProgressSource()..count = 1;
    await mount(tester, source);
    expect(find.text('合成阶段1'), findsOneWidget);
    expect(find.byKey(const ValueKey('talent-flow-line-1')), findsNothing);
    source.count = 0;
    await mount(tester, source, revision: 1);
    expect(find.text('暂无招聘流程'), findsOneWidget);
    final fresh = ProgressSource();
    await mount(tester, fresh, context: null);
    expect(find.text('选择岗位后查看流程'), findsOneWidget);
    expect(fresh.reads, 0);
    expect(fresh.plans, 0);
  });

  testWidgets('流程失败可重试，会话无法核实保留节点且不标绿', (tester) async {
    final source = ProgressSource()..fails = true;
    await mount(tester, source);
    expect(find.text('流程暂不可用'), findsOneWidget);
    source.fails = false;
    source.appointments = [appointment(1, session: 201)];
    source.sessionFails = true;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('合成阶段1'), findsOneWidget);
    expect(find.text('部分参加记录待核实'), findsOneWidget);
    final line = tester.widget<Container>(
      find.byKey(const ValueKey('talent-flow-line-1')),
    );
    expect(line.color, AppColors.hairline);
  });

  testWidgets('revision更新重新读取，迟到响应不能覆盖新岗位或销毁页面', (tester) async {
    final source = ProgressSource()..gate = Completer<Map<String, dynamic>>();
    await mount(tester, source);
    final oldGate = source.gate!;
    source.gate = null;
    source.count = 1;
    await mount(tester, source, revision: 1);
    expect(find.text('合成阶段1'), findsOneWidget);
    oldGate.complete({
      'stages': [
        {'stageId': 99, 'name': '过期流程'},
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('过期流程'), findsNothing);
    final late = Completer<Map<String, dynamic>>();
    source.gate = late;
    await mount(tester, source, revision: 2);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    late.complete({'stages': []});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320dp字号$scale水平流程无布局溢出', (tester) async {
      await mount(
        tester,
        ProgressSource()..count = 7,
        width: 320,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('talent-flow-scroll')),
        const Offset(-800, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
