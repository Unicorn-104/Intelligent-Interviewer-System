import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../../talent/widgets/talent_status_badge.dart';
import '../../talent/widgets/talent_candidate_actions.dart';
import '../../talent/data/talent_detail_data_source.dart';
import '../../talent/models/talent_detail_view_data.dart';
import '../models/job_detail_view_data.dart';

class JobCandidatesTab extends StatelessWidget {
  const JobCandidatesTab({
    super.key,
    required this.detail,
    required this.scores,
    required this.screening,
    required this.onReloadDetail,
    required this.onReloadScores,
    required this.onScreen,
    this.onFullScreen,
    required this.onOpen,
    required this.loadResume,
    required this.actionsSource,
    required this.job,
    this.workflowRevision = 0,
  });
  final JobSectionState<JobDetailViewData> detail;
  final JobSectionState<List<Map<String, dynamic>>> scores;
  final bool screening;
  final Future<void> Function() onReloadDetail;
  final Future<void> Function() onReloadScores;
  final VoidCallback onScreen;
  final VoidCallback? onFullScreen;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final Future<Map<String, dynamic>> Function(int) loadResume;
  final TalentDetailDataSource actionsSource;
  final TalentJobContext job;
  final int workflowRevision;

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
        key: const PageStorageKey('job-candidates-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: AppColors.interactive,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    key: const Key('job-rescreen'),
                    onTap: screening || scores.loading ? null : onScreen,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            screening ? '分析中…' : '增量分析',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withValues(alpha: .45),
                  ),
                  PopupMenuButton<String>(
                    key: const Key('job-analysis-menu'),
                    tooltip: '选择分析方式',
                    enabled: !screening && !scores.loading,
                    constraints: const BoxConstraints(minWidth: 210),
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    onSelected: (mode) {
                      if (mode == 'full') {
                        onFullScreen?.call();
                      } else {
                        onScreen();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'incremental',
                        child: Text('增量分析（优先读取，补充新增）'),
                      ),
                      PopupMenuItem(
                        value: 'full',
                        enabled: onFullScreen != null,
                        child: const Text('全量分析（耗时较长）'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '进入页面自动读取已有结果；增量分析会先刷新，只有缺少分析的求职者才调用模型。简历或岗位更新后可选择全量分析。',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
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
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < ranked.length; index++) ...[
            JobCandidateCard(
              key: ValueKey(
                'job-candidate-${ranked[index].candidate['talId'] ?? index}',
              ),
              candidate: ranked[index].candidate,
              loadResume: loadResume,
              actionsSource: actionsSource,
              job: job,
              workflowRevision: workflowRevision,
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

class JobCandidateCard extends StatefulWidget {
  const JobCandidateCard({
    super.key,
    required this.candidate,
    required this.score,
    required this.onOpen,
    required this.loadResume,
    required this.actionsSource,
    required this.job,
    this.workflowRevision = 0,
  });
  final Map<String, dynamic> candidate;
  final num? score;
  final VoidCallback onOpen;
  final Future<Map<String, dynamic>> Function(int) loadResume;
  final TalentDetailDataSource actionsSource;
  final TalentJobContext job;
  final int workflowRevision;

  @override
  State<JobCandidateCard> createState() => _JobCandidateCardState();
}

class _JobCandidateCardState extends State<JobCandidateCard> {
  late Future<Map<String, dynamic>> _resume;
  int? get _id => jobPositiveId(widget.candidate['talId']);

  @override
  void initState() {
    super.initState();
    _resume = _loadResume();
  }

  @override
  void didUpdateWidget(covariant JobCandidateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate['talId'] != widget.candidate['talId']) {
      _resume = _loadResume();
    }
  }

  Future<Map<String, dynamic>> _loadResume() async =>
      _id == null ? <String, dynamic>{} : await widget.loadResume(_id!);

  Widget _badge(String text, Color color) => Container(
    constraints: const BoxConstraints(minHeight: 22),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 11)),
  );

  String _education(Map<String, dynamic>? resume) {
    final raw = resume?['educationList'];
    if (raw is! List) return '学校未填写 · 学历未填写';
    // 与完整资料页一致，使用接口按结束时间倒序返回的最近一条教育记录。
    final entries = raw.whereType<Map>();
    if (entries.isEmpty) return '学校未填写 · 学历未填写';
    final education = entries.first;
    return '${jobValue(education['school'], fallback: '学校未填写')} · ${talentDegree(education['degree'])}';
  }

  Widget _educationLine() => FutureBuilder<Map<String, dynamic>>(
    future: _resume,
    builder: (context, snapshot) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            snapshot.connectionState != ConnectionState.done
                ? '教育信息加载中…'
                : snapshot.hasError
                ? '教育信息暂不可用'
                : _education(snapshot.data),
            key: ValueKey('job-candidate-education-$_id'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        if (snapshot.hasError)
          IconButton(
            key: ValueKey('job-candidate-education-retry-$_id'),
            tooltip: '重试教育信息',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () {
              final request = _loadResume();
              setState(() {
                _resume = request;
              });
            },
          ),
      ],
    ),
  );

  Widget _identity() {
    final status = jobValue(widget.candidate['statusLabel'], fallback: '状态未提供');
    final stage = jobValue(widget.candidate['currentStage'], fallback: '');
    final (_, statusColor) = TalentStatusBadge.visualFor(
      widget.candidate['statusCode'],
    );
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Text(
              jobValue(widget.candidate['name'], fallback: '姓名未填写'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _badge(status, statusColor),
          if (stage.isNotEmpty && stage != status)
            _badge(stage, AppColors.interactive),
        ],
      ),
    );
  }

  Widget _scoring() => _CandidateScore(score: widget.score);

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 44),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _identity(),
                          const SizedBox(height: 4),
                          _educationLine(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _scoring(),
                  ],
                ),
                const SizedBox(height: 4),
                TalentCandidateActions(
                  keyPrefix: 'job-candidate-$_id',
                  workflowRevision: widget.workflowRevision,
                  candidateId: _id,
                  name: jobValue(widget.candidate['name'], fallback: '姓名未填写'),
                  source: widget.actionsSource,
                  job: TalentJobContext(
                    positionId: widget.job.positionId,
                    title: widget.job.title,
                    currentStage: widget.candidate['currentStage']?.toString(),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 44,
          child: Material(
            color: AppColors.hairline,
            child: InkWell(
              key: ValueKey('job-candidate-expand-$_id'),
              onTap: _id == null ? null : widget.onOpen,
              child: Semantics(
                button: true,
                enabled: _id != null,
                label: _id == null ? '候选人ID缺失，无法查看详情' : '展开求职者详细信息',
                child: const Center(
                  child: Icon(
                    Icons.chevron_right,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CandidateScore extends StatelessWidget {
  const _CandidateScore({required this.score});
  final num? score;

  @override
  Widget build(BuildContext context) {
    final color = score == null
        ? AppColors.textMuted
        : score! >= 85
        ? AppColors.success
        : score! >= 70
        ? AppColors.interactive
        : AppColors.warning;
    return Semantics(
      label: '通用评分：${score ?? '暂无评分'}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: score == null ? 0 : score!.clamp(0, 100) / 100,
                strokeWidth: 4,
                backgroundColor: AppColors.hairline,
                color: color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  score?.toStringAsFixed(1) ?? '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
