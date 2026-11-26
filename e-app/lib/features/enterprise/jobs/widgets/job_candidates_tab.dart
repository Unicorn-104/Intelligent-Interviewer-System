import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../../talent/widgets/talent_status_badge.dart';
import '../../talent/widgets/talent_candidate_actions.dart';
import '../../talent/widgets/talent_filter_icon.dart';
import '../../talent/data/talent_detail_data_source.dart';
import '../../talent/models/talent_detail_view_data.dart';
import '../models/job_detail_view_data.dart';

class JobCandidatesTab extends StatefulWidget {
  const JobCandidatesTab({
    super.key,
    required this.detail,
    required this.scores,
    required this.screening,
    required this.onReloadDetail,
    required this.onReloadScores,
    required this.onScreen,
    required this.onOpen,
    this.beforeInvite,
    this.examStageId,
    this.onSendExam,
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
  final ValueChanged<Map<String, dynamic>> onOpen;
  final Future<bool> Function(Map<String, dynamic> candidate)? beforeInvite;
  final int? examStageId;
  final Future<void> Function(Map<String, dynamic> candidate)? onSendExam;
  final Future<Map<String, dynamic>> Function(int) loadResume;
  final TalentDetailDataSource actionsSource;
  final TalentJobContext job;
  final int workflowRevision;

  @override
  State<JobCandidatesTab> createState() => _JobCandidatesTabState();
}

class _JobCandidatesTabState extends State<JobCandidatesTab> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _statusFilter;
  String? _stageFilter;
  bool? _scoredFilter;
  bool _sortDescending = true;

  bool get _hasFilters =>
      _statusFilter != null || _stageFilter != null || _scoredFilter != null;

  JobSectionState<JobDetailViewData> get detail => widget.detail;
  JobSectionState<List<Map<String, dynamic>>> get scores => widget.scores;
  bool get screening => widget.screening;
  Future<void> Function() get onReloadDetail => widget.onReloadDetail;
  Future<void> Function() get onReloadScores => widget.onReloadScores;
  VoidCallback get onScreen => widget.onScreen;
  ValueChanged<Map<String, dynamic>> get onOpen => widget.onOpen;
  Future<Map<String, dynamic>> Function(int) get loadResume =>
      widget.loadResume;
  Future<bool> Function(Map<String, dynamic> candidate)? get beforeInvite =>
      widget.beforeInvite;
  int? get examStageId => widget.examStageId;
  Future<void> Function(Map<String, dynamic> candidate)? get onSendExam =>
      widget.onSendExam;
  TalentDetailDataSource get actionsSource => widget.actionsSource;
  TalentJobContext get job => widget.job;
  int get workflowRevision => widget.workflowRevision;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _candidateText(Map<String, dynamic> candidate) => [
    candidate['candidateName'],
    candidate['nickName'],
    candidate['name'],
    candidate['realName'],
    candidate['phone'],
    candidate['statusLabel'],
    candidate['currentStage'],
    candidate['desiredPosition'],
  ].whereType<Object>().join(' ').toLowerCase();

  bool _matches(JobRankedCandidate row) {
    final query = _query.trim().toLowerCase();
    final status = '${row.candidate['statusLabel'] ?? ''}'.trim();
    final stage = '${row.candidate['currentStage'] ?? ''}'.trim();
    final hasScore = row.resultScore != null || row.score != null;
    return (query.isEmpty || _candidateText(row.candidate).contains(query)) &&
        (_statusFilter == null || status == _statusFilter) &&
        (_stageFilter == null || stage == _stageFilter) &&
        (_scoredFilter == null || hasScore == _scoredFilter);
  }

  int _compareScore(JobRankedCandidate a, JobRankedCandidate b) {
    final left = a.resultScore ?? a.score;
    final right = b.resultScore ?? b.score;
    if (left == null && right != null) return 1;
    if (left != null && right == null) return -1;
    if (left == null && right == null) {
      return a.originalIndex.compareTo(b.originalIndex);
    }
    final comparison = right!.compareTo(left!);
    return _sortDescending ? comparison : -comparison;
  }

  Future<void> _chooseFilters(List<JobRankedCandidate> ranked) async {
    final statuses =
        ranked
            .map((row) => '${row.candidate['statusLabel'] ?? ''}'.trim())
            .where((status) => status.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final stages =
        ranked
            .map((row) => '${row.candidate['currentStage'] ?? ''}'.trim())
            .where((stage) => stage.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    var status = _statusFilter;
    var stage = _stageFilter;
    var scored = _scoredFilter;
    final selected = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              const Text(
                '筛选求职者',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _filterGroup(
                '求职状态',
                ['全部', ...statuses],
                status ?? '全部',
                (value) =>
                    setSheetState(() => status = value == '全部' ? null : value),
              ),
              if (stages.isNotEmpty) ...[
                const SizedBox(height: 12),
                _filterGroup(
                  '招聘阶段',
                  ['全部', ...stages],
                  stage ?? '全部',
                  (value) =>
                      setSheetState(() => stage = value == '全部' ? null : value),
                ),
              ],
              const SizedBox(height: 12),
              _filterGroup(
                'AI评分',
                const ['全部', '已有评分', '待分析'],
                scored == null ? '全部' : (scored! ? '已有评分' : '待分析'),
                (value) => setSheetState(
                  () => scored = value == '全部' ? null : value == '已有评分',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheetState(() {
                        status = null;
                        stage = null;
                        scored = null;
                      }),
                      child: const Text('重置'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, {
                        'status': status,
                        'stage': stage,
                        'scored': scored,
                      }),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _statusFilter = selected['status'] as String?;
      _stageFilter = selected['stage'] as String?;
      _scoredFilter = selected['scored'] as bool?;
    });
  }

  Widget _filterGroup(
    String title,
    List<String> options,
    String selected,
    ValueChanged<String> onSelected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option),
              selected: option == selected,
              onSelected: (_) => onSelected(option),
              selectedColor: AppColors.primarySoft,
              labelStyle: TextStyle(
                color: option == selected
                    ? AppColors.interactive
                    : AppColors.bodySoft,
              ),
            ),
        ],
      ),
    ],
  );

  String _detailMessage(String message) {
    final text = message.trim();
    if (text.contains('网络异常') ||
        text.contains('connection') ||
        text.contains('XMLHttpRequest')) {
      return '请检查网络后重试';
    }
    return text.length > 24 ? '加载失败，请稍后重试' : text;
  }

  @override
  Widget build(BuildContext context) {
    if (detail.loading) {
      return const SkeletonList(rows: 4);
    }
    if (detail.error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '求职者加载失败',
        message: _detailMessage(detail.error!),
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
    final ranked = rankJobCandidates(data.candidates, scores.data ?? const []);
    final filtered = ranked.where(_matches).toList()..sort(_compareScore);
    final hasScores = filtered.any((row) => row.resultScore != null);
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '搜索姓名 / 求职方向',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('job-candidate-filter'),
                tooltip: '筛选',
                onPressed: () => _chooseFilters(ranked),
                icon: TalentFilterIcon(
                  color: _hasFilters ? AppColors.interactive : AppColors.ink,
                  size: 25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: const ValueKey('job-candidate-sort'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () =>
                      setState(() => _sortDescending = !_sortDescending),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 5, 7, 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'AI\u8bc4\u5206',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_drop_up,
                              size: 17,
                              color: _sortDescending
                                  ? AppColors.interactive.withValues(alpha: .28)
                                  : AppColors.interactive,
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 17,
                              color: _sortDescending
                                  ? AppColors.interactive
                                  : AppColors.interactive.withValues(
                                      alpha: .28,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    key: const Key('job-rescreen'),
                    onPressed: screening || scores.loading ? null : onScreen,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: Text(
                      screening
                          ? '\u5206\u6790\u4e2d\u2026'
                          : '\u4eba\u5c97\u5339\u914d',
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (scores.loading)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          if (!scores.loading && !hasScores) ...[
            const SizedBox(height: 12),
            const Text('暂无评分数据', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < filtered.length; index++) ...[
            JobCandidateCard(
              key: ValueKey(
                'job-candidate-${filtered[index].candidate['talId'] ?? index}',
              ),
              candidate: filtered[index].candidate,
              loadResume: loadResume,
              actionsSource: actionsSource,
              job: job,
              workflowRevision: workflowRevision,
              score: filtered[index].score,
              beforeInvite: beforeInvite == null
                  ? null
                  : () => beforeInvite!(filtered[index].candidate),
              examStageId: examStageId,
              onSendExam: onSendExam == null
                  ? null
                  : () => onSendExam!(filtered[index].candidate),
              onOpen: () => onOpen(filtered[index].candidate),
            ),
            // 紧凑化：卡片间距由 12 略减到 10，连续排列更密集但仍可区分
            const SizedBox(height: 10),
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
    this.beforeInvite,
    this.examStageId,
    this.onSendExam,
    required this.loadResume,
    required this.actionsSource,
    required this.job,
    this.workflowRevision = 0,
  });
  final Map<String, dynamic> candidate;
  final num? score;
  final VoidCallback onOpen;
  final Future<bool> Function()? beforeInvite;
  final int? examStageId;
  final VoidCallback? onSendExam;
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
    // 投递ID或人才ID变化都需重新加载，避免卡片复用后展示上一位候选人的简历
    if (oldWidget.candidate['applicationId'] !=
            widget.candidate['applicationId'] ||
        oldWidget.candidate['talId'] != widget.candidate['talId']) {
      _resume = _loadResume();
    }
  }

  Future<Map<String, dynamic>> _loadResume() async {
    // 岗位投递场景优先按 applicationId 读取企业快照，不读 C-App 当前简历
    final applicationId = jobPositiveId(widget.candidate['applicationId']);
    if (applicationId != null) {
      return widget.actionsSource.loadApplicationResume(applicationId);
    }
    // 无投递ID（历史/异常数据）保留 talId 口径兜底
    return _id == null ? <String, dynamic>{} : await widget.loadResume(_id!);
  }

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

  bool get _isExamStage {
    final type = int.tryParse('${widget.candidate['currentStageType']}');
    if (type != null) return type == 1;
    final currentStageId = int.tryParse('${widget.candidate['currentStageId']}');
    return widget.examStageId != null && currentStageId == widget.examStageId;
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    // 轻微柔和阴影：仅 1 级高度，阴影用低透明度深蓝，避免过重
    elevation: 1,
    shadowColor: const Color(0x141A3C6E),
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 44),
          child: Padding(
            // 紧凑化：卡片内边距由 12 收紧到 10
            padding: const EdgeInsets.all(10),
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
                  // 求职者真实 userId，用于「打招呼」直接进入聊天页
                  peerId: jobPositiveId(widget.candidate['userId']),
                  name: jobValue(widget.candidate['name'], fallback: '姓名未填写'),
                  source: widget.actionsSource,
                  appStatusCode: widget.candidate['statusCode'],
                  beforeInvite: widget.beforeInvite,
                  examStage: _isExamStage,
                  onSendExam: widget.onSendExam,
                  job: TalentJobContext(
                    positionId: widget.job.positionId,
                    title: widget.job.title,
                    currentStage: widget.candidate['currentStage']?.toString(),
                    applicationId: jobPositiveId(
                      widget.candidate['applicationId'],
                    ),
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
            // 右侧展开区背景改用白色（与卡片同色），不再显示浅灰竖条，仅保留 chevron 图标
            color: AppColors.canvas,
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
        // 紧凑化：评分圆环由 56 缩小到 48，与设计稿右上角圆环占比一致
        dimension: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: score == null ? 0 : score!.clamp(0, 100) / 100,
                // 环条随尺寸略收细，避免小圆环下显得过粗
                strokeWidth: 3.5,
                backgroundColor: AppColors.hairline,
                color: color,
              ),
            ),
            Padding(
              // 内边距同步收小，保证内容居中且不压环
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // 纵向排列：分数在上、极小「ai评分」提示在下，整体随圆环自适应缩放
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score?.toStringAsFixed(1) ?? '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        // 字号随圆环缩小，保持视觉平衡
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // 数字下方极小提示文字，标明此处为 AI 评分（无评分「—」时同样展示）
                    const Text(
                      'ai评分',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 7,
                        height: 1,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
