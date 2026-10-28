import 'package:flutter/material.dart';

import '../../../api/interview_room_api.dart' as room;
import '../../../config/app_config.dart';
import '../dashboard/home_models.dart';
import '../notification/conversation_page.dart';
import '../notification/data/message_data_source.dart';
import '../notification/models/message_view_data.dart';

/// 面试模式中文文案（与 enterprise_pc messages/index.vue 的 MODE_LABEL 一致）。
const Map<int, String> interviewModeLabels = {
  1: '纯AI面试',
  2: 'AI+单面试官',
  3: 'AI+多面试官',
  4: '无AI纯人工',
};

/// 阶段类型 → 默认面试方式（与 PC 端 STAGE_TYPE_MODE 一致）：
/// AI技术面试→AI+单面试官、HR综合面试→无AI纯人工、编程实操→纯AI。
const Map<int, int> stageTypeMode = {2: 2, 3: 4, 4: 1};

typedef CreateRoomLink = Future<Map<String, dynamic>> Function({
  required int peerUserId,
  required int positionId,
  int? stageId,
  int? durationMinutes,
  int? mode,
  List<int>? interviewerIds,
});

/// 点击「开始面试」：复用 PC 端 POST /system/conference/link 生成会议场次，
/// 把面试邀请（含候选人端会议链接）以文本消息发送到候选人会话，随后打开会话。
///
/// 后端每次发起都会新建场次并签发新的随机链接，同时取消该候选人旧的
/// 待面试预约与未结束场次；发起后候选人流程状态自动推进为「面试中」。
bool _starting = false;

Future<void> startInterviewInvitation(
  BuildContext context,
  HomeInterview interview, {
  MessageDataSource? source,
  CreateRoomLink? createLink,
}) async {
  if (_starting) return;
  _starting = true;
  try {
    await _invite(context, interview, source: source, createLink: createLink);
  } finally {
    _starting = false;
  }
}

Future<void> _invite(
  BuildContext context,
  HomeInterview interview, {
  MessageDataSource? source,
  CreateRoomLink? createLink,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final raw = interview.raw;
  final peerUserId = messageId(raw['candidateUserId']);
  final positionId = interview.positionId;
  final interviewerId = messageId(raw['interviewerId']);
  final stageType = messageId(raw['stageType']);
  final stageName = homeText(raw['stageName'], '');
  if (peerUserId == null || positionId == null) {
    messenger.showSnackBar(const SnackBar(content: Text('面试信息不完整，无法发起面试邀请')));
    return;
  }
  final mode = stageTypeMode[stageType];
  if (mode != 1 && interviewerId == null) {
    messenger.showSnackBar(const SnackBar(content: Text('该面试未指派面试官，无法发起面试')));
    return;
  }
  final Map<String, dynamic> link;
  try {
    link = await (createLink ?? room.createRoomLink)(
      peerUserId: peerUserId,
      positionId: positionId,
      stageId: messageId(raw['stageId']),
      durationMinutes: _appointmentMinutes(raw),
      mode: mode,
      interviewerIds: mode == 1 ? const <int>[] : <int>[interviewerId!],
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('发起面试失败：$error')));
    return;
  }
  final token = homeText(link['token'], '');
  if (token.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('会议链接生成异常，请稍后重试')));
    return;
  }
  final modeLabel =
      interviewModeLabels[int.tryParse('${link['mode']}')] ?? '视频面试';
  final inviteTag = stageName.isEmpty
      ? '·$modeLabel'
      : '·$stageName·$modeLabel';
  final company = homeText(link['companyName'], '公司');
  final position = homeText(link['positionTitle'], '岗位');
  final inviteUrl = '${AppConfig.candidateAppUrl}/conference-join?token=$token';
  final text = '【面试邀请$inviteTag】$company $position 视频面试，请点击链接进入：$inviteUrl';

  final client = source ?? const MessageDataSource();
  final int sessionId;
  try {
    final existing = await client.findPeerSession(peerUserId);
    if (existing == null) {
      sessionId = await client.startPeerConversation(peerUserId, text);
    } else {
      await client.send(existing, text);
      sessionId = existing;
    }
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('面试邀请发送失败：$error')));
    return;
  }
  if (!context.mounted) return;
  // 邀请已发出、会话即将打开，释放防重入标志；网络临界区（生成链接+发消息）已结束。
  _starting = false;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        session: {
          'sessionId': sessionId,
          'peerId': peerUserId,
          'peerName': interview.candidate,
        },
        source: client,
      ),
    ),
  );
}

/// 按预约起止时间推算面试时长（分钟）；不在后端允许区间内时不传，由后端取默认值。
int? _appointmentMinutes(Map<String, dynamic> raw) {
  final start = DateTime.tryParse(
    homeText(raw['startTime'], '').replaceFirst(' ', 'T'),
  );
  final end = DateTime.tryParse(
    homeText(raw['endTime'], '').replaceFirst(' ', 'T'),
  );
  if (start == null || end == null || !end.isAfter(start)) return null;
  final minutes = end.difference(start).inMinutes;
  return minutes >= 1 && minutes <= 480 ? minutes : null;
}
