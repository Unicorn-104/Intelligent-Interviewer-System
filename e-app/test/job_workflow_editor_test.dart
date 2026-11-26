import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_publish_workflow.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_workflow_section.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'job_publish_page_test.dart' show enter;
import 'job_publish_workflow_test.dart' show tapKey;

Map<String, dynamic> initialWorkflow() => {
  'template': {'name': 'workflow'},
  'stages': [
    {
      'name': 'written',
      'type': 1,
      'required': 1,
      'threshold': 80,
      'configJson': '{"target":"fundamentals","skip":false,"terminate":true}',
    },
    {
      'name': 'interview',
      'type': 3,
      'required': 0,
      'threshold': 70,
      'configJson': '{"duration":45,"mode":"human"}',
    },
  ],
};

Future<void> openEditor(
  WidgetTester tester, {
  required Future<bool> Function(Map<String, Object?>) onSave,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
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
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('existing workflow keeps only supported stage types', (
    tester,
  ) async {
    Map<String, Object?>? saved;
    await openEditor(
      tester,
      onSave: (body) async {
        saved = body;
        return true;
      },
    );
    expect(find.byType(JobPublishStageCard), findsNWidgets(2));
    expect(find.byKey(const Key('job-workflow-up-0')), findsNothing);
    expect(find.byKey(const Key('job-workflow-down-0')), findsNothing);
    await tapKey(tester, 'job-workflow-save');
    final stages = saved!['stages'] as List;
    expect(stages.map((stage) => stage['type']), [1, 3]);
  });

  testWidgets('stage names are editable and defaults are preserved', (
    tester,
  ) async {
    Map<String, Object?>? saved;
    await openEditor(
      tester,
      onSave: (body) async {
        saved = body;
        return true;
      },
    );
    await tapKey(tester, 'job-publish-stage-edit-0');
    expect(find.byKey(const Key('job-publish-stage-name-0')), findsOneWidget);
    await enter(tester, 'job-publish-stage-name-0', 'written-custom');
    await tapKey(tester, 'job-publish-stage-save');
    await tapKey(tester, 'job-workflow-save');
    final stages = saved!['stages'] as List;
    expect((stages.first as Map)['name'], 'written-custom');
    expect((stages.last as Map)['name'], 'interview');
  });

  testWidgets('new stages expose only written-test and interview choices', (
    tester,
  ) async {
    await openEditor(tester, onSave: (_) async => true);
    await tapKey(tester, 'job-workflow-add-stage');
    expect(find.text('阶段类型 *'), findsOneWidget);
    expect(find.text('重点考察项'), findsNothing);
    expect(find.byKey(const Key('job-publish-stage-target-2')), findsNothing);
    final typeField = find.byKey(const Key('job-publish-stage-type-2'));
    expect(
      find.descendant(of: typeField, matching: find.byType(CheckboxListTile)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: typeField,
        matching: find.text(jobPublishStageTypeOptions[1]!),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: typeField,
        matching: find.text(jobPublishStageTypeOptions[3]!),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('AI'), findsNothing);
    expect(find.textContaining('coding'), findsNothing);
    await tapKey(tester, 'job-publish-stage-type-2-1');
    final exam = tester.widget<CheckboxListTile>(
      find.byKey(const Key('job-publish-stage-type-2-1')),
    );
    final interview = tester.widget<CheckboxListTile>(
      find.byKey(const Key('job-publish-stage-type-2-3')),
    );
    expect(exam.value, isTrue);
    expect(interview.value, isFalse);
  });
}
