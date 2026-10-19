import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../models/job_detail_view_data.dart';

class JobCandidatesTab extends StatelessWidget {
  const JobCandidatesTab({
    super.key,
    required this.state,
    required this.onReload,
    required this.onOpen,
  });
  final JobSectionState<JobDetailViewData> state;
  final Future<void> Function() onReload;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const SkeletonList(rows: 4);
    }
    if (state.error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '求职者加载失败',
        message: state.error!,
        onAction: onReload,
      );
    }
    final detail = state.data;
    if (detail == null || detail.candidates.isEmpty) {
      return PageMessage(
        icon: Icons.people_outline,
        title: '暂无求职者',
        message: '该岗位暂无投递候选人',
        actionLabel: '刷新',
        onAction: onReload,
      );
    }
    if (detail.tooManyCandidates) {
      return PageMessage(
        icon: Icons.people_outline,
        title: '数据量过大，暂无法完整展示',
        message: '详情接口没有候选人分页参数，不截断名单',
        onAction: onReload,
      );
    }
    return RefreshIndicator(
      onRefresh: onReload,
      child: ListView.separated(
        key: const PageStorageKey('job-candidates-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: detail.candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final candidate = detail.candidates[index];
          return JobCandidateCard(
            key: ValueKey('job-candidate-$index'),
            candidate: candidate,
            score: jobScore(candidate['matchScore']),
            onOpen: () => onOpen(candidate),
          );
        },
      ),
    );
  }
}

class JobCandidateCard extends StatelessWidget {
  const JobCandidateCard({
    super.key,
    required this.candidate,
    required this.score,
    required this.onOpen,
  });
  final Map<String, dynamic> candidate;
  final num? score;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final validId = jobPositiveId(candidate['talId']) != null;
    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(jobValue(candidate['name'], fallback: '姓名未填写')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('阶段：${jobValue(candidate['currentStage'], fallback: '未提供')}'),
            Text('状态：${jobValue(candidate['statusLabel'], fallback: '未提供')}'),
            Text(
              '通用评分：${score ?? '暂无评分'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (!validId) const Text('候选人ID缺失，无法查看详情'),
          ],
        ),
        trailing: validId ? const Icon(Icons.chevron_right) : null,
        onTap: validId ? onOpen : null,
      ),
    );
  }
}
