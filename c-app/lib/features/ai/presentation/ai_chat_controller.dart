import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';
import '../data/ai_api.dart';
import '../data/ai_conversation_store.dart';
import '../domain/ai_models.dart';

class AiChatController extends ChangeNotifier {
  AiChatController(
    this.api,
    this.token,
    this.sessionId, {
    this.conversationStore,
    this._restoreLastConversation = false,
  });
  final AiApi api;
  final String token;
  final AiConversationStore? conversationStore;
  bool _restoreLastConversation;
  String? _rememberedSessionId;
  String? sessionId;
  List<AiMessage> messages = [];
  bool loading = false;
  bool sending = false;
  bool stopping = false;
  bool hasOlder = false;
  int? _before;
  String? error;
  String? runId;
  String status = '';
  String draft = '';
  List<Job> cards = [];
  String? _requestId;
  String? _requestContent;
  int? _requestResume;
  int? _requestApplication;
  String _requestAction = 'chat';
  int _cursor = 0;
  bool _disposed = false;
  bool _completing = false;
  StreamSubscription<AiEvent>? _stream;
  int _epoch = 0;
  int _streamEpoch = 0;
  bool get busy => sending || runId != null || stopping || _completing;
  bool get awaitingConversation =>
      _restoreLastConversation && sessionId == null;
  bool get canRetry =>
      !busy &&
      !loading &&
      messages.isNotEmpty &&
      messages.last.role == 'user' &&
      messages.last.runId != null &&
      messages.last.runStatus == 'FAILED';

  Future<bool> retry() async {
    if (!canRetry || _disposed) return false;
    final question = messages.last;
    final failedRun = question.runId;
    if (failedRun == null) return false;
    final epoch = _epoch;
    loading = true;
    error = null;
    _notify();
    int? resumeId;
    int? applicationId;
    var action = 'chat';
    try {
      final metadata = await api.run(token, failedRun);
      if (!_valid(epoch)) return false;
      if (metadata['status'] != 'FAILED') {
        loading = false;
        await load();
        return false;
      }
      resumeId = (metadata['resumeId'] as num?)?.toInt();
      applicationId = (metadata['applicationId'] as num?)?.toInt();
      action = metadata['action'] as String? ?? 'chat';
    } catch (e) {
      if (_valid(epoch)) error = _message(e);
      return false;
    } finally {
      if (_valid(epoch)) {
        loading = false;
        _notify();
      }
    }
    if (!_valid(epoch)) return false;
    return send(
      question.content,
      resumeId,
      applicationId: applicationId,
      action: action,
    );
  }

