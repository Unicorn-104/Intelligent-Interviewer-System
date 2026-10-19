import 'dart:convert';

import 'package:flutter/material.dart';

import 'api/assistant_api.dart';
import 'api/interview_room_api.dart';
import 'api/jd_api.dart';
import 'api/jobs_api.dart';
import 'api/message_api.dart';
import 'api/notification_api.dart';
import 'api/offer_api.dart';
import 'api/practice_api.dart';
import 'api/review_api.dart';
import 'api/schedule_api.dart';
import 'api/screening_api.dart';
import 'api/survey_api.dart';
import 'api/talent_api.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';

/// P7 联调诊断入口（新增测试页，不动 features/ 页面）。
///
/// 运行方式（DEV_TOKEN 为后端登录令牌，有效期 30 分钟）：
///   flutter run -t lib/p7_pilot_main.dart -d emulator-5554 \
///     --dart-define=DEV_TOKEN=你的登录令牌
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const P7PilotApp());
}

class P7PilotApp extends StatelessWidget {
  const P7PilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P7 联调诊断',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const P7PilotPage(),
    );
  }
}

class P7PilotPage extends StatefulWidget {
  const P7PilotPage({super.key});

  @override
  State<P7PilotPage> createState() => _P7PilotPageState();
}

class _P7PilotPageState extends State<P7PilotPage> {
  String _result = '尚未发起请求';
  bool _busy = false;

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _result = '请求中…';
    });
    try {
      final text = await action();
      setState(() => _result = text);
    } catch (e) {
      setState(() => _result = '异常：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _json(Object? data) async =>
      const JsonEncoder.withIndent('  ').convert(data);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('P7 联调诊断')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('编译 baseUrl: ${AppConfig.apiBaseUrl}',
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Text('JD 画像（P7 试点）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _testButton('jd.getJdProfile(1)', () async {
            final data = await getJdProfile(1);
            return _json(data);
          }),
          _testButton('jd.parseJdProfile(2)', () async {
            final data = await parseJdProfile(
              positionId: 2,
              jdText: '前端开发工程师，本科以上，3年经验，熟悉 Vue、TypeScript，有责任心',
            );
            return _json(data);
          }),
          const SizedBox(height: 16),
          Text('第 1 批：岗位 + 人才库', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _testButton('jobs.listJobs()', () async {
            final rows = await listJobs(pageNum: 1, pageSize: 5);
            return '共 ${rows.length} 条\n${_json(rows)}';
          }),
          _testButton('jobs.getJobDetail(1) + listDepartments()', () async {
            final detail = await getJobDetail(1);
            final depts = await listDepartments();
            return '${_json(detail)}\n--- 部门 ---\n${_json(depts)}';
          }),
          _testButton('talent.searchTalentPool(keyword=Java)', () async {
            final rows = await searchTalentPool(keyword: 'Java', pageSize: 5);
            return '共 ${rows.length} 条\n${_json(rows)}';
          }),
          _testButton('talent.getTalentParsedResume(1)', () async {
            final data = await getTalentParsedResume(1);
            return _json(data);
          }),
          const SizedBox(height: 16),
          Text('第 2 批：初筛 + 调度', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _testButton('screening.listScreeningTasks()', () async {
            final rows = await listScreeningTasks(pageSize: 10);
            return '共 ${rows.length} 个任务\n${_json(rows)}';
          }),
          _testButton('schedule.listInterviews()', () async {
            final rows = await listInterviews(pageSize: 10);
            return '共 ${rows.length} 场面试\n${_json(rows)}';
          }),
          _testButton('schedule.getInterviewerAvailability(1)', () async {
            final rows = await getInterviewerAvailability(1);
            return '共 ${rows.length} 个时段\n${_json(rows)}';
          }),
          const SizedBox(height: 16),
          Text('第 3 批：会议会话', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _testButton('room.getStoragePolicy()', () async {
            final data = await getStoragePolicy();
            return _json(data);
          }),
          _testButton('room.listRecordings()', () async {
            final rows = await listRecordings();
            return '共 ${rows.length} 条\n${_json(rows)}';
          }),
          const SizedBox(height: 16),
          Text('第 4 批：终审 + Offer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _testButton('review.listPendingReviews()', () async {
            final rows = await listPendingReviews();
            return '共 ${rows.length} 条\n${_json(rows)}';
          }),
          _testButton('offer.listOffers()', () async {
            final rows = await listOffers();
            return '共 ${rows.length} 条\n${_json(rows)}';
          }),
          const SizedBox(height: 16),
          Text('第 5 批：实操/通知/调研', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _testButton('practice.getPracticePreloadStatus(1)', () async {
            final data = await getPracticePreloadStatus(1);
            return _json(data);
          }),
          _testButton('notification.listNotificationTemplates() + stats()', () async {
            final templates = await listNotificationTemplates();
            final stats = await getNotificationStats();
            return '模板 ${templates.length} 个\n${_json(stats)}';
          }),
          _testButton('survey.getSurveyResults() + templates()', () async {
            final results = await getSurveyResults();
            final templates = await getSurveyTemplates();
            return '${_json(results)}\n--- 模板 ---\n${_json(templates)}';
          }),
          const SizedBox(height: 16),
          Text('第 6 批：消息/公告/助手', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _testButton('message.listImSessions() + unread + 公告', () async {
            final sessions = await listImSessions();
            final unread = await getImUnreadCount();
            final notices = await listTopNotices();
            return '会话 ${sessions.length} 个，未读 $unread\n${_json(notices)}';
          }),
          _testButton('assistant.getAssistantHelpArticles()', () async {
            final rows = await getAssistantHelpArticles();
            return '共 ${rows.length} 篇\n${_json(rows)}';
          }),
          const SizedBox(height: 20),
          Text('结果：', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              _result,
              style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testButton(String label, Future<String> Function() action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.tonal(
        onPressed: _busy ? null : () => _run(action),
        child: Text(label),
      ),
    );
  }
}
