import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_controller.dart';
import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_data_source.dart';

import 'support/fake_enterprise_ai_source.dart';

void main() {
  test('打开助手与新对话不写数据库，首次明确发送才建会话', () async {
    final source = FakeEnterpriseAiSource();
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    await chat.initialize();
    chat.newConversation();
    expect(source.creates, 0);
    expect(source.starts, 0);
    expect(await chat.send('合成招聘问题'), isTrue);
    expect(source.creates, 1);
    expect(source.starts, 1);
    expect(chat.messages.map((m) => m.role), ['user', 'assistant']);
    expect(chat.messages.last.content, '合成回答');
  });
  test('发送超时锁定输入，不自动重发，核对后恢复原回答', () async {
    final source = FakeEnterpriseAiSource()..timeout = true;
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    expect(await chat.send('合成问题'), isFalse);
    expect(chat.uncertain, isTrue);
    expect(await chat.send('不要重复'), isFalse);
    expect(source.starts, 1);
    await chat.verify();
    expect(source.lookups, 1);
    expect(source.starts, 1);
    expect(chat.uncertain, isFalse);
    expect(chat.messages.first.content, '合成问题');
  });
  test('初始化迟到的历史结果不能覆盖新会话', () async {
    final source = FakeEnterpriseAiSource()..historyGate = Completer();
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    final initializing = chat.initialize();
    chat.newConversation();
    source.historyGate!.complete(
      const EnterpriseAiSlice([EnterpriseAiSession(9, '旧合成会话')], null),
    );
    await initializing;
    expect(chat.session, isNull);
    expect(chat.loading, isFalse);
  });
  test('读取历史及更早消息保持顺序，不触发模型调用', () async {
    final source = FakeEnterpriseAiSource()
      ..history = [const EnterpriseAiSession(1, '合成历史')]
      ..rows = [
        const EnterpriseAiMessage(11, 'user', '合成历史问题'),
        const EnterpriseAiMessage(12, 'assistant', '合成历史回答', state: 'C'),
      ]
      ..older = 11;
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    await chat.initialize();
    await chat.loadOlder();
    expect(chat.messages.map((m) => m.id), [1, 11, 12]);
    expect(chat.before, isNull);
    expect(source.starts, 0);
    expect(source.creates, 0);
  });
  test('后台及销毁断开流式连接，恢复仅订阅原回答，不重新发送', () async {
    final source = FakeEnterpriseAiSource()
      ..answer = const EnterpriseAiRun(12, 1, 'R', '部分合成内容');
    final chat = EnterpriseAiController(source);
    await chat.send('合成问题');
    chat.pause(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(source.polls, 0);
    chat.pause(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(source.streamsOpened, 2);
    expect(source.polls, 0);
    chat.dispose();
    final count = source.polls;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(source.polls, count);
    expect(source.starts, 1);
  });
  test('停止回答保留已有内容，状态读取错误不自动重发', () async {
    final source = FakeEnterpriseAiSource()
      ..answer = const EnterpriseAiRun(12, 1, 'R', '合成部分内容');
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    await chat.send('合成问题');
    source.failPoll = true;
    await chat.refreshRun();
    expect(chat.error, contains('不会重复发送'));
    expect(source.starts, 1);
    await chat.stop();
    expect(chat.messages.last.state, 'X');
    expect(chat.messages.last.content, '合成部分内容');
    expect(chat.busy, isFalse);
  });
  test('空白及超长内容不触发写入', () async {
    final source = FakeEnterpriseAiSource();
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    expect(await chat.send('   '), isFalse);
    expect(await chat.send('x' * 4001), isFalse);
    expect(source.creates, 0);
    expect(source.starts, 0);
  });
  test('流式分段抵达即更新气泡，无需等待整段或轮询', () async {
    final source = FakeEnterpriseAiSource()
      ..answer = const EnterpriseAiRun(12, 1, 'R', '');
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    await chat.send('合成流式问题');
    source.emit(const EnterpriseAiRun(12, 1, 'R', '先到的半句'));
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages.last.content, '先到的半句');
    expect(chat.busy, isTrue);
    source.emit(const EnterpriseAiRun(12, 1, 'R', '先到的半句，随后继续输出'));
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages.last.content, '先到的半句，随后继续输出');
    source.emit(const EnterpriseAiRun(12, 1, 'C', '先到的半句，随后继续输出。'));
    await Future<void>.delayed(Duration.zero);
    expect(chat.busy, isFalse);
    expect(source.polls, 0);
    expect(source.starts, 1);
    expect(source.streamsClosed, 1);
  });
  test('断线保留部分文本，人工刷新重连只订阅已有任务', () async {
    final source = FakeEnterpriseAiSource()
      ..answer = const EnterpriseAiRun(12, 1, 'R', '已生成的部分');
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    await chat.send('合成恢复问题');
    source.failStream();
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages.last.content, '已生成的部分');
    expect(chat.error, contains('不会重复发送'));
    expect(source.streamsClosed, 1);
    await chat.refreshRun();
    source.emit(const EnterpriseAiRun(12, 1, 'C', '已生成的部分及恢复后的内容'));
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages.last.content, '已生成的部分及恢复后的内容');
    expect(source.starts, 1);
    expect(source.streamsOpened, 2);
    expect(source.polls, 1);
  });
  test('拒绝串入其他回答的流式事件，不污染当前会话', () async {
    final source = FakeEnterpriseAiSource()
      ..answer = const EnterpriseAiRun(12, 1, 'R', '当前合成文本');
    final chat = EnterpriseAiController(source);
    addTearDown(chat.dispose);
    await chat.send('合成问题');
    source.emit(const EnterpriseAiRun(99, 2, 'C', '不应出现的文本'));
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages.last.content, '当前合成文本');
    expect(chat.error, contains('流式连接中断'));
    expect(source.streamsClosed, 1);
  });
}
