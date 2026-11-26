import 'package:enterprise_recruiter/features/enterprise/conference/interview_modes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('清理历史面试卡片中的无AI纯人工后缀', () {
    expect(cleanInterviewTitle('HR 综合面试·无AI纯人工'), 'HR 综合面试');
    expect(cleanInterviewTitle('HR 综合面试·无 AI · 纯人工'), 'HR 综合面试');
    expect(cleanInterviewTitle('HR 综合面试 · 无AI纯人工'), 'HR 综合面试');
    expect(
      cleanInterviewTitle('【面试邀请·HR 综合面试·无AI纯人工】杭州云智科技有限公司'),
      '【面试邀请·HR 综合面试】杭州云智科技有限公司',
    );
    expect(cleanInterviewTitle('无AI纯人工'), '');
    expect(cleanInterviewTitle('AI技术面试·AI+单面试官'), 'AI技术面试·AI+单面试官');
  });

  test('纯人工面试邀请标签不再拼接无AI纯人工', () {
    expect(interviewInviteTag('HR 综合面试', 4), '·HR 综合面试');
    expect(interviewInviteTag('HR 综合面试·无AI纯人工', 4), '·HR 综合面试');
    expect(interviewInviteTag('', 4), '·面试');
    expect(interviewInviteTag('AI技术面试', 2), '·AI技术面试·AI+单面试官');
  });
}
