import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_events.dart';

import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_data_source.dart';

/// Synthetic, in-memory fixture. Never connects to a model or a database.
class FakeEnterpriseAiSource extends EnterpriseAiDataSource {
  int creates = 0, starts = 0, polls = 0, cancels = 0, lookups = 0;
  bool timeout = false, failPoll = false;
  int streamsOpened = 0, streamsClosed = 0;
  final streams = <StreamController<EnterpriseAiRun>>[];

  @override
  EnterpriseAiConnection openEvents(int id) {
    streamsOpened++;
    final controller = StreamController<EnterpriseAiRun>();
    streams.add(controller);
    controller.add(answer);
    var closed = false;
    return EnterpriseAiConnection(controller.stream, () {
      if (closed) return;
      closed = true;
      streamsClosed++;
      streams.remove(controller);
      if (!controller.isClosed) unawaited(controller.close());
    });
  }

  void emit(EnterpriseAiRun run) {
    answer = run;
    for (final stream in List.of(streams)) {
      if (!stream.isClosed) stream.add(run);
    }
  }

  void failStream() {
    for (final stream in List.of(streams)) {
      if (!stream.isClosed) {
        stream.addError(TimeoutException('Synthetic SSE timeout'));
      }
    }
  }

  final deleted = <int>[];
  final prompts = <String>[];
  List<EnterpriseAiSession> history = [];
  List<EnterpriseAiMessage> rows = [];
  int? older;
  EnterpriseAiRun answer = const EnterpriseAiRun(12, 1, 'C', '合成回答');
  Completer<EnterpriseAiSlice<EnterpriseAiSession>>? historyGate;
  @override
  Future<EnterpriseAiSlice<EnterpriseAiSession>> sessions({
    int? before,
  }) async => historyGate == null
      ? EnterpriseAiSlice(history, null)
      : historyGate!.future;
  @override
  Future<EnterpriseAiSession> create() async {
    creates++;
    return const EnterpriseAiSession(1, '新对话');
  }

  @override
  Future<EnterpriseAiSlice<EnterpriseAiMessage>> messages(
    int session, {
    int? before,
  }) async => EnterpriseAiSlice(
    before == null ? rows : [const EnterpriseAiMessage(1, 'user', '更早的合成问题')],
    before == null ? older : null,
  );
  @override
  Future<EnterpriseAiRun> start(
    int session,
    String requestId,
    String content,
  ) async {
    starts++;
    prompts.add(content);
    if (timeout) throw TimeoutException('Synthetic timeout');
    rows = [EnterpriseAiMessage(11, 'user', content)];
    return answer;
  }

  @override
  Future<EnterpriseAiRun?> lookup(int session, String requestId) async {
    lookups++;
    rows = [EnterpriseAiMessage(11, 'user', prompts.last)];
    return answer;
  }

  @override
  Future<EnterpriseAiRun> run(int id) async {
    polls++;
    if (failPoll) throw TimeoutException('Synthetic timeout');
    return answer;
  }

  @override
  Future<EnterpriseAiRun> cancel(int id) async {
    cancels++;
    return EnterpriseAiRun(id, answer.sessionId, 'X', answer.content);
  }

  @override
  Future<void> delete(int id) async {
    deleted.add(id);
    history = history.where((s) => s.id != id).toList();
  }
}
