/// 企业 APP - 笔试管理接口（ExamController）。
///
/// 对接后端 `backend/ruoyi-admin/.../enterprise/ExamController.java`：
/// - GET  /enterprise/exam/questions            题库列表（type/difficulty/skillTag/keyword/scope 筛选）
/// - DELETE /enterprise/exam/questions/{id}      删除企业题库题目
/// - GET  /enterprise/exam/papers                试卷列表（positionId 筛选）
/// - POST /enterprise/exam/papers                新建试卷（random 随机抽题 / manual 人工组卷）
/// - DELETE /enterprise/exam/papers/{id}         删除试卷
/// - POST /enterprise/exam/papers/draw-preview   随机抽题预览
///
/// 题库归属：companyId 为空表示平台题库，否则为本企业题库；scope=platform/enterprise
/// 可分别只看平台或企业，缺省时后端返回「平台题库 + 本企业题库」。
library;

import '../core/network/enterprise_api_client.dart';

/// 题库列表（TableDataInfo 解包 rows）。
/// [type] 1单选/2多选/3判断/4简答/5编程；[difficulty] 1简单/2中等/3困难；
/// [scope] platform 仅平台题库，enterprise 仅本企业题库，缺省返回两者。
Future<List<Map<String, dynamic>>> listExamQuestions({
  int? type,
  int? difficulty,
  String? skillTag,
  String? keyword,
  String? scope,
  int pageNum = 1,
  int pageSize = 50,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/exam/questions',
    query: {
      'type': type,
      'difficulty': difficulty,
      'skillTag': skillTag,
      'keyword': keyword,
      'scope': scope,
      'pageNum': pageNum,
      'pageSize': pageSize,
    },
  );
  return _rows(response);
}

/// 题目详情（含选项、标准答案与答案解析）。
Future<Map<String, dynamic>> getExamQuestion(int questionId) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/exam/questions/$questionId',
  );
  final data = response['data'];
  if (data is! Map) {
    throw const FormatException('题目详情格式不正确');
  }
  return Map<String, dynamic>.from(data);
}

Future<Map<String, dynamic>> aiAnalyzeExamQuestion({
  required int questionId,
  required int type,
  String? typeName,
  required String content,
  List<String>? options,
  required String answer,
  int? difficulty,
  String? skillTag,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/exam/questions/ai-analysis',
    body: {
      'questionId': questionId,
      'type': type,
      'typeName': typeName,
      'content': content,
      'options': options,
      'answer': answer,
      'difficulty': difficulty,
      'skillTag': skillTag,
    },
  );
  final data = response['data'];
  if (data is! Map) throw const FormatException('AI 解析响应格式不正确');
  return Map<String, dynamic>.from(data);
}

Future<void> fillExamQuestionAnalysis(int questionId, String analysis) async {
  await EnterpriseApiClient().put(
    '/enterprise/exam/questions/$questionId/analysis',
    body: {'analysis': analysis},
  );
}

/// 新增题目（归属当前企业题库）。选择题（type<=3）必须提供 [options]。
/// [options] 形如 [{label: A, text: ...}]；[answer] 单选/判断为选项标签（如 A），
/// 多选为逗号分隔标签（如 A,B），简答/编程为参考答案文本。
Future<void> saveExamQuestion({
  required int type,
  required String content,
  required String answer,
  required double score,
  int difficulty = 2,
  String? skillTag,
  String? analysis,
  List<Map<String, String>>? options,
}) async {
  await EnterpriseApiClient().post(
    '/enterprise/exam/questions',
    body: {
      'type': type,
      'content': content,
      'answer': answer,
      'score': score,
      'difficulty': difficulty,
      'skillTag': skillTag,
      'analysis': analysis,
      ...?options == null ? null : {'options': options},
    },
  );
}

/// 修改本企业题目。
Future<void> updateExamQuestion(
  int questionId, {
  required int type,
  required String content,
  required String answer,
  required double score,
  int difficulty = 2,
  String? skillTag,
  String? analysis,
  List<Map<String, String>>? options,
}) async {
  await EnterpriseApiClient().put(
    '/enterprise/exam/questions/$questionId',
    body: {
      'type': type,
      'content': content,
      'answer': answer,
      'score': score,
      'difficulty': difficulty,
      'skillTag': skillTag,
      'analysis': analysis,
      ...?options == null ? null : {'options': options},
    },
  );
}

/// 删除企业题库题目（平台题库为共享只读，后端会拦截）。
Future<void> deleteExamQuestion(int questionId) async {
  await EnterpriseApiClient().delete('/enterprise/exam/questions/$questionId');
}

