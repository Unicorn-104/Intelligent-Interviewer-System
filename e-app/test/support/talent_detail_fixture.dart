import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';

import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_detail_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const talentTestJob = TalentJobContext(
  positionId: 7,
  title: '合成测试岗位',
  currentStage: '初筛',
);
Map<String, dynamic> talentResumeJson() => {
  'name': '合成候选人',
  'integrity': 82,
  'missingFields': ['项目结束时间'],
  'educationList': [
    {
      'school': '合成大学',
      'degree': 3,
      'major': '计算机',
      'startDate': '2020-09',
      'endDate': '2024-06',
    },
  ],
  'workList': [
    {'company': '合成企业', 'position': '工程师', 'summary': '合成工作经历'},
  ],
  'projectList': [
    {'name': '合成项目', 'role': '开发', 'techStack': 'Dart', 'summary': '合成项目经历'},
  ],
  'skills': [
    {'name': 'Dart', 'level': 3},
  ],
};

class TalentFakeSource extends TalentDetailDataSource {
  bool detailFails = false,
      resumeFails = false,
      matchFails = false,
      reportFails = false,
      peopleFail = false,
      availabilityFails = false;
  Map<String, dynamic> detail = {
    'talentId': 11,
    'name': '合成候选人',
    'status': 2,
    'matchedScore': 88,
    'currentRound': 1,
  };
  Map<String, dynamic> resume = talentResumeJson();
  TalentMatchData match = const TalentMatchData(
    requiredSkills: ['Dart'],
    currentStage: '技术面试',
    result: {
      'source': 'llm',
      'positionId': 7,
      'positionTitle': '合成测试岗位',
      'recommendation': '合成推荐理由：具备Dart项目经验，与岗位技能要求匹配，科研和奖项待补充。',
      'totalScore': 91,
      'skillMatch': 75,
      'projectMatch': null,
      'educationMatch': null,
      'industryMatch': null,
    },
  );
  Map<String, dynamic>? report = {
    'source': 'llm',
    'positionId': 7,
    'positionTitle': '合成测试岗位',
    'totalScore': 91,
    'skillMatch': 75,
    'recommendation': '合成推荐理由：具备Dart项目经验，与岗位技能要求匹配，科研和奖项待补充。',
    'matchPoints': ['合成匹配点'],
    'content': '合成报告正文',
    'status': 0,
    'sentAt': null,
  };
  Map<String, dynamic>? greeting = {'content': '已有合成招呼语', 'status': 0};
  List<Map<String, dynamic>> people = [
    {'userId': 19, 'userName': '合成面试官', 'department': '技术部'},
  ];
  List<Map<String, dynamic>> jobs = [
    {'posId': 7, 'title': '合成测试岗位'},
  ];
  List<Map<String, dynamic>> slots = [];
  Map<String, dynamic> workflow = {
    'template': {'name': '合成流程'},
    'stages': <Map<String, dynamic>>[],
  };
  List<List<Map<String, dynamic>>> interviewPages = [[]];
  Map<String, dynamic> inviteResult = {'appointmentId': 101};
  Completer<Map<String, dynamic>>? resumePending, invitePending;
  Completer<List<Map<String, dynamic>>>? availabilityPending;
  int detailCalls = 0,
      resumeCalls = 0,
      matchCalls = 0,
      reportCalls = 0,
      greetingCalls = 0,
      peopleCalls = 0;
  final invites = <Map<String, Object?>>[];
  final availabilityQueries = <Map<String, Object?>>[];
  final interviewQueries = <Map<String, Object?>>[];
  @override
  Future<Map<String, dynamic>> loadDetail(int id) async {
    detailCalls++;
    if (detailFails) {
      throw StateError('detail');
    }
    return detail;
  }

  @override
  Future<Map<String, dynamic>> loadResume(int id) async {
    resumeCalls++;
    if (resumeFails) {
      throw StateError('resume');
    }
    if (resumePending != null) {
      return resumePending!.future;
    }
    return resume;
  }

  @override
  Future<TalentMatchData> loadMatch(int id, TalentJobContext context) async {
    matchCalls++;
    if (matchFails) {
      throw StateError('match');
    }
    return match;
  }

  @override
  Future<Map<String, dynamic>?> loadReport(int id) async {
    reportCalls++;
    if (reportFails) {
      throw StateError('report');
    }
    return report;
  }

  @override
  Future<Map<String, dynamic>?> loadGreeting(int id) async {
    greetingCalls++;
    return greeting;
  }

