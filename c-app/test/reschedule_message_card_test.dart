import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'package:intelligent_interviewer/features/messages/presentation/reschedule_message_card.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

Map<String, dynamic> cardData(String status) => {
  'kind': 'interview_reschedule',
  'version': 1,
  'requestId': 31,
  'appointmentId': 44,
  'status': status,
  'positionName': '合成岗位',
  'originalStartTime': '2099-01-02 09:00:00',
  'originalEndTime': '2099-01-02 09:45:00',
  'newStartTime': '2099-01-03 10:00:00',
  'newEndTime': '2099-01-03 10:45:00',
  'reason': '合成申请原因',
  'reviewNote': '合成审批说明',
};

void main() {
  test('只将服务端卡片类型及协议识别为改期卡片，普通JSON消息保持文本', () {
    for (final status in ['changed', 'pending', 'approved', 'rejected']) {
      final message = ChatMessage.fromJson({
        'messageId': 77,
        'senderId': 9,
        'type': 5,
        'content': jsonEncode(cardData(status)),
        'mine': false,
      });
      expect(message.reschedule?['status'], status);
    }
    for (final content in ['invalid', '[]', '{"kind":"other","version":1}']) {
      expect(
        ChatMessage.fromJson({'type': 5, 'content': content}).reschedule,
        isNull,
      );
    }
    expect(
      ChatMessage.fromJson({
        'type': 1,
        'content': jsonEncode(cardData('approved')),
      }).reschedule,
      isNull,
    );
  });

  for (final entry in {
    'changed': '企业已调整面试时间',
    'pending': '改期申请已提交',
    'approved': '改期申请已同意',
    'rejected': '改期申请未通过',
  }.entries) {
    testWidgets('求职者展示${entry.key}卡片和完整时段及审批说明', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RescheduleMessageCard(data: cardData(entry.key)),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.textContaining('2099-01-02 09:45:00'), findsOneWidget);
      expect(find.textContaining('2099-01-03 10:45:00'), findsOneWidget);
      expect(find.text('审批说明：合成审批说明'), findsOneWidget);
      expect(find.text('同意'), findsNothing);
      expect(find.text('拒绝'), findsNothing);
      if (entry.key == 'rejected') {
        expect(find.textContaining('面试仍按原安排进行'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('没有申请原因时仍显示审批说明，自己发出的申请文字保持清晰', (tester) async {
    final data = cardData('rejected')..remove('reason');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RescheduleMessageCard(data: data, mine: true)),
      ),
    );
    expect(find.text('审批说明：合成审批说明'), findsOneWidget);
    final context = tester.element(find.text('审批说明：合成审批说明'));
    expect(DefaultTextStyle.of(context).style.color, Colors.white);
  });
}
