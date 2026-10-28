/// 企业 APP - 模块四（面试入口与监控）+ 模块五（面试执行）：会议会话接口。
///
/// 依据《业务功能分析》UC-10（面试入场鉴权与设备检测）、
/// UC-12（多模式 AI 面试执行）、UC-14（HR 协同面试与实时提词）。
///
/// P7 联调状态：已对接真实后端接口（ConferenceController，/system/conference）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
library;

import '../../core/network/enterprise_api_client.dart';

EnterpriseApiClient get _client => EnterpriseApiClient();

/// UC-10/UC-12：获取当前登录人关联的面试会话（入场入口）。
/// 已对接：GET /system/conference/session/current
Future<Map<String, dynamic>> getCurrentSession() async {
  final response = await _client.get('/system/conference/session/current');
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-10：面试会话上下文（岗位名称/面试官/时长/模式等元数据）。
/// 已对接：GET /system/conference/session/{sessionId}
Future<Map<String, dynamic>> getSessionContext(int sessionId) async {
  final response = await _client.get('/system/conference/session/$sessionId');
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-10：换取 LiveKit 入会令牌（与 PC 端 /system/conference 视频会议一致）。
/// 已对接：GET /system/conference/livekit-token/{sessionId}
///
/// 返回 { url, token, room, identity }，客户端凭 url/token 直连 LiveKit
/// 信令与媒体服务器；identity 形如 u{userId}，用于把远端参会者映射回业务用户。
Future<Map<String, dynamic>> getLiveKitToken(int sessionId) async {
  final response = await _client.get(
    '/system/conference/livekit-token/$sessionId',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// 面试官加入本次面试（登记 join_status，主面试官进入时自动登记）。
/// 已对接：POST /system/conference/session/{sessionId}/interviewer/join
Future<Map<String, dynamic>> joinInterviewerSession(int sessionId) async {
  final response = await _client.post(
    '/system/conference/session/$sessionId/interviewer/join',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-10 步骤5-6：设备与环境检测（摄像头/麦克风/网络，绿黄红灯报告）。
/// 已对接：POST /system/conference/session/{sessionId}/environment-check
Future<void> checkEnvironment(
  int sessionId,
  Map<String, Object?> report,
) async {
  await _client.post(
    '/system/conference/session/$sessionId/environment-check',
    body: report,
  );
}

/// UC-10 步骤8：面试须知确认。
/// 已对接：POST /system/conference/session/{sessionId}/consent
Future<void> confirmConsent(int sessionId, Map<String, Object?> payload) async {
  await _client.post(
    '/system/conference/session/$sessionId/consent',
    body: payload,
  );
}

/// UC-10 步骤9：开始面试（会话状态转"已就绪"）。
/// 已对接：POST /system/conference/session/{sessionId}/start
Future<void> startSession(int sessionId) async {
  await _client.post('/system/conference/session/$sessionId/start');
}

/// HR 发起视频面试：生成会议场次与候选人会议链接（与 PC 端一致）。
/// 已对接：POST /system/conference/link
///
/// 后端每次发起都会新建场次并签发新的随机链接，同时取消该候选人旧的
/// 待面试预约与未结束场次；发起后候选人流程状态自动推进为「面试中」。
/// 面试方式 mode 与面试官人数严格联动：1-纯AI（0人）、2-AI+单面试官（1人）、
/// 3-AI+多面试官（≥2人）、4-无AI纯人工（≥1人）。
Future<Map<String, dynamic>> createRoomLink({
  required int peerUserId,
  required int positionId,
  int? stageId,
  int? durationMinutes,
  int? mode,
  List<int>? interviewerIds,
}) async {
  final response = await _client.post(
    '/system/conference/link',
    body: {
      'peerUserId': peerUserId,
      'positionId': positionId,
      'stageId': stageId,
      'durationMinutes': durationMinutes,
      'mode': mode,
      'interviewerIds': interviewerIds,
    },
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12：面试进度（AI 面试进行状态）。
/// 已对接：GET /system/conference/session/{sessionId}/progress
Future<Map<String, dynamic>> getSessionProgress(int sessionId) async {
  final response = await _client.get(
    '/system/conference/session/$sessionId/progress',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12 A3：候选人作答上报。
/// 已对接：POST /system/conference/session/{sessionId}/answers
Future<void> submitAnswer(int sessionId, Map<String, Object?> payload) async {
  await _client.post(
    '/system/conference/session/$sessionId/answers',
    body: payload,
  );
}

/// UC-12：会话心跳保活。
/// 已对接：POST /system/conference/session/{sessionId}/heartbeat
Future<void> sendSessionHeartbeat(int sessionId) async {
  await _client.post('/system/conference/session/$sessionId/heartbeat');
}

/// UC-12：实时转写字幕（增量拉取）。
/// 已对接：GET /system/conference/session/{sessionId}/captions
Future<List<Map<String, dynamic>>> getCaptions(
  int sessionId, {
  int? afterSequence,
  int? limit,
}) async {
  final response = await _client.get(
    '/system/conference/session/$sessionId/captions',
    query: {'afterSequence': afterSequence, 'limit': limit},
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-14 B2-B3：HR 协同面试 AI 提词建议（含评分要点，增量拉取）。
/// 已对接：GET /system/conference/session/{sessionId}/copilot
Future<List<Map<String, dynamic>>> getCopilotSuggestions(
  int sessionId, {
  int? afterSequence,
  int? limit,
}) async {
  final response = await _client.get(
    '/system/conference/session/$sessionId/copilot',
    query: {'afterSequence': afterSequence, 'limit': limit},
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-14 B4：对提词建议执行采纳/编辑/忽略。
/// 已对接：POST /system/conference/session/{sessionId}/copilot/{id}/handle
Future<void> handleCopilotSuggestion(
  int sessionId,
  int suggestionId,
  Map<String, Object?> payload,
) async {
  await _client.post(
    '/system/conference/session/$sessionId/copilot/$suggestionId/handle',
    body: payload,
  );
}

/// UC-14：人工接管会话。
/// 已对接：POST /system/conference/session/{sessionId}/takeover
Future<void> takeOverSession(
  int sessionId,
  Map<String, Object?> payload,
) async {
  await _client.post(
    '/system/conference/session/$sessionId/takeover',
    body: payload,
  );
}

/// UC-12：正常结束面试。
/// 已对接：POST /system/conference/session/{sessionId}/finish
Future<void> finishSession(
  int sessionId, {
  Map<String, Object?>? payload,
}) async {
  await _client.post(
    '/system/conference/session/$sessionId/finish',
    body: payload,
  );
}

/// UC-12 E1：异常终止面试（强制中断兜底）。
/// 已对接：POST /system/conference/session/{sessionId}/abort
Future<void> abortSession(int sessionId) async {
  await _client.post('/system/conference/session/$sessionId/abort');
}

/// UC-12 步骤5-7：面试结果（五维评分卡 + 结构化评语）。
/// 已对接：GET /system/conference/session/{sessionId}/result
Future<Map<String, dynamic>> getSessionResult(int sessionId) async {
  final response = await _client.get(
    '/system/conference/session/$sessionId/result',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12 后置条件1：面试录制列表（合规存档）。
/// 已对接：GET /system/conference/recordings
Future<List<Map<String, dynamic>>> listRecordings({
  int? sessionId,
  String? candidate,
  String? from,
  String? to,
}) async {
  final response = await _client.get(
    '/system/conference/recordings',
    query: {
      'sessionId': sessionId,
      'candidate': candidate,
      'from': from,
      'to': to,
    },
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-12：面试回放。
/// 已对接：GET /system/conference/recordings/{sessionId}
Future<Map<String, dynamic>> getRecordingPlayback(int sessionId) async {
  final response = await _client.get(
    '/system/conference/recordings/$sessionId',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12：录制回放访问授权。
/// 已对接：POST /system/conference/recordings/{sessionId}/access
Future<void> requestRecordingAccess(
  int sessionId,
  Map<String, Object?> payload,
) async {
  await _client.post(
    '/system/conference/recordings/$sessionId/access',
    body: payload,
  );
}

/// UC-12：录制下载码申请。
/// 已对接：POST /system/conference/recordings/{sessionId}/download-code
Future<void> requestRecordingDownloadCode(int sessionId) async {
  await _client.post('/system/conference/recordings/$sessionId/download-code');
}

/// UC-12：录制下载。
/// 已对接：POST /system/conference/recordings/{sessionId}/download
Future<void> downloadRecording(
  int sessionId,
  Map<String, Object?> payload,
) async {
  await _client.post(
    '/system/conference/recordings/$sessionId/download',
    body: payload,
  );
}

/// UC-12：录制存储策略查看。
/// 已对接：GET /system/conference/storage-policy
Future<Map<String, dynamic>> getStoragePolicy() async {
  final response = await _client.get('/system/conference/storage-policy');
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12：录制存储策略保存。
/// 已对接：PUT /system/conference/storage-policy
Future<void> saveStoragePolicy(Map<String, Object?> payload) async {
  await _client.put('/system/conference/storage-policy', body: payload);
}