  @override
  Future<List<Map<String, dynamic>>> loadInterviewers() async {
    peopleCalls++;
    if (peopleFail) {
      throw StateError('people');
    }
    return people;
  }

  @override
  Future<List<Map<String, dynamic>>> loadJobs({int pageNum = 1}) async =>
      pageNum == 1 ? jobs : [];
  @override
  Future<Map<String, dynamic>> loadWorkflow(int positionId) async {
    if (workflowFails) throw StateError('workflow');
    return workflow;
  }

  @override
  Future<List<Map<String, dynamic>>> loadAvailability(
    int id, {
    String? to,
  }) async {
    availabilityQueries.add({'id': id, 'to': to});
    if (availabilityFails) {
      throw StateError('availability');
    }
    if (availabilityPending != null) {
      return availabilityPending!.future;
    }
    return slots;
  }

  @override
  Future<Map<String, dynamic>> invite({
    required int candidateId,
    required int positionId,
    int? stageId,
    required int interviewerId,
    required String startTime,
    required int durationMin,
  }) async {
    invites.add({
      'candidateId': candidateId,
      'positionId': positionId,
      ...?stageId == null ? null : {'stageId': stageId},
      'interviewerId': interviewerId,
      'startTime': startTime,
      'durationMin': durationMin,
    });
    if (invitePending != null) {
      return invitePending!.future;
    }
    return inviteResult;
  }

  List<Map<String, dynamic>> plan = [];
  bool planFails = false, workflowFails = false, rescheduleFails = false;
  final stageInvites = <List<Map<String, Object?>>>[];
  final reschedules = <Map<String, Object?>>[];
  @override
  Future<Map<String, dynamic>> loadWorkflowSession(int sessionId) async => {};

  @override
  Future<List<Map<String, dynamic>>> loadCandidatePlan(
    int candidateId,
    int positionId,
  ) async {
    if (planFails) throw StateError('plan');
    return plan;
  }

  @override
  Future<List<Map<String, dynamic>>> inviteStages({
    required int candidateId,
    required int positionId,
    required List<Map<String, Object?>> stages,
  }) async {
    stageInvites.add(stages);
    final results = [
      for (final (index, stage) in stages.indexed)
        <String, dynamic>{
          ...stage,
          'candidateId': candidateId,
          'positionId': positionId,
          'appointmentId': 101 + index,
          'status': 0,
          'endTime': TalentUtc8.serverTime(
            TalentUtc8.parseServer(stage['startTime'])!
                .add(Duration(minutes: stage['durationMin'] as int)),
          ),
        },
    ];
    plan.addAll(results);
    return results;
  }

  @override
  Future<Map<String, dynamic>> reschedule(
    int appointmentId, {
    required String newStartTime,
    int? durationMin,
    int? interviewerId,
  }) async {
    if (rescheduleFails) throw const ApiException('时间冲突');
    reschedules.add({
      'appointmentId': appointmentId,
      'newStartTime': newStartTime,
      'durationMin': durationMin,
      'interviewerId': interviewerId,
    });
    final old = plan.where((row) => row['appointmentId'] == appointmentId);
    return {
      'appointmentId': appointmentId,
      'startTime': newStartTime,
      'endTime': TalentUtc8.serverTime(
        TalentUtc8.parseServer(newStartTime)!
            .add(Duration(minutes: durationMin ?? 45)),
      ),
      'status': 0,
      'interviewerId':
          interviewerId ?? (old.isEmpty ? 19 : old.first['interviewerId']),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> loadInterviews({
    required int pageNum,
    int pageSize = 50,
    String? from,
    String? to,
  }) async {
    interviewQueries.add({
      'pageNum': pageNum,
      'pageSize': pageSize,
      'from': from,
      'to': to,
    });
    return pageNum <= interviewPages.length ? interviewPages[pageNum - 1] : [];
  }
}

Future<void> pumpTalentWidget(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(480, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollTalentTo(
  WidgetTester tester,
  Finder target, {
  double delta = 350,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 30,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> fillTalentInvite(
  WidgetTester tester, {
  int hour = 9,
  int minute = 30,
  bool save = true,
}) async {
  if (find.byKey(const Key('invite-interviewer')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('invite-stage-edit-0')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('invite-interviewer')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('合成面试官 · 技术部').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('invite-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('2').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('invite-time')));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), '$minute');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  if (save) {
    await tester.tap(find.byKey(const Key('invite-stage-save')));
    await tester.pumpAndSettle();
  }
}