  Future<void> load({bool older = false}) async {
    if (_restoreLastConversation && sessionId == null) {
      await _restoreConversation();
      return;
    }
    final id = sessionId;
    if (id == null) return;
    if (loading || _disposed) return;
    final epoch = _epoch;
    loading = true;
    error = null;
    _notify();
    try {
      final data = await api.messages(
        token,
        id,
        before: older ? _before : null,
      );
      if (!_valid(epoch)) return;
      final items = (data['items'] as List)
          .map(
            (item) =>
                AiMessage.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      messages = older ? [...items, ...messages] : items;
      hasOlder = data['hasNext'] == true;
      _before = data['nextCursor'] as int?;
      if (!older) {
        runId = data['activeRunId'] as String?;
        if (runId != null) {
          draft = '';
          cards = [];
          _cursor = 0;
          status = '正在恢复回答';
          await reconnect();
        } else if (messages.isNotEmpty &&
            messages.last.role == 'user' &&
            messages.last.runStatus == 'FAILED') {
          final failedRun = messages.last.runId;
          if (failedRun != null) {
            final metadata = await api.run(token, failedRun);
            if (!_valid(epoch)) return;
            error = aiRunError(metadata['errorCode'] as String?);
          }
        }
      }
    } catch (e) {
      if (_valid(epoch)) error = _message(e);
    } finally {
      if (_valid(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _restoreConversation() async {
    if (loading || _disposed) return;
    final epoch = _epoch;
    loading = true;
    error = null;
    _notify();
    try {
      var id = await conversationStore?.read();
      if (!_valid(epoch)) return;
      if (id == null) {
        final data = await api.sessions(token);
        if (!_valid(epoch)) return;
        final items = data['items'] as List;
        if (items.isNotEmpty) {
          id = AiSession.fromJson(
            Map<String, dynamic>.from(items.first as Map),
          ).id;
        }
      }
      sessionId = id;
      _restoreLastConversation = false;
    } catch (e) {
      if (_valid(epoch)) error = _message(e);
    } finally {
      if (_valid(epoch)) {
        loading = false;
        _notify();
      }
    }
    if (_valid(epoch) && !_restoreLastConversation && sessionId != null) {
      await load();
    }
  }

  Future<bool> send(
    String content,
    int? resumeId, {
    int? applicationId,
    String action = 'chat',
  }) async {
    content = content.trim();
    if (busy ||
        loading ||
        awaitingConversation ||
        content.isEmpty ||
        content.length > 4000 ||
        _disposed) {
      return false;
    }
    final epoch = _epoch;
    sending = true;
    error = null;
    status = '正在发送';
    _notify();
    if (_requestContent != content ||
        _requestResume != resumeId ||
        _requestApplication != applicationId ||
        _requestAction != action ||
        _requestId == null) {
      _requestId = _newRequestId();
      _requestContent = content;
      _requestResume = resumeId;
      _requestApplication = applicationId;
      _requestAction = action;
    }
    try {
      if (sessionId == null) {
        final conversation = await api.createSession(token);
        if (!_valid(epoch)) return false;
        sessionId = conversation.id;
      }
      final data = await api.start(
        token,
        sessionId!,
        content: content,
        requestId: _requestId!,
        resumeId: resumeId,
        applicationId: applicationId,
        action: action,
      );
      if (!_valid(epoch)) return false;
      _requestId = null;
      runId = data['id'] as String;
      sending = false;
      await load();
      return true;
    } catch (e) {
      if (_valid(epoch)) error = _message(e);
      return false;
    } finally {
      if (_valid(epoch)) {
        sending = false;
        _notify();
      }
    }
  }

  Future<void> reconnect() async {
    final id = runId;
    if (id == null || _disposed) return;
    final epoch = _epoch;
    final streamEpoch = ++_streamEpoch;
    await _stream?.cancel();
    if (!_valid(epoch) || streamEpoch != _streamEpoch) return;
    error = null;
    _stream = api
        .events(token, id, _cursor)
        .listen(
          (event) {
            if (!_valid(epoch) ||
                streamEpoch != _streamEpoch ||
                runId != id ||
                event.id <= _cursor) {
              return;
            }
            _cursor = event.id;
            switch (event.type) {
              case 'status':
                status = event.data['text']?.toString() ?? '正在处理';
              case 'delta':
                draft += event.data['text']?.toString() ?? '';
              case 'cards':
                cards = readJobCards(event.data['items']);
              case 'done':
                final finalStatus = event.data['status'];
                error = finalStatus == 'FAILED'
                    ? aiRunError(event.data['errorCode'] as String?)
                    : null;
                status = finalStatus == 'CANCELLED' ? '已停止生成' : '';
                runId = null;
                unawaited(_complete(error));
            }
            _notify();
          },
          onError: (Object e) {
            if (_valid(epoch) && streamEpoch == _streamEpoch) {
              error = _message(e);
              _notify();
            }
          },
          onDone: () {
            if (_valid(epoch) && streamEpoch == _streamEpoch && runId != null) {
              error = '连接已断开，点击重新连接查看回答';
              _notify();
            }
          },
        );
    _notify();
  }

  Future<void> _complete(String? finalError) async {
    if (_completing || _disposed) return;
    _completing = true;
    await _stream?.cancel();
    _stream = null;
    draft = '';
    cards = [];
    loading = false;
    await load();
    _completing = false;
    _notify();
    if (!_disposed && finalError != null) {
      error = finalError;
      _notify();
    }
  }

  Future<void> stop() async {
    final id = runId;
    if (id == null || stopping) return;
    stopping = true;
    _notify();
    try {
      await api.cancel(token, id);
      if (_disposed) return;
      runId = null;
      status = '已停止生成';
      await _complete(null);
    } catch (e) {
      if (!_disposed) error = _message(e);
    } finally {
      if (!_disposed) {
        stopping = false;
        _notify();
      }
    }
  }

  String _newRequestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  bool _valid(int epoch) => !_disposed && epoch == _epoch;
  void _notify() {
    if (_disposed) return;
    final id = sessionId;
    if (id != null && id != _rememberedSessionId && conversationStore != null) {
      _rememberedSessionId = id;
      unawaited(conversationStore!.write(id));
    }
    notifyListeners();
  }

  String _message(Object e) => e is ApiException ? e.message : 'AI 服务暂不可用，请重试';
  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    unawaited(_stream?.cancel());
    super.dispose();
  }
}
