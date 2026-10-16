import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../models/job_detail_view_data.dart';
import 'job_candidates_tab.dart';

class JobAiScreeningTab extends StatelessWidget {
  const JobAiScreeningTab({
    super.key,
    required this.detail,
    required this.scores,
    required this.screening,
    required this.onReloadDetail,
    required this.onReloadScores,
    required this.onScreen,
    required this.onOpen,
  });
  final JobSectionState<JobDetailViewData> detail;
  final JobSectionState<List<Map<String, dynamic>>> scores;
  final bool screening;
  final Future<void> Function() onReloadDetail;
  final Future<void> Function() onReloadScores;
  final VoidCallback onScreen;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    if (detail.loading) {
      return const SkeletonList(rows: 4);
    }
    if (detail.error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '求职者加载失败',
        message: detail.error!,
        onAction: onReloadDetail,
      );
    }
    final data = detail.data;
    if (data == null || data.candidates.isEmpty) {
      return PageMessage(
        icon: Icons.people_outline,
        title: '暂无求职者',
        message: '有求职者投递后，可查看同批候选人的通用评分',
        actionLabel: '刷新',
        onAction: onReloadDetail,
      );
    }
    if (data.tooManyCandidates) {
      return PageMessage(
        icon: Icons.people_outline,
        title: '数据量过大，暂无法完整展示',
        message: '不使用筛选接口替换或截断详情候选人集合',
        onAction: onReloadDetail,
      );
    }
    final ranked = rankJobCandidates(
      data.candidates,
      scores.error == null ? scores.data ?? const [] : const [],
    );
    final hasScores = ranked.any((row) => row.resultScore != null);
    return RefreshIndicator(
      onRefresh: () async {
        await onReloadDetail();
        await onReloadScores();
      },
      child: ListView(
        key: const PageStorageKey('job-ai-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: AppColors.accentPurple),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '同批候选人的另一种查看方式',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '通用评分，非岗位维度',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const Text(
            'AI 结果仅供参考',
            style: TextStyle(color: AppColors.accentPurple),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('job-rescreen'),
              onPressed: screening ? null : onScreen,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(screening ? '正在筛选…' : '重新筛选'),
            ),
          ),
          if (scores.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (scores.error != null) ...[
            const SizedBox(height: 8),
            Text(scores.error!, style: const TextStyle(color: AppColors.error)),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('job-scores-retry'),
                onPressed: scores.loading ? null : onReloadScores,
                child: const Text('加载筛选结果失败，重试'),
              ),
            ),
          ] else if (!scores.loading && !hasScores) ...[
            const SizedBox(height: 12),
            const Text('暂无评分数据', style: TextStyle(fontWeight: FontWeight.w600)),
            const Text(
              '未找到该岗位的筛选评分，下方保留同批求职者及详情接口提供的通用评分。',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onReloadScores,
                child: const Text('刷新评分'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < ranked.length; index++) ...[
            JobCandidateCard(
              key: ValueKey('job-ai-candidate-$index'),
              candidate: ranked[index].candidate,
              score: ranked[index].score,
              onOpen: () => onOpen(ranked[index].candidate),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
