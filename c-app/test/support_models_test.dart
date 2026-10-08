import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/support/domain/support_models.dart';

void main() {
  test('parses help center articles from the app support response', () {
    final article = HelpArticle.fromJson({
      'articleId': 3,
      'category': '简历管理',
      'title': '如何设置默认简历？',
      'content': '进入简历管理后设置默认简历。',
      'keywords': '默认简历,投递',
      'updatedAt': '2026-09-30 09:00:00',
    });

    expect(article.articleId, 3);
    expect(article.category, '简历管理');
    expect(article.updatedAt.year, 2026);
  });

  test('parses feedback labels and replies', () {
    final feedback = FeedbackRecord.fromJson({
      'feedbackId': '9',
      'type': 2,
      'subject': '页面异常',
      'description': '点击后无法加载',
      'status': 2,
      'reply': '问题已修复',
      'createdAt': '2026-09-30 10:30:00',
    });

    expect(feedback.feedbackId, 9);
    expect(feedback.typeLabel, 'Bug反馈');
    expect(feedback.statusLabel, '已处理');
    expect(feedback.reply, '问题已修复');
  });
}
