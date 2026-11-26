import 'package:enterprise_recruiter/features/enterprise/notification/models/exam_invitation.dart';
import 'package:flutter_test/flutter_test.dart';

const invite =
    '【笔试邀请·Java后端笔试试卷】Java工程师，作答时间 2026-11-26 10:00 ~ '
    '2026-11-26 11:00，试卷时长 60 分钟。请点击链接进入：'
    'https://app.local/user/exam?scheduleId=12';

void main() {
  test('解析笔试邀请卡片字段', () {
    final card = ExamInvitation.parse(invite);
    expect(card, isNotNull);
    expect(card!.scheduleId, 12);
    expect(card.paperName, 'Java后端笔试试卷');
    expect(
      card.detail,
      'Java工程师，作答时间 2026-11-26 10:00 ~ 2026-11-26 11:00，试卷时长 60 分钟',
    );
    expect(card.url, endsWith('/user/exam?scheduleId=12'));
  });

  test('兼容相对链接并拒绝非考试入口', () {
    final card = ExamInvitation.parse(
      invite.replaceFirst('https://app.local/user/exam', '/exam'),
    );
    expect(card?.scheduleId, 12);
    expect(
      ExamInvitation.parse(invite.replaceFirst('/exam?', '/jobs?')),
      isNull,
    );
    expect(
      ExamInvitation.parse(
        invite.replaceFirst('scheduleId=12', 'scheduleId=abc'),
      ),
      isNull,
    );
    expect(ExamInvitation.parse('【笔试邀请】没有链接'), isNull);
    expect(ExamInvitation.parse('普通聊天消息'), isNull);
  });
}
