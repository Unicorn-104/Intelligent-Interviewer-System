import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/chat_context.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/message_avatar.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'message_center_page_test.dart'
    show FakeMessageSource, mountMessages, sessionJson;
import 'support/talent_detail_fixture.dart';
import 'support/job_detail_fixture.dart';

ChatJob chatJob(int id, {int talentId = 42}) => ChatJob(
  job: {
    'posId': id,
    'title': '合成研发岗位$id',
    'salaryMin': 18000,
    'salaryMax': 28000,
    'city': '杭州',
    'experience': '3-5年',
    'education': 3,
  },
  talent: {
    'talentId': talentId,
    'userId': 12,
    'name': '合成候选人',
    'currentStage': '初筛',
  },
);

class ContextSource extends FakeMessageSource {
  final candidate = TalentFakeSource();
  final job = DetailFakeSource();
  Completer<ChatContext>? gate;
  @override
  TalentFakeSource get candidateDetailsSource => candidate;
  @override
  DetailFakeSource get jobDetailsSource => job;
  @override
  Future<ChatContext> loadChatContext(Map<String, dynamic> session) =>
      gate?.future ?? super.loadChatContext(session);
}

void main() {
  testWidgets('岗位卡固定在聊天顶部，历史滚动不移动卡片或重复读取岗位', (tester) async {
    final job = chatJob(7);
    final source = ContextSource()
      ..chatContext = ChatContext(jobs: [job], talent: job.talent);
    source.messages = List.generate(
      35,
      (i) => ConversationMessage.fromJson({
        'messageId': i + 1,
        'isMine': i.isOdd,
        'content': '合成聊天内容$i',
        'sendTime': '2026-10-22 09:00',
      }),
    );
    await mountMessages(tester, source, chat: true);
    final card = find.byKey(const Key('chat-job-card'));
    expect(find.text('合成研发岗位7'), findsOneWidget);
    expect(find.text('杭州 · 3-5年 · 本科'), findsOneWidget);
    final top = tester.getTopLeft(card);
    final list = find.ancestor(
      of: find.byKey(const ValueKey('chat-message-35')),
      matching: find.byType(ListView),
    );
    await tester.drag(list, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card), top);
    await tester.tap(find.byKey(const Key('chat-refresh')));
    await tester.pumpAndSettle();
    expect(source.contextCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('气泡显示对方头像，点击以候选人编号进入招聘者人才详情并保留岗位', (tester) async {
    final job = chatJob(7);
    final source = ContextSource()
      ..chatContext = ChatContext(jobs: [job], talent: job.talent);
    await mountMessages(tester, source, chat: true);
    final avatar = find.byKey(const ValueKey('chat-peer-avatar-1'));
    expect(
      find.descendant(of: avatar, matching: find.byType(MessageAvatar)),
      findsOneWidget,
    );
    await tester.tap(avatar);
    await tester.pumpAndSettle();
    final page = tester.widget<TalentDetailPage>(find.byType(TalentDetailPage));
    expect(page.talent['talentId'], 42);
    expect(page.talent['talentId'], isNot(sessionJson()['peerId']));
    expect(page.jobContext!.positionId, 7);
    expect(page.jobContext!.currentStage, '初筛');
    expect(source.candidate.detailCalls, 1);
  });

  testWidgets('点击顶部岗位卡打开企业岗位详情', (tester) async {
    final job = chatJob(1);
    final source = ContextSource()
      ..chatContext = ChatContext(jobs: [job], talent: job.talent);
    await mountMessages(tester, source, chat: true);
    await tester.tap(find.byKey(const Key('chat-job-card')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<JobDetailPage>(find.byType(JobDetailPage)).job['posId'],
      1,
    );
    expect(source.job.detailCalls, 1);
  });

  testWidgets('多岗位不默认第一项，选择后资料入口使用当前岗位的候选人编号', (tester) async {
    final source = ContextSource()
      ..chatContext = ChatContext(
        jobs: [chatJob(7, talentId: 107), chatJob(8, talentId: 108)],
      );
    await mountMessages(tester, source, chat: true);
    expect(find.text('应聘多个岗位，请选择'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-select-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-job-option-8')));
    await tester.pumpAndSettle();
    expect(find.text('合成研发岗位8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-peer-profile')));
    await tester.pumpAndSettle();
    final page = tester.widget<TalentDetailPage>(find.byType(TalentDetailPage));
    expect(page.talent['talentId'], 108);
    expect(page.jobContext!.positionId, 8);
  });

  testWidgets('无关联不编造岗位或求职者，读取失败可重试且仍可发送消息', (tester) async {
    final source = ContextSource()..contextFail = true;
    await mountMessages(tester, source, chat: true);
    expect(find.text('岗位资料暂不可用'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('chat-input')), '合成发送');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(source.sends, ['合成发送']);
    source.contextFail = false;
    await tester.tap(find.byKey(const Key('chat-job-card')));
    await tester.pumpAndSettle();
    expect(find.text('暂无关联应聘岗位'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-peer-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(TalentDetailPage), findsNothing);
    expect(find.text('当前企业暂无该求职者的关联资料，请稍后刷新重试'), findsOneWidget);
  });

  testWidgets('仅人才库关联仍可查看真实求职者，不虚构岗位上下文', (tester) async {
    final source = ContextSource()
      ..chatContext = ChatContext(
        talent: {'talentId': 42, 'userId': 12, 'name': '合成候选人'},
      );
    await mountMessages(tester, source, chat: true);
    expect(find.text('暂无关联应聘岗位'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-peer-profile')));
    await tester.pumpAndSettle();
    final page = tester.widget<TalentDetailPage>(find.byType(TalentDetailPage));
    expect(page.talent['talentId'], 42);
    expect(page.jobContext, isNull);
    expect(source.candidate.matchCalls, 0);
  });

  testWidgets('未关联岗位可点击重新读取', (tester) async {
    final source = ContextSource();
    await mountMessages(tester, source, chat: true);
    final job = chatJob(7);
    source.chatContext = ChatContext(jobs: [job], talent: job.talent);
    await tester.tap(find.byKey(const Key('chat-job-card')));
    await tester.pumpAndSettle();
    expect(find.text('合成研发岗位7'), findsOneWidget);
    expect(source.contextCalls, 2);
  });

  testWidgets('岗位读取中不阻塞消息且离开页面后返回不会setState', (tester) async {
    final source = ContextSource()..gate = Completer<ChatContext>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChatPage(
          session: sessionJson(),
          source: source,
          pollInterval: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('正在读取应聘岗位…'), findsOneWidget);
    expect(find.text('真实接口合成消息'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    source.gate!.complete(ChatContext());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('真实岗位和长消息在$size大字及键盘下不溢出', (tester) async {
      final source = ContextSource()
        ..chatContext = ChatContext(jobs: [chatJob(7)]);
      source.messages = [
        ConversationMessage.fromJson({
          'messageId': 1,
          'isMine': false,
          'content': '合成超长消息' * 30,
        }),
      ];
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ChatPage(
            session: sessionJson(),
            source: source,
            pollInterval: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'before keyboard');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
