import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/jobs/presentation/application_resume_picker.dart';
import 'package:intelligent_interviewer/features/resume/data/resume_api.dart';
import 'package:intelligent_interviewer/features/resume/domain/app_resume.dart';
import 'package:intelligent_interviewer/models/job.dart';

class _Resumes extends ResumeApi {
  _Resumes(super.client);
  List<AppResume> items = [];
  bool fail = false;
  @override
  Future<List<AppResume>> list(String token) async {
    if (fail) throw const ApiException('简历加载失败');
    return items;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Resumes api,
    ValueChanged<int?> result,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result(
                await chooseApplicationResume(
                  context,
                  token: 'synthetic',
                  job: Job.fromJson({
                    'positionId': 91,
                    'title': '合成岗位',
                    'company': '合成企业',
                  }),
                  api: api,
                ),
              ),
              child: const Text('投递'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('投递'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selecting a nondefault resume returns its id and leaves default unchanged',
    (tester) async {
      final client = ApiClient();
      addTearDown(client.close);
      final api = _Resumes(client)
        ..items = [
          AppResume(resumeId: 51, resumeName: '默认版本', isDefault: true),
          AppResume(resumeId: 52, resumeName: '后端版本'),
        ];
      int? result;
      await open(tester, api, (id) => result = id);
      await tester.tap(find.text('后端版本'));
      await tester.tap(find.text('确认投递'));
      await tester.pumpAndSettle();
      expect(result, 52);
      expect(api.items.first.isDefault, isTrue);
    },
  );

  testWidgets('empty resumes cannot confirm and cancelling submits nothing', (
    tester,
  ) async {
    final client = ApiClient();
    addTearDown(client.close);
    final api = _Resumes(client);
    int? result = -1;
    await open(tester, api, (id) => result = id);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认投递'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('暂不投递'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('failed resume load supports retry before confirmation', (
    tester,
  ) async {
    final client = ApiClient();
    addTearDown(client.close);
    final api = _Resumes(client)..fail = true;
    await open(tester, api, (_) {});
    expect(find.text('简历加载失败'), findsOneWidget);
    api
      ..fail = false
      ..items = [AppResume(resumeId: 52, resumeName: '后端版本')];
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('后端版本'), findsOneWidget);
  });
}