/// 试卷列表（AjaxResult 解包 data）。可按岗位 [positionId] 筛选。
Future<List<Map<String, dynamic>>> listExamPapers({int? positionId}) async {
  final query = <String, Object?>{};
  if (positionId != null) query['positionId'] = positionId;
  final response = await EnterpriseApiClient().get(
    '/enterprise/exam/papers',
    query: query,
    timeout: const Duration(seconds: 45),
  );
  final data = response['data'];
  if (data is List) {
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  return const <Map<String, dynamic>>[];
}

Future<int?> createExamSchedule({
  required int positionId,
  required int paperId,
  required int stageId,
  required String startAt,
  required String endAt,
  required num passThreshold,
  int? passThresholdPercent,
  int maxAttempts = 1,
}) async {
  final body = <String, Object?>{
    'positionId': positionId,
    'paperId': paperId,
    'stageId': stageId,
    'startAt': startAt,
    'endAt': endAt,
    'maxAttempts': maxAttempts,
    'passThreshold': passThreshold,
  };
  if (passThresholdPercent != null) {
    body['passThresholdPercent'] = passThresholdPercent;
  }
  final response = await EnterpriseApiClient().post(
    '/enterprise/exam/schedules',
    body: body,
  );
  final data = response['data'];
  if (data is int) return data;
  return int.tryParse('$data');
}

Future<List<Map<String, dynamic>>> listExamSchedules({
  required int positionId,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/exam/schedules',
    query: {'positionId': positionId, 'pageNum': 1, 'pageSize': 50},
  );
  final rows = response['rows'];
  if (rows is! List) return const <Map<String, dynamic>>[];
  return rows
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

Future<Map<String, dynamic>> assignExamCandidates(
  int scheduleId, {
  required List<int> candidateIds,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/exam/schedules/$scheduleId/candidates',
    body: {'candidateIds': candidateIds, 'source': 'manual'},
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

Future<Map<String, dynamic>> sendExamNotify(
  int scheduleId, {
  required List<int> candidateIds,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/exam/schedules/$scheduleId/notify',
    body: {
      'candidateIds': candidateIds,
      'channels': const ['inapp', 'email'],
    },
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// 试卷详情（含题目与规则）。
Future<Map<String, dynamic>> getExamPaper(int paperId) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/exam/papers/$paperId',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// 新建试卷。mode=random 时传 [rule]（[{type,difficulty,skillTag,count,score}]），
/// 后端约定包装为 rule:{rules:[...]}；mode=manual 时传 [questions]（[{questionId,score}]）。
/// 返回新试卷 paperId。
Future<int?> createExamPaper({
  required String name,
  required int positionId,
  required int durationMin,
  required String mode,
  List<Map<String, dynamic>>? rule,
  List<Map<String, dynamic>>? questions,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/exam/papers',
    body: {
      'name': name,
      'positionId': positionId,
      'durationMin': durationMin,
      'mode': mode,
      ...?rule == null
          ? null
          : {
              'rule': {'rules': rule},
            },
      ...?questions == null ? null : {'questions': questions},
    },
  );
  final data = response['data'];
  if (data is int) return data;
  return int.tryParse('$data');
}

/// 随机抽题预览：按 [rule] 返回会被抽中的题目列表。
/// 后端 drawPreview 的 body 直接是 {rules:[...]}。
Future<List<Map<String, dynamic>>> previewExamDraw(
  List<Map<String, dynamic>> rule,
) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/exam/papers/draw-preview',
    body: {'rules': rule},
  );
  final data = response['data'];
  if (data is List) {
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  return const <Map<String, dynamic>>[];
}

/// 删除试卷。
Future<void> deleteExamPaper(int paperId) async {
  await EnterpriseApiClient().delete('/enterprise/exam/papers/$paperId');
}

/// 关联岗位列表（复用岗位管理接口，TableDataInfo 解包 rows）。
Future<List<Map<String, dynamic>>> listExamJobs() async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/jobs/list',
    query: {'pageNum': 1, 'pageSize': 100},
  );
  return _rows(response);
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> response) {
  return (response['rows'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// 监控监考：进行中的考试列表（AjaxResult 解包 data）。
/// 保留自旧实现，exam_proctor_page.dart 依赖。
Future<List<Map<String, dynamic>>> listOngoingExams() async {
  final response = await EnterpriseApiClient().get('/enterprise/exam/ongoing');
  final data = response['data'];
  if (data is List) {
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  return const <Map<String, dynamic>>[];
}
