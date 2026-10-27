import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import 'enterprise_ai_data_source.dart';
import 'enterprise_ai_events.dart';

class EnterpriseAiController extends ChangeNotifier {
  EnterpriseAiController(this.source);
  final EnterpriseAiDataSource source;
  EnterpriseAiSession? session;
  List<EnterpriseAiMessage> messages = [];
  EnterpriseAiRun? activeRun;
  String? error;
  int? before;
  bool loading = false,
      sending = false,
      loadingOlder = false,
      uncertain = false;
  bool _disposed = false, _refreshing = false, _paused = false;
  int _generation = 0;
  int _streamGeneration = 0;
  EnterpriseAiConnection? _connection;
  StreamSubscription<EnterpriseAiRun>? _subscription;
  String? _pendingId, _pendingText;
  bool get busy => sending || activeRun?.running == true || uncertain;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final history = await source.sessions();
      if (_disposed || generation != _generation) return;
      if (history.items.isNotEmpty) await open(history.items.first);
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = EnterpriseAiDataSource.errorMessage(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> open(EnterpriseAiSession target) async {
    if (sending) return;
    final generation = ++_generation;
    _disconnect();
    loading = true;
    loadingOlder = false;
    error = null;
    session = target;
    messages = [];
    activeRun = null;
    uncertain = false;
    _pendingId = null;
    _pendingText = null;
    before = null;
    _notify();
    try {
      final result = await source.messages(target.id);
      if (_disposed || generation != _generation) return;
      messages = result.items;
      before = result.next;
      if (result.activeRunId != null) {
        final run = await source.run(result.activeRunId!);
        if (_disposed || generation != _generation) return;
        _apply(run);
        _subscribe();
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = EnterpriseAiDataSource.errorMessage(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void newConversation() {
    if (_disposed || busy) return;
    _generation++;
    _disconnect();
    session = null;
    messages = [];
    activeRun = null;
    before = null;
    error = null;
    uncertain = false;
    loading = false;
    _pendingId = null;
    _pendingText = null;
    _notify();
  }

  Future<bool> send(String input) async {
    final text = input.trim();
    if (_disposed || busy || loading || text.isEmpty) return false;
    if (text.length > 4000) {
      error = '每条消息最多4000个字符';
      _notify();
      return false;
    }
    sending = true;
    error = null;
    _notify();
    bool attempted = false;
    try {
      session ??= await source.create();
      if (_disposed) return false;
      _pendingId = source.requestId();
      _pendingText = text;
      attempted = true;
      final run = await source.start(session!.id, _pendingId!, text);
      if (_disposed) return false;
      if (run.sessionId != session!.id) {
        throw const FormatException('AI对话关联异常，请刷新核对');
      }
      final snapshot = await source.messages(session!.id);
      if (_disposed) return false;
      messages = snapshot.items;
      before = snapshot.next;
      _apply(run);
      _pendingId = null;
      _pendingText = null;
      _subscribe();
      return true;
    } catch (e) {
      if (_disposed) return false;
      uncertain =
          attempted && (e is! ApiException || e.code == null || e.code! >= 500);
      error = uncertain
          ? '请求结果待核对，请先核对，不会自动重复发送'
          : EnterpriseAiDataSource.errorMessage(e);
      if (!uncertain) {
        _pendingId = null;
        _pendingText = null;
      }
      return false;
    } finally {
      if (!_disposed) {
        sending = false;
        _notify();
      }
    }
  }

  Future<void> verify() async {
    if (_disposed || sending || _pendingId == null || session == null) return;
    sending = true;
    error = null;
    _notify();
    try {
      final run = await source.lookup(session!.id, _pendingId!);
      if (_disposed) return;
      if (run == null) {
        error = '暂未查到该请求，请稍后再核对；确认未发送后可手动恢复编辑';
        return;
      }
      if (run.sessionId != session!.id) {
        throw const FormatException('AI对话关联异常，请刷新核对');
      }
      final snapshot = await source.messages(session!.id);
      if (_disposed) return;
      messages = snapshot.items;
      before = snapshot.next;
      _apply(run);
      uncertain = false;
      _pendingId = null;
      _pendingText = null;
      _subscribe();
    } catch (e) {
      if (!_disposed) error = EnterpriseAiDataSource.errorMessage(e);
    } finally {
      if (!_disposed) {
        sending = false;
        _notify();
      }
    }
  }

  void resumeEditing() {
    if (!uncertain || sending) return;
    uncertain = false;
    error = null;
    _pendingId = null;
    _pendingText = null;
    _notify();
  }

  String? get pendingText => _pendingText;
  Future<void> loadOlder() async {
    if (before == null || session == null || loadingOlder) return;
    final generation = _generation;
    loadingOlder = true;
    _notify();
    try {
      final result = await source.messages(session!.id, before: before);
      if (_disposed || generation != _generation) return;
      final ids = messages.map((row) => row.id).toSet();
      messages = [
        ...result.items.where((row) => !ids.contains(row.id)),
        ...messages,
      ];
      before = result.next;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = EnterpriseAiDataSource.errorMessage(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loadingOlder = false;
        _notify();
      }
    }
  }

  Future<void> stop() async {
    final run = activeRun;
    if (run == null || !run.running || sending) return;
    sending = true;
    _notify();
    try {
      final updated = await source.cancel(run.id);
      if (!_disposed) {
        _apply(updated);
        _disconnect();
        error = null;
      }
    } catch (e) {
      if (!_disposed) error = '停止结果待核对，请刷新回答状态';
    } finally {
      if (!_disposed) {
        sending = false;
        _notify();
      }
    }
  }

  Future<void> refreshRun() async {
    final current = activeRun;
    if (current == null || _disposed || _refreshing) return;
    final generation = _generation;
    _refreshing = true;
    _disconnect();
    try {
      final result = await source.run(current.id);
      if (_disposed || generation != _generation) return;
      if (result.id != current.id || result.sessionId != session?.id) {
        throw const FormatException('AI对话关联异常');
      }
      error = null;
      _apply(result);
      _subscribe();
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = '回答连接中断，点击刷新恢复；不会重复发送问题';
      }
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  void _apply(EnterpriseAiRun run) {
    activeRun = run;
    final row = EnterpriseAiMessage(
      run.id,
      'assistant',
      run.content,
      state: run.state,
    );
    final index = messages.indexWhere((message) => message.id == run.id);
    if (index < 0) {
      messages = [...messages, row];
    } else {
      messages = [...messages]..[index] = row;
    }
    if (run.state == 'F') error = run.error ?? '本次回答未完成，请稍后再试';
  }

  void _disconnect() {
    _streamGeneration++;
    final subscription = _subscription;
    final connection = _connection;
    _subscription = null;
    _connection = null;
    connection?.close();
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }
  }

  void _streamFailed(int generation, Object failure) {
    if (_disposed || generation != _streamGeneration) return;
    _disconnect();
    error = failure is ApiException && failure.isUnauthorized
        ? '登录已失效，请重新登录后使用AI助手'
        : '流式连接中断，点击刷新恢复；不会重复发送问题';
    _notify();
  }

  void _subscribe() {
    _disconnect();
    final current = activeRun;
    if (_disposed || _paused || current == null || !current.running) return;
    final generation = _streamGeneration;
    try {
      final connection = source.openEvents(current.id);
      _connection = connection;
      _subscription = connection.events.listen(
        (result) {
          if (_disposed || generation != _streamGeneration) return;
          if (result.id != current.id || result.sessionId != session?.id) {
            _streamFailed(generation, const FormatException('AI对话关联异常'));
            return;
          }
          error = null;
          _apply(result);
          if (!result.running) _disconnect();
          _notify();
        },
        onError: (Object failure) => _streamFailed(generation, failure),
        onDone: () {
          if (!_disposed &&
              generation == _streamGeneration &&
              activeRun?.running == true) {
            _streamFailed(generation, const FormatException('回答连接提前结束'));
          }
        },
      );
    } catch (failure) {
      _streamFailed(generation, failure);
    }
  }

  void pause(bool paused) {
    _paused = paused;
    if (paused) {
      _disconnect();
    } else {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _disconnect();
    super.dispose();
  }
}
