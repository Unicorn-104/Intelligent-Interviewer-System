import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_workflow_section.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_publish_workflow.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'job_publish_page_test.dart' show enter;
import 'job_publish_workflow_test.dart' show tapKey, chooseType;

Map<String, dynamic> initialWorkflow() => {
  'template': {'name': '合成招聘流程'},
  'stages': [
    {
      'name': '技术面试',
      'type': 2,
      'required': 1,
      'threshold': 80,
      'configJson': '{"duration":60,"interviewer":"原面试官","mode":"ai_human_hybrid","target":"系统设计","skip":false,"terminate":true,"interviewer_ids":[19,20]}',
    },
    {
      'name': '综合面试',
      'type': 3,
      'required': 0,
      'threshold': 70,
      'configJson': '{"duration":45,"mode":"human","target":"沟通表达"}',
    },
  ],
};

Future<void> openEditor(
  WidgetTester tester, {
  required Future<bool> Function(Map<String, Object?>) onSave,
  Size size = const Size(430, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showJobWorkflowEditor(
              context: context,
              data: initialWorkflow(),
              onSave: onSave,
            ),
            child: const Text('打开流程编辑'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开流程编辑'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('节点弹窗保存失败保留内容，重试期间禁用删除和重复提交', (tester) async {
    var calls = 0;
    final gate = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showJobWorkflowStageEditor(
                context: context,
                data: initialWorkflow(),
                index: 0,
                onSave: (_) async {
                  calls++;
                  return calls == 1 ? false : gate.future;
                },
              ),
              child: const Text('编辑节点'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑节点'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'job-publish-stage-save');
    expect(find.text('流程保存失败，请核对后重试'), findsOneWidget);
    expect(find.byType(JobPublishStageDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-publish-stage-save')));
    await tester.pump();
    expect(calls, 2);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('job-publish-stage-save')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('job-publish-stage-delete')))
          .onPressed,
      isNull,
    );
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(JobPublishStageDialog), findsNothing);
  });

  testWidgets('节点编辑弹窗可直接删除对应阶段，保留其他阶段配置', (tester) async {
    Map<String, Object?>? sent;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showJobWorkflowStageEditor(
                context: context,
                data: initialWorkflow(),
                index: 0,
                onSave: (body) async {
                  sent = body;
                  return true;
                },
              ),
              child: const Text('编辑节点'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑节点'));
    await tester.pumpAndSettle();
    expect(find.byType(JobPublishStageDialog), findsOneWidget);
    expect(find.byType(JobPublishStageCard), findsNothing);
    await tapKey(tester, 'job-publish-stage-delete');
    expect(sent!['templateName'], '合成招聘流程');
    final stages = sent!['stages'] as List;
    expect(stages, hasLength(1));
    expect(stages.single['name'], '综合面试');
    expect(stages.single['mode'], 'human');
    expect(stages.single['target'], '沟通表达');
    expect(find.byType(JobPublishStageDialog), findsNothing);
  });

  testWidgets('既有阶段无需改选面试方式，保存弹窗自动使用面试方式作名称', (tester) async {
    Map<String, Object?>? sent;
    await openEditor(
      tester,
      onSave: (body) async {
        sent = body;
        return true;
      },
    );
    await tapKey(tester, 'job-publish-stage-edit-0');
    expect(find.byKey(const Key('job-publish-stage-name-0')), findsNothing);
    await tapKey(tester, 'job-publish-stage-save');
    final first = tester
        .widget<JobPublishStageCard>(
          find.byKey(const Key('job-workflow-stage-0')),
        )
        .stage;
    expect(first.name.text, 'AI 技术面试');
    expect(sent, isNull);
    await tapKey(tester, 'job-workflow-save');
    final saved = (sent!['stages'] as List).first;
    expect(saved['name'], 'AI 技术面试');
    expect(saved['type'], 2);
    expect(saved['interviewer'], '原面试官');
    expect(saved['mode'], 'ai_human_hybrid');
    expect(saved['interviewer_ids'], [19, 20]);
  });

  testWidgets('详情流程使用发布岗位卡片和相同阶段弹窗，取消不修改，保存保留原隐藏配置', (tester) async {
    Map<String, Object?>? sent;
    await openEditor(
      tester,
      onSave: (body) async {
        sent = body;
        return true;
      },
    );
    expect(find.byType(JobPublishStageCard), findsNWidgets(2));
    expect(find.byKey(const Key('job-workflow-name')), findsNothing);
    expect(find.text('流程名称'), findsNothing);
    for (final id in [0, 1]) {
      final card = find.byKey(ValueKey('job-workflow-stage-$id'));
      final up = find.byKey(ValueKey('job-workflow-up-$id'));
      final down = find.byKey(ValueKey('job-workflow-down-$id'));
      expect(find.descendant(of: card, matching: up), findsOneWidget);
      expect(find.descendant(of: card, matching: down), findsOneWidget);
      expect(tester.getRect(card).contains(tester.getCenter(up)), isTrue);
      expect(tester.getRect(card).contains(tester.getCenter(down)), isTrue);
      expect(tester.getCenter(down).dx, greaterThan(tester.getCenter(up).dx));
      expect(
        tester.getBottomRight(card).dy - tester.getBottomRight(down).dy,
        lessThan(20),
      );
      expect(
        tester.getBottomRight(card).dx - tester.getBottomRight(down).dx,
        lessThan(20),
      );
    }
    expect(find.byType(JobPublishStageEditor), findsNothing);
    await tapKey(tester, 'job-publish-stage-edit-0');
    expect(find.byType(JobPublishStageDialog), findsOneWidget);
    expect(find.text('编辑招聘流程'), findsNWidgets(2));
    expect(find.byKey(const Key('job-publish-stage-name-0')), findsNothing);
    expect(find.text('阶段名称 *'), findsNothing);
    await chooseType(tester, 0, '在线笔试');
    await tapKey(tester, 'job-publish-stage-cancel');
    final first = tester
        .widget<JobPublishStageCard>(
          find.byKey(const Key('job-workflow-stage-0')),
        )
        .stage;
    expect(first.name.text, '技术面试');
    expect(first.type, 2);
    expect(sent, isNull);
    await tapKey(tester, 'job-publish-stage-edit-0');
    await chooseType(tester, 0, '编程实操');
    await tapKey(tester, 'job-publish-stage-duration-increment-0');
    await enter(tester, 'job-publish-stage-target-0', '编程能力');
    await tapKey(tester, 'job-publish-stage-save');
    expect(sent, isNull);
    await tapKey(tester, 'job-workflow-save');
    expect(sent!['templateName'], '合成招聘流程');
    final stages = sent!['stages'] as List;
    expect(stages.first['name'], '编程实操');
    expect(stages.first['type'], 4);
    expect(stages.first['duration'], 61);
    expect(stages.first['threshold'], 80);
    expect(stages.first['target'], '编程能力');
    expect(stages.first['interviewer'], '原面试官');
    expect(stages.first['mode'], 'ai_human_hybrid');
    expect(stages.first['interviewer_ids'], [19, 20]);
    expect(stages.first['required'], isTrue);
    expect(stages.first['skip'], isFalse);
    expect(stages.first['terminate'], isTrue);
    expect(stages.last.containsKey('skip'), isFalse);
    expect(stages.last.containsKey('interviewer'), isFalse);
    expect(find.text('打开流程编辑'), findsOneWidget);
  });

  testWidgets('新增弹窗取消不追加，保存追加到末尾，顺序移动和删除沿用现有功能', (tester) async {
    Map<String, Object?>? sent;
    await openEditor(
      tester,
      onSave: (body) async {
        sent = body;
        return true;
      },
    );
    await tapKey(tester, 'job-workflow-add-stage');
    await tapKey(tester, 'job-publish-stage-cancel');
    expect(find.byType(JobPublishStageCard), findsNWidgets(2));
    await tapKey(tester, 'job-workflow-add-stage');
    await chooseType(tester, 3, '在线笔试');
    await tapKey(tester, 'job-publish-stage-save');
    final cards = tester
        .widgetList<JobPublishStageCard>(find.byType(JobPublishStageCard))
        .toList();
    expect(cards.map((card) => card.stage.name.text), ['技术面试', '综合面试', '在线笔试']);
    await tapKey(tester, 'job-workflow-up-3');
    await tapKey(tester, 'job-publish-stage-remove-1');
    await tapKey(tester, 'job-workflow-save');
    expect((sent!['stages'] as List).map((row) => row['name']), [
      '技术面试',
      '在线笔试',
    ]);
  });

  testWidgets('阶段弹窗验证失败不更新卡片，整个流程取消不发送保存', (tester) async {
    var saves = 0;
    await openEditor(
      tester,
      onSave: (_) async {
        saves++;
        return true;
      },
    );
    await tapKey(tester, 'job-publish-stage-edit-0');
    await enter(tester, 'job-publish-stage-duration-0', '0');
    await enter(tester, 'job-publish-stage-threshold-0', '101');
    await tapKey(tester, 'job-publish-stage-save');
    expect(find.byType(JobPublishStageDialog), findsOneWidget);
    expect(find.byKey(const Key('job-publish-stage-name-0')), findsNothing);
    expect(find.text('请输入1至1440的整数'), findsOneWidget);
    expect(find.text('请输入0至100的整数'), findsOneWidget);
    await tapKey(tester, 'job-publish-stage-close');
    await tapKey(tester, 'job-workflow-close');
    expect(saves, 0);
  });

  testWidgets('保存失败保留阶段卡片，保存中禁止重复提交', (tester) async {
    var saves = 0;
    final gate = Completer<bool>();
    await openEditor(
      tester,
      onSave: (_) async {
        saves++;
        return saves == 1 ? false : gate.future;
      },
    );
    await tapKey(tester, 'job-workflow-save');
    expect(find.text('流程保存失败，请核对后重试'), findsOneWidget);
    expect(find.byType(JobPublishStageCard), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('job-workflow-save')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('job-workflow-save')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('job-workflow-add-stage')),
          )
          .onPressed,
      isNull,
    );
    expect(saves, 2);
    gate.complete(true);
    await tester.pumpAndSettle();
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('统一流程编辑在 $size 和键盘出现时无溢出', (tester) async {
      await openEditor(tester, onSave: (_) async => true, size: size);
      await tapKey(tester, 'job-publish-stage-edit-0');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 120 : 260,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tapKey(tester, 'job-publish-stage-cancel');
    });
  }
}
