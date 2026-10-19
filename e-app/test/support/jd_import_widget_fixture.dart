import 'package:enterprise_recruiter/features/enterprise/jobs/data/jd_document_picker.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_publish_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'jd_import_fixture.dart';

Future<void> openJdPublishPage(
  WidgetTester tester, {
  Future<JdPickedDocument?> Function()? pick,
  JdDocumentParser? parse,
  Future<Map<String, dynamic>> Function(Map<String, Object?>)? submit,
  Size? size = const Size(430, 1000),
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('jd-test-open-page'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => JobPublishPage(
                    loadOptions: () async => {
                      'company': {'id': 2, 'name': '合成测试企业', 'city': '上海'},
                      'departments': ['测试研发部'],
                    },
                    pickDocument: pick ?? () async => jdDocument(),
                    parseDocument:
                        parse ??
                        (document, {cancelToken, onSendProgress}) async =>
                            jdDraft(),
                    submitJob: submit ?? (payload) async => {'posId': 99001},
                  ),
                ),
              ),
              child: const Text('打开合成岗位发布页'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('jd-test-open-page')));
  await tester.pumpAndSettle();
}

Future<void> tapJdKey(
  WidgetTester tester,
  String key, {
  bool settle = true,
}) async {
  final target = find.byKey(Key(key));
  // The import card precedes the form; scroll upward to rebuild lazy children.
  await tester.scrollUntilVisible(
    target,
    -300,
    scrollable: find
        .descendant(
          of: find.byType(JobPublishPage),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 30,
  );
  expect(target, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Future<void> enterJdText(
  WidgetTester tester,
  String key,
  String value, {
  bool settle = true,
}) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.enterText(field, value);
  tester.testTextInput.hide();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

String jdFieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

Future<void> applyJdReview(WidgetTester tester) async {
  await tapJdKey(tester, 'jd-import-apply');
  if (find
      .byKey(const Key('jd-import-confirm-overwrite'))
      .evaluate()
      .isNotEmpty) {
    await tapJdKey(tester, 'jd-import-confirm-overwrite');
  }
}
