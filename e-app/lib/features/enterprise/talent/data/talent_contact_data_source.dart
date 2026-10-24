import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/enterprise_api_client.dart';
import '../../notification/data/message_data_source.dart';
import 'talent_discovery_data_source.dart';
import '../../notification/models/message_view_data.dart';

class TalentContactTarget {
  const TalentContactTarget({
    required this.userId,
    required this.name,
    required this.avatar,
  });
  final int userId;
  final String name, avatar;
}

class TalentContactDataSource {
  const TalentContactDataSource({
    this.client,
    this.storage = const FlutterSecureStorage(),
  });
  final EnterpriseApiClient? client;
  final FlutterSecureStorage storage;
  MessageDataSource get messages =>
      MessageDataSource(client: client, storage: storage);

  Future<void> _requireSession() async {
    final token = await storage.read(key: 'enterprise_access_token');
    if (token == null || token.isEmpty) {
      throw const ApiException('登录已失效，请重新登录', code: 401);
    }
  }

  Future<TalentContactTarget> loadTarget(int talentId) async {
    await _requireSession();
    if (talentId <= 0) throw const FormatException('候选人编号无效');
    final response = await (client ?? EnterpriseApiClient()).get(
      '/enterprise/talent/$talentId',
    );
    final detail = response['data'];
    if (detail is! Map || messageId(detail['talentId']) != talentId) {
      throw const FormatException('求职者资料编号不一致，请重新读取');
    }
    final userId = messageId(detail['userId']);
    if (userId == null) throw const FormatException('该候选人未关联可沟通账号，暂无法主动联系');
    return TalentContactTarget(
      userId: userId,
      name: messageText(detail['name'], '求职者'),
      avatar: messageText(detail['avatar'], ''),
    );
  }

  Future<TalentContactTarget> loadUserTarget(int userId) async {
    await _requireSession();
    final profile = await TalentDiscoveryDataSource(client: client)
        .detail(userId);
    return TalentContactTarget(
      userId: userId,
      name: messageText(profile['name'], '求职者'),
      avatar: messageText(profile['avatar'], ''),
    );
  }

  Future<Map<String, dynamic>?> findSession(TalentContactTarget target) async {
    final sessions = (await messages.loadSessions())
        .where((item) => item.peerId == target.userId)
        .toList();
    if (sessions.length > 1) throw const FormatException('沟通会话关联异常，请到消息中心核对');
    return sessions.isEmpty ? null : sessions.single.raw;
  }

  Future<Map<String, dynamic>> sendGreeting(
    TalentContactTarget target,
    String text,
  ) async {
    await _requireSession();
    final content = text.trim();
    if (content.isEmpty || content.length > 1000) {
      throw const FormatException('请输入1至1000字的招呼语');
    }
    // Only an explicit greeting creates a conversation. Never send a fake empty message.
    final response = await (client ?? EnterpriseApiClient()).post(
      '/system/im/messages',
      body: {'peerId': target.userId, 'type': 1, 'content': content},
    );
    final id = messageId(response['sessionId']);
    if (id == null) throw const FormatException('发送结果待核对，请刷新会话，不要重复发送');
    return {
      'sessionId': id,
      'peerId': target.userId,
      'peerName': target.name,
      'peerAvatar': target.avatar,
    };
  }
}
