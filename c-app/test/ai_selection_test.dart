import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/ai/presentation/ai_chat_screen.dart';
import 'package:intelligent_interviewer/features/ai/presentation/ai_chat_controller.dart';
import 'package:intelligent_interviewer/features/applications/data/application_api.dart';
import 'package:intelligent_interviewer/features/applications/domain/job_application.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/resume/data/resume_api.dart';
import 'package:intelligent_interviewer/features/resume/domain/app_resume.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

import 'ai_agent_test.dart' show FakeAiApi;

class SelectionResumes extends ResumeApi {
  SelectionResumes() : this._(ApiClient());
  SelectionResumes._(this.client) : super(client);
  final ApiClient client;
  int reads = 0;
  bool empty = false;
  @override
  Future<List<AppResume>> list(String token) async {
    reads++;
    return empty ? [] : [AppResume(resumeId: 5, resumeName: '模拟通用简历')];
  }
}

class SelectionApplications extends ApplicationApi {
  SelectionApplications() : super(ApiClient());
  final pages = <int>[];
  bool fail = false;
  bool empty = false;
  bool missingResume = false;
  @override
  Future<ApplicationPage> list(
    String token, {
    int page = 1,
    int size = 10,
    String? status,
  }) async {
    pages.add(page);
    if (fail) throw const ApiException('模拟岗位列表失败');
    return ApplicationPage(
      items: empty ? [] : [_item(page)],
      page: page,
      size: size,
      total: empty ? 0 : 2,
      hasNext: !empty && page == 1,
    );
  }

  JobApplication _item(int id) => JobApplication(
    id: id,
    jobId: 90 + id,
    resumeId: missingResume ? null : 6 + id,
    jobTitle: '模拟岗位 $id',
    companyName: '模拟企业',
    resumeName: '投递简历 $id',
    status: 'submitted',
    statusText: '已投递',
  );

  @override
  Future<JobApplication> detail(String token, int applicationId) async =>
      _item(applicationId);
}

Future<void> mountChat(
  WidgetTester tester,
  FakeAiApi api,
  SelectionResumes resumes,
  SelectionApplications applications,
) async {
  tester.view.physicalSize = const Size(900, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    api.client.close();
    resumes.client.close();
    applications.client.close();
    await api.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AiChatScreen(
        session: const AuthSession(
          token: 'synthetic',
          userId: 17,
          userName: 'test',
          nickName: 'test',
        ),
        api: api,
        resumeApi: resumes,
        applicationApi: applications,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    '岗位推荐': 'job_recommendation',
    '简历分析': 'resume_analysis',
  }.entries) {
    testWidgets(
      '${entry.key} requires a resume and sends its structured action',
      (tester) async {
        final api = FakeAiApi();
        final resumes = SelectionResumes();
        final applications = SelectionApplications();
        await mountChat(tester, api, resumes, applications);
        final chips = tester
            .widgetList<ActionChip>(find.byType(ActionChip))
            .map((chip) => (chip.label as Text).data)
            .toList();
        expect(chips.take(2), ['选择简历', '选择岗位']);
        await tester.tap(find.widgetWithText(ActionChip, entry.key));
        await tester.pumpAndSettle();
        expect(find.text('选择本次使用的简历'), findsOneWidget);
        expect(api.creates, 0);
        await tester.tap(find.text('模拟通用简历'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('取消简历上下文'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('发送'));
        await tester.pumpAndSettle();
        expect(find.text('选择本次使用的简历'), findsOneWidget);
        expect(api.requests, isEmpty);
        await tester.tap(find.text('模拟通用简历'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(api.resumeIds, [5]);
        expect(api.actions, [entry.value]);
        expect(api.applicationIds, [null]);
        expect(applications.pages, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'interview selects a paginated application and replaces an unrelated resume',
    (tester) async {
      final api = FakeAiApi();
      final resumes = SelectionResumes();
      final applications = SelectionApplications();
      await mountChat(tester, api, resumes, applications);
      await tester.tap(find.text('选择简历'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟通用简历'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('面试准备'));
      await tester.pumpAndSettle();
      expect(find.text('选择已投递的岗位'), findsOneWidget);
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(applications.pages, [1, 2]);
      await tester.tap(find.text('模拟岗位 2'));
      await tester.pumpAndSettle();
      expect(find.text('投递简历 2'), findsOneWidget);
      expect(find.text('模拟通用简历'), findsNothing);
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      expect(api.resumeIds, [8]);
      expect(api.applicationIds, [2]);
      expect(api.actions, ['interview_preparation']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cancelled or unavailable selection sends nothing and preserves draft',
    (tester) async {
      final api = FakeAiApi();
      final resumes = SelectionResumes()..empty = true;
      final applications = SelectionApplications()..fail = true;
      await mountChat(tester, api, resumes, applications);
      await tester.enterText(find.byType(TextField), '保留模拟草稿');
      await tester.tap(find.text('简历分析'));
      await tester.pumpAndSettle();
      expect(find.text('暂无简历，可先自由聊天，或到简历页创建简历'), findsOneWidget);
      await tester.tap(find.text('面试准备'));
      await tester.pumpAndSettle();
      expect(find.text('模拟岗位列表失败'), findsOneWidget);
      applications.fail = false;
      applications.missingResume = true;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟岗位 1'));
      await tester.pumpAndSettle();
      expect(find.text('该投递缺少关联简历，请选择其他岗位'), findsOneWidget);
      Navigator.of(tester.element(find.text('选择已投递的岗位'))).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '保留模拟草稿',
      );
      expect(api.creates, 0);
      expect(api.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('regeneration restores the original application and feature', () async {
    final api = FakeAiApi()..failed = true;
    final controller = AiChatController(api, 'synthetic', 'session');
    await controller.load();
    api.pendingRun = Completer<Map<String, dynamic>>();
    final retry = controller.retry();
    api.pendingRun!.complete({
      'status': 'FAILED',
      'resumeId': 8,
      'applicationId': 2,
      'action': 'interview_preparation',
    });
    expect(await retry, isTrue);
    expect(api.resumeIds, [8]);
    expect(api.applicationIds, [2]);
    expect(api.actions, ['interview_preparation']);
    controller.dispose();
    api.client.close();
    await api.stream.close();
  });
}
