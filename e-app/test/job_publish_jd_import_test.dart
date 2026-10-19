import 'dart:async';

import 'package:dio/dio.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/jd_document_picker.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/models/jd_import_draft.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/jd_import_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_import_fixture.dart';
import 'support/jd_import_widget_fixture.dart';

void main() {
  testWidgets('取消文件选择不报错、不解析、不发布', (tester) async {
    var parsed = 0;
    var published = 0;
    await openJdPublishPage(
      tester,
      pick: () async => null,
      parse: (document, {cancelToken, onSendProgress}) async {
        parsed++;
        return jdDraft();
      },
      submit: (payload) async {
        published++;
        return {'posId': 99001};
      },
    );
    await tapJdKey(tester, 'jd-document-import-select');
    expect(parsed, 0);
    expect(published, 0);
    expect(find.byKey(const Key('jd-document-import-error')), findsNothing);
    expect(find.byType(JdImportReviewSheet), findsNothing);
  });

  testWidgets('解析仅展示待核对草稿，不自动回填或调用 createJob', (tester) async {
    var published = 0;
    await openJdPublishPage(
      tester,
      submit: (payload) async {
        published++;
        return {'posId': 99001};
      },
    );
    await tapJdKey(tester, 'jd-document-import-select');
    expect(find.byType(JdImportReviewSheet), findsOneWidget);
    expect(jdFieldText(tester, 'job-title'), isEmpty);
    expect(published, 0);
    expect(
      tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .where((button) => button.onPressed != null),
      hasLength(1),
    );
    await tapJdKey(tester, 'jd-import-review-close');
    expect(jdFieldText(tester, 'job-title'), isEmpty);
    expect(find.byKey(const Key('jd-document-import-review')), findsOneWidget);
  });

  testWidgets('应用后编辑并预览，只有确认发布才调用一次 createJob', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    var published = 0;
    Map<String, Object?>? body;
    await openJdPublishPage(
      tester,
      submit: (payload) {
        published++;
        body = payload;
        return pending.future;
      },
    );
    await tapJdKey(tester, 'jd-document-import-select');
    await applyJdReview(tester);
    expect(published, 0);
    expect(jdFieldText(tester, 'job-title'), jdDraftJson()['title']);
    expect(jdFieldText(tester, 'job-salary-min'), '15000.5');
    await enterJdText(tester, 'job-title', '人工核对后的合成岗位');
    await tapJdKey(tester, 'job-publish-action');
    expect(published, 0);
    expect(find.text('人工核对后的合成岗位'), findsOneWidget);
    await tapJdKey(tester, 'job-publish-action', settle: false);
    await tapJdKey(tester, 'job-publish-action', settle: false);
    expect(published, 1);
    expect(body!['title'], '人工核对后的合成岗位');
    expect(body!['responsibilities'], ['开发移动端功能', '编写自动化测试']);
    expect((body!['skills'] as List).last, {
      'name': 'Flutter',
      'required': null,
    });
    expect(body!.containsKey('summary'), isFalse);
    expect(body!.containsKey('softRequirements'), isFalse);
    pending.complete({'posId': 99001});
    await tester.pumpAndSettle();
    expect(find.text('打开合成岗位发布页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('覆盖展示前后差异，取消确认保留已有内容和核对草稿', (tester) async {
    await openJdPublishPage(tester);
    await enterJdText(tester, 'job-title', '用户已有岗位');
    await tapJdKey(tester, 'jd-document-import-select');
    await tapJdKey(tester, 'jd-import-apply');
    expect(find.text('确认覆盖已有内容？'), findsOneWidget);
    expect(find.text('当前：用户已有岗位'), findsOneWidget);
    expect(find.text('导入后：合成移动端工程师'), findsOneWidget);
    await tapJdKey(tester, 'jd-import-keep-current');
    expect(jdFieldText(tester, 'job-title'), '用户已有岗位');
    expect(find.byType(JdImportReviewSheet), findsOneWidget);
    await tapJdKey(tester, 'jd-import-review-close');
    expect(jdFieldText(tester, 'job-title'), '用户已有岗位');
  });

  testWidgets('解析期间仍可编辑，应用时比较最新输入且重复导入被禁用', (tester) async {
    final pending = Completer<JdImportDraft>();
    ProgressCallback? progress;
    var parsed = 0;
    await openJdPublishPage(
      tester,
      parse: (document, {cancelToken, onSendProgress}) {
        parsed++;
        progress = onSendProgress;
        return pending.future;
      },
    );
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    progress!(2, 10);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('jd-document-import-progress')),
          )
          .value,
      0.2,
    );
    await enterJdText(tester, 'job-title', '解析期间的新输入', settle: false);
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    expect(parsed, 1);
    progress!(10, 10);
    await tester.pump();
    expect(find.text('正在解析'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('jd-document-import-progress')),
          )
          .value,
      isNull,
    );
    pending.complete(jdDraft());
    await tester.pumpAndSettle();
    await tapJdKey(tester, 'jd-import-apply');
    expect(find.text('当前：解析期间的新输入'), findsOneWidget);
    await tapJdKey(tester, 'jd-import-keep-current');
    expect(jdFieldText(tester, 'job-title'), '解析期间的新输入');
    await tapJdKey(tester, 'jd-import-review-close');
  });

  testWidgets('解析失败仅显示卡片错误，不清空原表单', (tester) async {
    await openJdPublishPage(
      tester,
      parse: (document, {cancelToken, onSendProgress}) async {
        throw const ApiException('合成解析失败');
      },
    );
    await enterJdText(tester, 'job-title', '保留手工输入');
    await tapJdKey(tester, 'jd-document-import-select');
    expect(find.text('合成解析失败'), findsOneWidget);
    expect(jdFieldText(tester, 'job-title'), '保留手工输入');
    expect(find.byType(JdImportReviewSheet), findsNothing);
    expect(find.byKey(const Key('jd-document-import-retry')), findsOneWidget);
  });

  testWidgets('重新选择取消后保留已应用表单和上次草稿', (tester) async {
    var picks = 0;
    await openJdPublishPage(
      tester,
      pick: () async => ++picks == 1 ? jdDocument() : null,
    );
    await tapJdKey(tester, 'jd-document-import-select');
    await applyJdReview(tester);
    await tapJdKey(tester, 'jd-document-import-select');
    expect(jdFieldText(tester, 'job-title'), jdDraftJson()['title']);
    expect(find.byKey(const Key('jd-document-import-review')), findsOneWidget);
    expect(find.byKey(const Key('jd-document-import-error')), findsNothing);
  });

  testWidgets('离开需确认，取消请求并忽略随后返回的草稿和进度', (tester) async {
    final pending = Completer<JdImportDraft>();
    CancelToken? token;
    ProgressCallback? progress;
    await openJdPublishPage(
      tester,
      parse: (document, {cancelToken, onSendProgress}) {
        token = cancelToken;
        progress = onSendProgress;
        return pending.future;
      },
    );
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('离开岗位发布？'), findsOneWidget);
    await tester.tap(find.text('离开'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(token!.isCancelled, isTrue);
    progress!(10, 10);
    pending.complete(jdDraft());
    await tester.pumpAndSettle();
    expect(find.text('打开合成岗位发布页'), findsOneWidget);
    expect(find.byType(JdImportReviewSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择器未返回期间重复点击只打开一次', (tester) async {
    final selection = Completer<JdPickedDocument?>();
    var picks = 0;
    await openJdPublishPage(
      tester,
      pick: () {
        picks++;
        return selection.future;
      },
    );
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    expect(picks, 1);
    selection.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jd-document-import-error')), findsNothing);
  });

  testWidgets('warnings 原样展示，主动选择摘要和软性要求后追加正文', (tester) async {
    await openJdPublishPage(tester);
    await tapJdKey(tester, 'jd-document-import-select');
    final warning = tester.widget<SelectableText>(
      find.byKey(const ValueKey('jd-import-warning-0')),
    );
    expect(warning.data, (jdDraftJson()['warnings'] as List).single);
    expect(find.textContaining('摘要和软性要求会追加到正文，不会单独保存'), findsOneWidget);
    await tapJdKey(tester, 'jd-import-append-summary');
    await tapJdKey(tester, 'jd-import-append-soft-requirements');
    await applyJdReview(tester);
    expect(
      jdFieldText(tester, 'job-responsibilities'),
      '开发移动端功能\n编写自动化测试\n维护合成测试应用',
    );
    expect(jdFieldText(tester, 'job-requirements'), '熟悉 Dart\n团队协作');
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('导入卡片和可滚动核对面板在 $size 无溢出', (tester) async {
      await openJdPublishPage(tester, size: size);
      await tapJdKey(tester, 'jd-document-import-select');
      await tapJdKey(tester, 'jd-import-append-soft-requirements');
      await applyJdReview(tester);
      await tester.ensureVisible(find.byKey(const Key('job-add-skill')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
