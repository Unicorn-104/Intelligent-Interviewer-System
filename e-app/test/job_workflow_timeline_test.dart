import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/models/job_detail_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_workflow_timeline.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mountTimeline(
  WidgetTester tester,
  List<Map<String, dynamic>> stages, {
  double width = 430,
  double scale = 1,
  bool loading = false,
  String? error,
  VoidCallback? reload,
  VoidCallback? onAddStage,
}) async {
  tester.view.physicalSize = Size(width, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RepaintBoundary(
              key: const Key('workflow-timeline-paint'),
              child: JobWorkflowTimeline(
                state: JobSectionState(
                  data: {'stages': stages},
                  loading: loading,
                  error: error,
                ),
                onReload: reload ?? () {},
                onAddStage: onAddStage,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('连线完整绘制在每对节点之间，不被节点点击区域遮挡', (tester) async {
    await mountTimeline(tester, [
      {'name': '在线笔试'},
      {'name': 'HR 综合面试'},
    ], onAddStage: () {});
    await tester.pumpAndSettle();
    final paint = find.byKey(const Key('workflow-timeline-paint'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(paint);
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final origin = tester.getTopLeft(paint);
        final nodes = [
          find.byKey(const Key('job-workflow-node-0')),
          find.byKey(const Key('job-workflow-node-1')),
          find.byKey(const Key('job-workflow-placeholder')),
        ];
        for (var i = 0; i < nodes.length - 1; i++) {
          final left = tester.getRect(nodes[i]).shift(-origin);
          final right = tester.getRect(nodes[i + 1]).shift(-origin);
          final y = left.center.dy.floor();
          for (var x = left.right.ceil() + 2; x < right.left.floor() - 2; x++) {
            final offset = (y * image.width + x) * 4;
            final argb =
                (bytes.getUint8(offset + 3) << 24) |
                (bytes.getUint8(offset) << 16) |
                (bytes.getUint8(offset + 1) << 8) |
                bytes.getUint8(offset + 2);
            expect(
              argb,
              AppColors.hairline.toARGB32(),
              reason: '节点$i到节点${i + 1}之间的连线在x=$x处应连续可见',
            );
          }
        }
      } finally {
        image.dispose();
      }
    });
  });

  testWidgets('真实阶段按原顺序显示为节点，节点之间通过线连接', (tester) async {
    await mountTimeline(tester, [
      {'name': '在线笔试'},
      {'name': 'AI技术面试'},
      {'name': 'HR综合面试'},
    ]);
    final nodes = [
      for (var i = 0; i < 3; i++) find.byKey(ValueKey('job-workflow-node-$i')),
    ];
    for (final node in nodes) {
      expect(node, findsOneWidget);
    }
    expect(find.byKey(const Key('job-workflow-timeline-line')), findsOneWidget);
    expect(
      tester.getCenter(nodes[0]).dx,
      lessThan(tester.getCenter(nodes[1]).dx),
    );
    expect(
      tester.getCenter(nodes[1]).dx,
      lessThan(tester.getCenter(nodes[2]).dx),
    );
    expect(find.text('在线笔试'), findsOneWidget);
    expect(find.text('AI技术面试'), findsOneWidget);
    expect(find.text('HR综合面试'), findsOneWidget);
    expect(find.byKey(const Key('job-workflow-placeholder')), findsNothing);
  });
  testWidgets('单阶段追加灰色占位，注明可继续添加，占位不会变成真实阶段', (tester) async {
    final stages = [
      {'name': '技术面试'},
    ];
    await mountTimeline(tester, stages);
    expect(find.byKey(const Key('job-workflow-node-0')), findsOneWidget);
    expect(find.byKey(const Key('job-workflow-node-1')), findsNothing);
    expect(find.byKey(const Key('job-workflow-placeholder')), findsOneWidget);
    expect(find.text('可继续添加'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('可继续添加')).style!.color,
      AppColors.textMuted,
    );
    expect(stages, hasLength(1));
  });
  testWidgets('空流程不伪造阶段，加载与错误状态不出现占位流程', (tester) async {
    await mountTimeline(tester, []);
    expect(find.byKey(const Key('job-workflow-node-0')), findsNothing);
    expect(find.text('可继续添加'), findsOneWidget);
    await mountTimeline(tester, [], loading: true);
    expect(find.text('招聘流程加载中'), findsOneWidget);
    expect(find.byKey(const Key('job-workflow-placeholder')), findsNothing);
    var retries = 0;
    await mountTimeline(tester, [], error: '合成错误', reload: () => retries++);
    expect(find.text('招聘流程暂不可用'), findsOneWidget);
    expect(find.byKey(const Key('job-workflow-placeholder')), findsNothing);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
  testWidgets('长阶段名称、多阶段及320dp大字体不溢出且可横向查看', (tester) async {
    await mountTimeline(
      tester,
      [
        for (var i = 0; i < 8; i++) {'name': '第$i阶段的较长面试流程名称'},
      ],
      width: 320,
      scale: 1.5,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('job-workflow-timeline-scroll')),
      const Offset(-1800, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('第7阶段的较长面试流程名称').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
