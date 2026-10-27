import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'data/talent_detail_data_source.dart';
import 'models/talent_detail_view_data.dart';
import 'talent_resume_pdf_page.dart';
import 'widgets/talent_candidate_actions.dart';
import 'widgets/talent_interview_section.dart';
import 'widgets/talent_match_analysis_section.dart';
import 'widgets/talent_recommendation_section.dart';
import 'widgets/talent_resume_section.dart';
import 'widgets/talent_status_badge.dart';

class TalentDetailPage extends StatefulWidget {
  const TalentDetailPage({
    super.key,
    required this.talent,
    this.jobContext,
    this.source = const TalentDetailDataSource(),
  });
  final Map<String, dynamic> talent;
  final TalentJobContext? jobContext;
  final TalentDetailDataSource source;
  @override
  State<TalentDetailPage> createState() => _TalentDetailPageState();
}

class _TalentDetailPageState extends State<TalentDetailPage> {
  final _detail = TalentSectionState<Map<String, dynamic>>();
  final _resume = TalentSectionState<Map<String, dynamic>>();
  final _match = TalentSectionState<TalentMatchData>();
  final _report = TalentSectionState<Map<String, dynamic>>();
  int _interviewRevision = 0;
  int? get _id => talentId(widget.talent['talentId']);
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _load<T>(
    TalentSectionState<T> section,
    Future<T?> Function(int) fetch,
  ) async {
    final request = ++section.request;
    setState(() {
      section.loading = true;
      section.error = null;
    });
    try {
      final id = _id;
      if (id == null) {
        throw const FormatException('候选人数据缺少 ID');
      }
      final data = await fetch(id);
      if (!mounted || request != section.request) {
        return;
      }
      setState(() => section.data = data);
    } catch (error) {
      if (mounted && request == section.request) {
        setState(() => section.error = talentError(error));
      }
    } finally {
      if (mounted && request == section.request) {
        setState(() => section.loading = false);
      }
    }
  }

  Future<void> _loadDetail() => _load(_detail, widget.source.loadDetail);
  Future<void> _loadResume() => _load(_resume, widget.source.loadResume);
  Future<void> _loadReport() => _load(_report, widget.source.loadReport);
  Future<void> _loadMatch() async {
    final job = widget.jobContext;
    if (job == null) {
      setState(() => _match.loading = false);
      return;
    }
    await _load(_match, (id) => widget.source.loadMatch(id, job));
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadDetail(),
      _loadResume(),
      _loadMatch(),
      if (widget.jobContext == null) _loadReport(),
    ]);
  }

  Future<void> _refresh() async {
    setState(() => _interviewRevision++);
    await _loadAll();
  }

  String get _name => talentText(
    _resume.data?['name'] ?? _detail.data?['name'] ?? widget.talent['name'],
    '未知候选人',
  );
  Widget _basic(BuildContext context) {
    final detail = _detail.data;
    final resume = _resume.data;
    final stage = _match.data?.currentStage ?? widget.jobContext?.currentStage;
    return TalentSectionFrame(
      title: '',
      loading: _detail.loading,
      error: _detail.error,
      empty: detail == null || detail.isEmpty,
      emptyText: '暂无候选人详情',
      onRetry: _loadDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  _name.characters.first,
                  style: const TextStyle(
                    color: AppColors.interactive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 5),
                    TalentStatusBadge(status: detail?['status']),
                  ],
                ),
              ),
              _originalResumeAction(context),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.jobContext != null) ...[
            Text(
              widget.jobContext!.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '当前招聘阶段：${talentText(stage, '未提供')}',
              style: const TextStyle(color: AppColors.bodySoft, fontSize: 12),
            ),
            if (_match.error != null)
              const Text(
                '岗位阶段刷新失败，当前显示进入页面时的阶段',
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
          ] else ...[
            const Text(
              '未指定岗位，暂无岗位招聘阶段',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (detail?['currentRound'] != null)
              Text(
                '当前轮次：${detail!['currentRound']}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
          ],
          const SizedBox(height: 8),
          _contact(
            Icons.work_outline,
            '求职方向',
            talentText(resume?['jobDirection'] ?? detail?['jobDirection']),
          ),
          _contact(
            Icons.phone_outlined,
            '手机',
            talentText(resume?['phone'] ?? detail?['phone']),
          ),
          _contact(
            Icons.mail_outline,
            '邮箱',
            talentText(resume?['email'] ?? detail?['email']),
          ),
          const SizedBox(height: 14),
          TalentCandidateActions(
            candidateId: _id,
            workflowRevision: _interviewRevision,
            name: _name,
            source: widget.source,
            job: widget.jobContext == null
                ? null
                : TalentJobContext(
                    positionId: widget.jobContext!.positionId,
                    title: widget.jobContext!.title,
                    currentStage: stage,
                  ),
            onInvited: () => setState(() => _interviewRevision++),
          ),
        ],
      ),
    );
  }

  /// 「原始简历」入口：仅当候选人已保存原始 PDF（解析接口返回 fileName）时展示。
  Widget _originalResumeAction(BuildContext context) {
    final fileName = _resume.data?['fileName'];
    final id = _id;
    if (fileName is! String || fileName.isEmpty || id == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.interactive,
          side: const BorderSide(color: AppColors.interactive),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  TalentResumePdfPage(talentId: id, fileName: fileName),
            ),
          );
        },
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
        label: const Text('原始简历'),
      ),
    );
  }

  Widget _contact(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: label,
          child: Icon(icon, size: 15, color: AppColors.muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: '$label：$value',
            excludeSemantics: true,
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.bodySoft),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        talentText(widget.talent['name'], '候选人详情'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _basic(context),
          TalentResumeSection(state: _resume, onRetry: _loadResume),
          TalentSectionFrame(
            key: const Key('talent-ai-analysis-card'),
            title: 'AI分析结果',
            ai: true,
            onRetry: _loadAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TalentMatchAnalysisSection(
                  detail: _detail,
                  match: _match,
                  fallbackReport: _report,
                  job: widget.jobContext,
                  onDetailRetry: widget.jobContext == null
                      ? _loadReport
                      : _loadDetail,
                  onMatchRetry: _loadMatch,
                  embedded: true,
                ),
                const Divider(
                  height: 24,
                  thickness: 1,
                  color: AppColors.hairline,
                ),
                TalentRecommendationSection(
                  state: widget.jobContext == null
                      ? _report
                      : TalentSectionState<Map<String, dynamic>>(
                          data: _match.data?.result,
                          error: _match.error,
                          loading: _match.loading,
                        ),
                  onRetry: widget.jobContext == null ? _loadReport : _loadMatch,
                  embedded: true,
                ),
              ],
            ),
          ),
          TalentInterviewSection(
            candidateId: _id,
            source: widget.source,
            revision: _interviewRevision,
          ),
        ],
      ),
    ),
  );
}
