import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'data/talent_detail_data_source.dart';
import 'models/talent_detail_view_data.dart';
import 'talent_resume_pdf_page.dart';
import 'widgets/talent_candidate_actions.dart';
import 'widgets/talent_interview_section.dart';
import 'widgets/talent_manual_score_section.dart';
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
    this.chatPageBuilder,
  });
  final Map<String, dynamic> talent;
  final TalentJobContext? jobContext;
  final TalentDetailDataSource source;

  /// 「打招呼」聊天页构建器（可注入以隔离网络，测试用）；透传给候选人操作组件。
  final Widget Function(Map<String, dynamic> session)? chatPageBuilder;
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

  /// 不依赖 talId 的分区加载：投递场景以 applicationId 自行取数，复用请求序号与状态管理。
  Future<void> _loadWith<T>(
    TalentSectionState<T> section,
    Future<T?> Function() fetch,
  ) async {
    final request = ++section.request;
    setState(() {
      section.loading = true;
      section.error = null;
    });
    try {
      final data = await fetch();
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

  /// 简历加载：有 applicationId 走投递级企业快照，无 applicationId（人才库）保留 talId 口径。
  Future<void> _loadResume() async {
    final applicationId = widget.jobContext?.applicationId;
    if (applicationId == null) {
      return _load(_resume, widget.source.loadResume);
    }
    return _loadWith(
      _resume,
      () => widget.source.loadApplicationResume(applicationId),
    );
  }

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
            // 求职者真实 userId，用于「打招呼」直接进入聊天页
            peerId: talentId(detail?['userId']),
            job: widget.jobContext == null
                ? null
                : TalentJobContext(
                    positionId: widget.jobContext!.positionId,
                    title: widget.jobContext!.title,
                    currentStage: stage,
                    applicationId: widget.jobContext!.applicationId,
                  ),
            onInvited: () => setState(() => _interviewRevision++),
            chatPageBuilder: widget.chatPageBuilder,
          ),
        ],
      ),
    );
  }

  /// 简历附件入口，按后端字段三态展示：
  /// 1) hasOriginalPdf：存在可读取的企业 PDF，可点击查看；
  /// 2) 快照无 PDF 但源简历有文件（sourceHasFile）：置灰「简历附件暂不可用」；
  /// 3) 源简历也无文件：置灰「未提供简历附件」。
  Widget _originalResumeAction(BuildContext context) {
    final id = _id;
    final hasOriginalPdf = _resume.data?['hasOriginalPdf'] == true;
    final sourceHasFile = _resume.data?['sourceHasFile'] == true;
    // 文件名缺失时使用默认展示名 resume.pdf
    final rawName = _resume.data?['fileName'];
    final displayName = rawName is String && rawName.isNotEmpty
        ? rawName
        : 'resume.pdf';

    // 态 1：存在可读取的企业 PDF，保持可点击入口
    if (hasOriginalPdf && id != null) {
      // 投递场景以 applicationId 读取企业 PDF；为 null（人才库）时 PDF 页内部走 talId 默认加载
      final applicationId = widget.jobContext?.applicationId;
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
                builder: (_) => TalentResumePdfPage(
                  talentId: id,
                  fileName: displayName,
                  loader: applicationId == null
                      ? null
                      : () => widget.source.loadApplicationPdfBytes(applicationId),
                ),
              ),
            );
          },
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('原始简历'),
        ),
      );
    }

    // 态 2/3：无可读取 PDF，统一置灰、不可点击；文案区分历史快照缺失与求职者未上传
    final String unavailableLabel =
        sourceHasFile ? '简历附件暂不可用' : '未提供简历附件';
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.muted,
          side: BorderSide(color: AppColors.muted),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
        // onPressed 置 null：按钮进入禁用态，不响应点击
        onPressed: null,
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
        label: Text(unavailableLabel),
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
          TalentManualScoreSection(
            result: widget.jobContext == null
                ? _report.data
                : _match.data?.result,
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
