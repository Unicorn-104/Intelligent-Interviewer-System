import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_publish_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_publish_workflow.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'job_publish_page_test.dart' show fill, enter, options;

Future<void> mountWorkflow(
  WidgetTester tester, {
  Future<Map<String, dynamic>> Function(Map<String, Object?>)? submit,
  Future<void> Function(int, Map<String, Object?>)? save,
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
            onPressed: () => Navigator.of(context).push<int>(
              MaterialPageRoute(
                builder: (_) => JobPublishPage(
                  loadOptions: options,
                  submitJob: submit ?? (_) async => {'posId': 901},
                  saveWorkflow: save ?? (_, _) async {},
                ),
              ),
            ),
            child: const Text('打开发布页'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开发布页'));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> saveStage(WidgetTester tester) async {
  await tapKey(tester, 'job-publish-stage-save');
}

Future<void> chooseType(WidgetTester tester, int id, String label) async {
  await tapKey(tester, 'job-publish-stage-type-$id');
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> preview(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('job-publish-action')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('取消新增不生成卡片、不标记草稿，返回直接离开', (tester) async {
    await mountWorkflow(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await chooseType(tester, 0, '在线笔试');
    expect(find.byKey(const Key('job-publish-stage-name-0')), findsNothing);
    expect(find.text('阶段名称 *'), findsNothing);
    await tapKey(tester, 'job-publish-stage-cancel');
    expect(find.byType(JobPublishStageCard), findsNothing);
    expect(find.byType(JobPublishStageDialog), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(JobPublishPage), findsNothing);
    expect(find.text('离开岗位发布？'), findsNothing);
  });

  testWidgets('编辑使用独立副本，取消保留所有字段，保存后原位更新且编号不变', (tester) async {
    await mountWorkflow(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await tapKey(tester, 'job-publish-stage-edit-0');
    await enter(tester, 'job-publish-stage-duration-0', '60');
    await enter(tester, 'job-publish-stage-threshold-0', '90');
    await enter(tester, 'job-publish-stage-target-0', '取消的考察项');
    await chooseType(tester, 0, '在线笔试');
    await tester.ensureVisible(find.text('必选阶段'));
    await tester.tap(find.text('必选阶段'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'job-publish-stage-cancel');
    final original = tester
        .widget<JobPublishStageCard>(
          find.byKey(const Key('job-publish-stage-card-0')),
        )
        .stage;
    expect(original.name.text, 'HR 综合面试');
    expect(original.type, 3);
    expect(original.duration.text, '45');
    expect(original.threshold.text, '70');
    expect(original.target.text, isEmpty);
    expect(original.required, isFalse);
    expect(original.skip, isTrue);
    await tapKey(tester, 'job-publish-stage-edit-0');
    await chooseType(tester, 0, '编程实操');
    await saveStage(tester);
    final cards = tester
        .widgetList<JobPublishStageCard>(find.byType(JobPublishStageCard))
        .toList();
    expect(cards.map((card) => card.stage.id), [0, 1]);
    expect(cards.map((card) => card.index), [0, 1]);
    expect(cards.first.stage.name.text, '编程实操');
    expect(cards.first.stage.type, 4);
    expect(find.byType(JobPublishStageEditor), findsNothing);
    expect(find.byKey(const Key('job-publish-stage-name-0')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('数字输入框右侧上下按钮每次调整1并遵守范围', (tester) async {
    await mountWorkflow(tester);
    await tapKey(tester, 'job-publish-add-stage');

    final duration = find.byKey(const Key('job-publish-stage-duration-0'));
    final threshold = find.byKey(const Key('job-publish-stage-threshold-0'));
    await tapKey(tester, 'job-publish-stage-duration-increment-0');
    await tapKey(tester, 'job-publish-stage-duration-decrement-0');
    await tapKey(tester, 'job-publish-stage-threshold-increment-0');
    await tapKey(tester, 'job-publish-stage-threshold-decrement-0');
    expect(tester.widget<TextFormField>(duration).controller!.text, '45');
    expect(tester.widget<TextFormField>(threshold).controller!.text, '70');

    await enter(tester, 'job-publish-stage-duration-0', '1');
    await tapKey(tester, 'job-publish-stage-duration-decrement-0');
    expect(tester.widget<TextFormField>(duration).controller!.text, '1');
    await enter(tester, 'job-publish-stage-threshold-0', '100');
    await tapKey(tester, 'job-publish-stage-threshold-increment-0');
    expect(tester.widget<TextFormField>(threshold).controller!.text, '100');
    await tapKey(tester, 'job-publish-stage-cancel');
  });

  testWidgets('关闭按钮、系统返回和点击遮罩均取消编辑', (tester) async {
    await mountWorkflow(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    for (var action = 0; action < 3; action++) {
      await tapKey(tester, 'job-publish-stage-edit-0');
      await chooseType(tester, 0, '在线笔试');
      if (action == 0) {
        await tapKey(tester, 'job-publish-stage-close');
      } else if (action == 1) {
        Navigator.of(tester.element(find.byType(JobPublishStageDialog))).pop();
      } else {
        await tester.tapAt(const Offset(2, 2));
      }
      await tester.pumpAndSettle();
      expect(find.byType(JobPublishStageDialog), findsNothing);
      expect(
        tester
            .widget<JobPublishStageCard>(find.byType(JobPublishStageCard))
            .stage
            .name
            .text,
        'HR 综合面试',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('新增按钮位于JD下方，一次新增一个，始终追加末尾并保留前面输入', (tester) async {
    await mountWorkflow(tester);
    await tapKey(tester, 'job-publish-add-stage');
    expect(find.byType(JobPublishStageDialog), findsOneWidget);
    expect(find.byType(JobPublishStageCard), findsNothing);
    await chooseType(tester, 0, '在线笔试');
    await saveStage(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await chooseType(tester, 1, 'AI 技术面试');
    await saveStage(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    final editors = tester
        .widgetList<JobPublishStageCard>(find.byType(JobPublishStageCard))
        .toList();
    expect(editors.map((editor) => editor.stage.id), [0, 1, 2]);
    expect(editors.map((editor) => editor.index), [0, 1, 2]);
    expect(editors[0].stage.name.text, '在线笔试');
    expect(editors[0].stage.type, 1);
    expect(editors[1].stage.name.text, 'AI 技术面试');
    expect(editors[2].stage.name.text, 'HR 综合面试');
    final import = find.byKey(const Key('jd-document-import-card'));
    final add = find.byKey(const Key('job-publish-add-stage'));
    expect(
      tester.getTopLeft(add).dy,
      greaterThan(tester.getBottomLeft(import).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('job-publish-stage-2'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('job-publish-stage-1'))).dy,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('删除中间阶段后重新编号，继续新增仍追加末尾，不串改已有值', (tester) async {
    await mountWorkflow(tester);
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'job-publish-add-stage');
      await chooseType(tester, i, jobPublishStageTypes[i + 1]!);
      await saveStage(tester);
    }
    await tapKey(tester, 'job-publish-stage-remove-1');
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    final editors = tester
        .widgetList<JobPublishStageCard>(find.byType(JobPublishStageCard))
        .toList();
    expect(editors.map((editor) => editor.stage.id), [0, 2, 3]);
    expect(editors.map((editor) => editor.index), [0, 1, 2]);
    expect(editors[0].stage.name.text, '在线笔试');
    expect(editors[1].stage.name.text, 'HR 综合面试');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('四种面试方式与PC字段编码一致，预览往返保留所有流程及原岗位输入', (tester) async {
    await mountWorkflow(tester);
    for (final (index, label) in jobPublishStageTypes.values.indexed) {
      await tapKey(tester, 'job-publish-add-stage');
      await chooseType(tester, index, label);
      expect(
        find.byKey(ValueKey('job-publish-stage-name-$index')),
        findsNothing,
      );
      await saveStage(tester);
    }
    await fill(tester);
    await preview(tester);
    final workflow = find.byType(JobPublishWorkflowPreview);
    await tester.ensureVisible(workflow);
    await tester.pumpAndSettle();
    expect(workflow, findsOneWidget);
    final drafts = tester.widget<JobPublishWorkflowPreview>(workflow).stages;
    expect(drafts.map((stage) => stage.type), [1, 2, 3, 4]);
    expect(drafts.map((stage) => stage.name.text), jobPublishStageTypes.values);
    await tester.tap(find.text('返回修改'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<JobPublishStageCard>(find.byType(JobPublishStageCard))
          .length,
      4,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('job-title')))
          .controller!
          .text,
      'Flutter 开发工程师',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('时长阈值在弹窗校验，失败不保存卡片也不发布', (tester) async {
    var created = 0;
    await mountWorkflow(
      tester,
      submit: (_) async {
        created++;
        return {'posId': 901};
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await enter(tester, 'job-publish-stage-duration-0', '0');
    await enter(tester, 'job-publish-stage-threshold-0', '101');
    await saveStage(tester);
    expect(find.byType(JobPublishStageDialog), findsOneWidget);
    expect(find.byType(JobPublishStageCard), findsNothing);
    expect(find.text('确认发布'), findsNothing);
    expect(find.byKey(const Key('job-publish-stage-name-0')), findsNothing);
    expect(find.text('请输入1至1440的整数'), findsOneWidget);
    expect(find.text('请输入0至100的整数'), findsOneWidget);
    expect(created, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('确认前不请求，创建成功后用真实岗位ID保存有序流程，保存期间禁用重复操作', (tester) async {
    final events = <String>[];
    Map<String, Object?>? sentJob;
    Map<String, Object?>? sentWorkflow;
    final gate = Completer<void>();
    await mountWorkflow(
      tester,
      submit: (body) async {
        events.add('create');
        sentJob = body;
        return {'posId': 901};
      },
      save: (id, body) async {
        events.add('workflow:$id');
        sentWorkflow = body;
        await gate.future;
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await chooseType(tester, 0, '在线笔试');
    await enter(tester, 'job-publish-stage-duration-0', '60');
    await enter(tester, 'job-publish-stage-target-0', '算法与基础知识');
    await saveStage(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await chooseType(tester, 1, 'AI 技术面试');
    await saveStage(tester);
    await fill(tester);
    await preview(tester);
    expect(events, isEmpty);
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(events, ['create', 'workflow:901']);
    expect(sentJob!.containsKey('stages'), isFalse);
    expect(sentWorkflow!['templateName'], 'Flutter 开发工程师招聘流程');
    final stages = sentWorkflow!['stages'] as List;
    expect(stages.map((stage) => stage['name']), ['在线笔试', 'AI 技术面试']);
    expect(stages.map((stage) => stage['type']), [1, 2]);
    expect(stages[0]['duration'], 60);
    expect(stages[0]['target'], '算法与基础知识');
    final action = tester.widget<FilledButton>(
      find.byKey(const Key('job-publish-action')),
    );
    expect(action.onPressed, isNull);
    expect(find.text('返回修改'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(JobPublishPage), findsNothing);
    expect(events, ['create', 'workflow:901']);
  });

  testWidgets('创建岗位成功但保存流程失败，重试仅保存流程不重复发布岗位', (tester) async {
    var created = 0;
    var saved = 0;
    await mountWorkflow(
      tester,
      submit: (_) async {
        created++;
        return {'posId': 902};
      },
      save: (id, _) async {
        expect(id, 902);
        saved++;
        if (saved == 1) throw const ApiException('合成网络超时');
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await fill(tester);
    await preview(tester);
    await preview(tester);
    expect(created, 1);
    expect(saved, 1);
    expect(find.text('重试保存流程'), findsOneWidget);
    expect(find.textContaining('岗位已创建，招聘流程保存失败'), findsOneWidget);
    expect(find.text('返回修改'), findsNothing);
    await preview(tester);
    expect(created, 1);
    expect(saved, 2);
    expect(find.byType(JobPublishPage), findsNothing);
  });

  testWidgets('流程保存失败离开时明确提示已创建的岗位，不误报未发布', (tester) async {
    await mountWorkflow(
      tester,
      save: (_, _) async {
        throw const ApiException('合成失败');
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await fill(tester);
    await preview(tester);
    await preview(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('招聘流程尚未保存'), findsOneWidget);
    await tester.tap(find.text('继续保存'));
    await tester.pumpAndSettle();
    expect(find.byType(JobPublishPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回岗位列表'));
    await tester.pumpAndSettle();
    expect(find.byType(JobPublishPage), findsNothing);
  });

  testWidgets('未添加流程保持原发布行为，删除全部流程后不调用流程接口', (tester) async {
    var saved = 0;
    await mountWorkflow(
      tester,
      save: (_, _) async {
        saved++;
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await tapKey(tester, 'job-publish-stage-remove-0');
    await fill(tester);
    await preview(tester);
    await preview(tester);
    expect(saved, 0);
    expect(find.byType(JobPublishPage), findsNothing);
  });

  testWidgets('成功创建响应缺少ID时不保存流程且不允许重复创建', (tester) async {
    var created = 0;
    var saved = 0;
    await mountWorkflow(
      tester,
      submit: (_) async {
        created++;
        return {};
      },
      save: (_, _) async {
        saved++;
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await fill(tester);
    await preview(tester);
    await preview(tester);
    expect(created, 1);
    expect(saved, 0);
    expect(find.text('返回岗位列表'), findsOneWidget);
    expect(find.text('重试保存流程'), findsNothing);
    await tester.tap(find.text('返回岗位列表'));
    await tester.pumpAndSettle();
    expect(created, 1);
  });

  testWidgets('仅新增招聘流程即视为未保存草稿，返回需要确认', (tester) async {
    await mountWorkflow(tester);
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('离开岗位发布？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.byType(JobPublishStageCard), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('流程编辑在 $size 及键盘出现时不溢出', (tester) async {
      await mountWorkflow(tester, size: size);
      await tapKey(tester, 'job-publish-add-stage');
      await chooseType(tester, 0, '在线笔试');
      final target = find.byKey(const Key('job-publish-stage-target-0'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 120 : 260,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('创建岗位失败不保存流程，重试仍沿用原始顺序与配置', (tester) async {
    var created = 0;
    var saved = 0;
    await mountWorkflow(
      tester,
      submit: (_) async {
        created++;
        if (created == 1) throw const ApiException('合成创建失败');
        return {'posId': 903};
      },
      save: (id, body) async {
        expect(id, 903);
        saved++;
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await fill(tester);
    await preview(tester);
    await preview(tester);
    expect(created, 1);
    expect(saved, 0);
    expect(find.text('确认发布'), findsOneWidget);
    expect(find.text('合成创建失败'), findsOneWidget);
    await preview(tester);
    expect(created, 2);
    expect(saved, 1);
    expect(find.byType(JobPublishPage), findsNothing);
  });

  testWidgets('长岗位名生成的流程模板名不超过现有字段长度', (tester) async {
    String? template;
    await mountWorkflow(
      tester,
      save: (_, body) async {
        template = body['templateName'] as String;
      },
    );
    await tapKey(tester, 'job-publish-add-stage');
    await saveStage(tester);
    await fill(tester);
    await enter(tester, 'job-title', List.filled(100, '岗').join());
    await preview(tester);
    await preview(tester);
    expect(template!.length, 100);
    expect(template!.endsWith('招聘流程'), isTrue);
    expect(find.byType(JobPublishPage), findsNothing);
  });
}
