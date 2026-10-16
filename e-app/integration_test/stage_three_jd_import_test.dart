import 'dart:async';

import 'package:dio/dio.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/jd_document_picker.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/models/jd_import_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/jd_import_fixture.dart';
import '../test/support/jd_import_widget_fixture.dart';

/// Device-controlled synthetic flow. Native picking and real HTTP are accepted
/// separately after manual login; this script never writes a real job.
Future<void> deviceEdit(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 350));
  tester.widget<TextFormField>(finder).controller!.text = value;
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pixel_10a：PDF/DOCX 草稿核对、人工修改、内存发布各一次', (tester) async {
    for (final filename in ['pixel-synthetic.pdf', 'pixel-synthetic.docx']) {
      var parsed = 0;
      var published = 0;
      Map<String, Object?>? body;
      await openJdPublishPage(
        tester,
        size: null,
        pick: () async => jdDocument(filename),
        parse: (document, {cancelToken, onSendProgress}) async {
          expect(document.name, filename);
          parsed++;
          onSendProgress?.call(document.size, document.size);
          return jdDraft();
        },
        submit: (payload) async {
          published++;
          body = payload;
          return {'posId': 99001};
        },
      );
      await tapJdKey(tester, 'jd-document-import-select');
      expect(parsed, 1);
      expect(published, 0);
      expect(find.text('解析完成，请核对'), findsWidgets);
      await tapJdKey(tester, 'jd-import-append-summary');
      await tapJdKey(tester, 'jd-import-append-soft-requirements');
      await applyJdReview(tester);
      await deviceEdit(tester, 'job-title', 'Pixel受控核对-$filename');
      await tapJdKey(tester, 'job-publish-action');
      expect(published, 0);
      await tapJdKey(tester, 'job-publish-action');
      expect(published, 1);
      expect(body!['title'], 'Pixel受控核对-$filename');
      expect((body!['skills'] as List).last, {
        'name': 'Flutter',
        'required': null,
      });
      expect(body!['responsibilities'], contains('维护合成测试应用'));
      expect(body!['requirements'], contains('团队协作'));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Pixel_10a：取消、超限和空文件均不请求解析', (tester) async {
    for (final kind in ['cancel', 'oversize', 'empty']) {
      var parsed = 0;
      final picker = JdDocumentPicker(
        pickFile: () async {
          if (kind == 'cancel') {
            return null;
          }
          return SyntheticJdPlatformFile(
            reportedSize: kind == 'empty' ? 0 : JdPickedDocument.maxBytes + 1,
          );
        },
      );
      await openJdPublishPage(
        tester,
        size: null,
        pick: picker.pick,
        parse: (document, {cancelToken, onSendProgress}) async {
          parsed++;
          return jdDraft();
        },
      );
      await deviceEdit(tester, 'job-title', '保留受控输入');
      await tapJdKey(tester, 'jd-document-import-select');
      expect(parsed, 0);
      expect(jdFieldText(tester, 'job-title'), '保留受控输入');
      expect(
        find.byKey(const Key('jd-document-import-error')),
        kind == 'cancel' ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('离开'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Pixel_10a：解析中编辑、覆盖取消、防重复及离开忽略迟到结果', (tester) async {
    final pending = Completer<JdImportDraft>();
    CancelToken? token;
    ProgressCallback? progress;
    var parsed = 0;
    await openJdPublishPage(
      tester,
      size: null,
      parse: (document, {cancelToken, onSendProgress}) {
        parsed++;
        token = cancelToken;
        progress = onSendProgress;
        return pending.future;
      },
    );
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    progress!(5, 10);
    await deviceEdit(tester, 'job-title', '受控解析期间编辑');
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    expect(parsed, 1);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('继续填写'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(token!.isCancelled, isFalse);
    progress!(10, 10);
    pending.complete(jdDraft());
    await tester.pumpAndSettle();
    await tapJdKey(tester, 'jd-import-apply');
    expect(find.text('当前：受控解析期间编辑'), findsOneWidget);
    await tapJdKey(tester, 'jd-import-keep-current');
    expect(jdFieldText(tester, 'job-title'), '受控解析期间编辑');
    await tapJdKey(tester, 'jd-import-review-close');

    final late = Completer<JdImportDraft>();
    await openJdPublishPage(
      tester,
      size: null,
      parse: (document, {cancelToken, onSendProgress}) {
        token = cancelToken;
        progress = onSendProgress;
        return late.future;
      },
    );
    await tapJdKey(tester, 'jd-document-import-select', settle: false);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('离开'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(token!.isCancelled, isTrue);
    progress!(10, 10);
    late.complete(jdDraft());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jd-test-open-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
