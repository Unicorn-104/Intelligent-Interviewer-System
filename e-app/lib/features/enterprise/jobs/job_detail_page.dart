import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';

import '../../../theme/app_theme.dart';
import '../talent/talent_detail_page.dart';
import '../talent/models/talent_detail_view_data.dart';
import 'data/job_detail_data_source.dart';
import 'job_interviews_page.dart';
import 'job_preview_page.dart';
import 'job_publish_page.dart';
import 'models/job_detail_view_data.dart';
import 'widgets/job_basic_info_tab.dart';
import 'widgets/job_candidates_tab.dart';
import 'widgets/job_jd_profile_section.dart';
import 'widgets/job_workflow_section.dart';
import 'widgets/job_workflow_timeline.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({
    super.key,
    required this.job,
    this.initialTab = 0,
    this.source = const JobDetailDataSource(),
    this.candidateBuilder,
  }) : assert(initialTab >= 0 && initialTab < 3);
  final Map<String, dynamic> job;
  final int initialTab;
  final JobDetailDataSource source;
  final Widget Function(Map<String, dynamic>)? candidateBuilder;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _detail = JobSectionState<JobDetailViewData>();
  final _profile = JobSectionState<Map<String, dynamic>>();
  final _workflow = JobSectionState<Map<String, dynamic>>();
  final _scores = JobSectionState<List<Map<String, dynamic>>>(loading: false);
  bool _scoresRequested = false;
  bool _jdExpanded = false;
  bool _workflowExpanded = false;
  bool _parsing = false;
  bool _savingWorkflow = false;
  bool _editingWorkflow = false;
  bool _screening = false;
  bool _editingJob = false;
  bool _previewing = false;
  bool _deletingJob = false;
  DateTimeRange? _interviewRange;

  int get _positionId {
    final id = jobPositiveId(widget.job['posId']);
    if (id == null) {
      throw const FormatException('岗位数据缺少有效ID');
    }
    return id;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      // 兼容旧 AI 筛选入口：索引 2 进入合并后的求职者页。
      initialIndex: widget.initialTab == 2 ? 1 : widget.initialTab,
      vsync: this,
    )..addListener(_tabChanged);
    _loadDetail();
    _loadProfile();
    _loadWorkflow();
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _tabChanged() {
    if (_tabs.index == 1) {
      _ensureScores();
    }
  }

  void _ensureScores() {
    final data = _detail.data;
    if (!_scoresRequested &&
        data != null &&
        data.candidates.isNotEmpty &&
        !data.tooManyCandidates &&
        _detail.error == null) {
      _loadScores();
    }
  }

  Future<void> _load<T>(
    JobSectionState<T> state,
    Future<T> Function() fetch,
  ) async {
    final request = ++state.request;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final result = await fetch();
      if (!mounted || request != state.request) {
        return;
      }
      setState(() => state.data = result);
    } catch (error) {
      if (!mounted || request != state.request) {
        return;
      }
      setState(() => state.error = jobDetailError(error));
    } finally {
      if (mounted && request == state.request) {
        setState(() => state.loading = false);
      }
    }
  }

  Future<void> _loadDetail() async {
    await _load(_detail, () async {
      final data = JobDetailViewData.fromJson(
        await widget.source.loadDetail(_positionId),
      );
      if (jobPositiveId(data.job['posId']) != _positionId) {
        throw const FormatException('岗位详情标识不一致');
      }
      return data;
    });
    if (mounted && _tabs.index == 1) {
      _ensureScores();
    }
  }

  Future<void> _loadProfile() => _load(_profile, () async {
    final data = await widget.source.loadProfile(_positionId);
    jobProfileSkills(data);
    return data;
  });

  Future<void> _loadWorkflow() => _load(_workflow, () async {
    final data = await widget.source.loadWorkflow(_positionId);
    jobWorkflowSaveBody(data);
    return data;
  });

  Future<void> _loadScores() {
    _scoresRequested = true;
    return _load(
      _scores,
      () async => jobMaps(await widget.source.loadScores(_positionId), '评分'),
    );
  }

  Future<bool> _parseJd(String text) async {
    if (_parsing) {
      return false;
    }
    setState(() => _parsing = true);
    try {
      await widget.source.parseJd(_positionId, text);
      if (!mounted) {
        return false;
      }
      await Future.wait([_loadProfile(), _loadDetail()]);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _profile.error = jobDetailError(error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _parsing = false);
      }
    }
  }

  Future<bool> _saveWorkflow(Map<String, Object?> body) async {
    if (_savingWorkflow) {
      return false;
    }
    setState(() => _savingWorkflow = true);
    try {
      await widget.source.saveWorkflow(_positionId, body);
      if (!mounted) {
        return false;
      }
      await Future.wait([_loadWorkflow(), _loadDetail()]);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _workflow.error = jobDetailError(error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _savingWorkflow = false);
      }
    }
  }

  Future<void> _editWorkflowStage(int? index) async {
    if (_editingWorkflow ||
        _savingWorkflow ||
        _workflow.loading ||
        _workflow.data == null) {
      return;
    }
    setState(() => _editingWorkflow = true);
    try {
      await showJobWorkflowStageEditor(
        context: context,
        data: _workflow.data!,
        index: index,
        onSave: _saveWorkflow,
      );
    } finally {
      if (mounted) setState(() => _editingWorkflow = false);
    }
  }

  Future<void> _editWorkflow() async {
    if (_editingWorkflow ||
        _savingWorkflow ||
        _workflow.loading ||
        _workflow.data == null) {
      return;
    }
    setState(() => _editingWorkflow = true);
    try {
      await showJobWorkflowEditor(
        context: context,
        data: _workflow.data!,
        onSave: _saveWorkflow,
      );
    } finally {
      if (mounted) setState(() => _editingWorkflow = false);
    }
  }

  Future<void> _fullRescreen() async {
    if (_screening) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认全量分析'),
        content: const Text(
          '全量分析将重新分析该岗位下所有求职者，覆盖已保存的分析结果，'
          '会耗费大量时间和模型调用额度。每位求职者仍独立与岗位要求匹配，不进行横向比较。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('job-full-analysis-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始全量分析'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _rescreen(fullAnalysis: true);
  }

  Future<void> _rescreen({bool fullAnalysis = false}) async {
    final data = _detail.data;
    if (_screening ||
        _detail.loading ||
        _detail.error != null ||
        data == null ||
        data.candidates.isEmpty ||
        data.tooManyCandidates) {
      return;
    }
    setState(() => _screening = true);
    try {
      // Re-read both sources before incremental analysis. If every current candidate
      // already has an LLM result, this action is read-only and does not spend model calls.
      if (!fullAnalysis) {
        await Future.wait([_loadDetail(), _loadScores()]);
        if (!mounted) return;
        if (_detail.error != null) throw ApiException(_detail.error!);
        if (_scores.error != null) throw ApiException(_scores.error!);
        final candidates =
            _detail.data?.candidates ?? const <Map<String, dynamic>>[];
        final analyzedIds = <int>{
          for (final result in _scores.data ?? const <Map<String, dynamic>>[])
            if (result['source'] == 'llm')
              if (jobPositiveId(result['resultId']) case final int id) id,
        };
        final hasUnanalyzedCandidate = candidates.any((candidate) {
          final id = jobPositiveId(candidate['talId']);
          return id == null || !analyzedIds.contains(id);
        });
        if (!hasUnanalyzedCandidate) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已读取已有分析结果，没有待补充的求职者')));
          return;
        }
      }
      final summary = fullAnalysis
          ? await widget.source.startFullScreening(_positionId)
          : await widget.source.startScreening(_positionId);
      if (!mounted) {
        return;
      }
      if (jobPositiveId(summary['taskId']) != _positionId) {
        setState(() => _scores.error = '筛选已响应，但没有返回可核对的任务标识。请刷新评分，避免重复提交。');
        return;
      }
      if (summary['processing'] is! bool) {
        throw const ApiException('服务器尚未部署新版AI筛选服务，请先更新服务器后端');
      }
      var progress = summary;
      final deadline = DateTime.now().add(const Duration(minutes: 12));
      while (progress['processing'] == true) {
        if (DateTime.now().isAfter(deadline)) {
          throw const ApiException('分析仍在后台进行，请稍后查看结果；无需重复提交');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        progress = await widget.source.loadScreeningStatus(_positionId);
        if (jobPositiveId(progress['taskId']) != _positionId) {
          throw const ApiException('分析进度标识不一致，请稍后查看结果');
        }
      }
      if (progress['state'] == 'failed') {
        throw ApiException(talentText(progress['error'], 'AI筛选失败，原有结果未变更'));
      }
      await Future.wait([_loadDetail(), _loadScores()]);
      if (mounted && summary['message'] is String) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(summary['message'] as String)));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _scores.error = jobDetailError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _screening = false);
      }
    }
  }

  Future<void> _editJob() async {
    if (_editingJob || _parsing || _savingWorkflow || _editingWorkflow) return;
    setState(() => _editingJob = true);
    try {
      final id = _positionId;
      final saved = await Navigator.of(context, rootNavigator: true).push<int>(
        MaterialPageRoute(
          builder: (_) => JobPublishPage(
            editingPositionId: id,
            loadOptions: () => widget.source.loadEditingOptions(id),
            submitJob: (body) => widget.source.updateJob(id, body),
          ),
        ),
      );
      if (!mounted || saved != id) return;
      await Future.wait([_loadDetail(), _loadProfile()]);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('岗位信息已更新')));
      }
    } finally {
      if (mounted) setState(() => _editingJob = false);
    }
  }

  void _openCandidate(Map<String, dynamic> candidate) {
    final id = jobPositiveId(candidate['talId']);
    if (id == null) {
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            widget.candidateBuilder?.call(candidate) ??
            TalentDetailPage(
              talent: {'talentId': id, 'name': candidate['name']},
              jobContext: TalentJobContext(
                positionId: _positionId,
                title: jobValue(
                  _detail.data?.job['title'] ?? widget.job['title'],
                ),
                currentStage: candidate['currentStage']?.toString(),
              ),
            ),
      ),
    );
  }

  Future<void> _preview() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JobPreviewPage(
            positionId: _positionId,
            load: () => widget.source.loadCandidatePreview(_positionId),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _deleteJob() async {
    if (_deletingJob) return;
    final title = jobValue(
      _detail.data?.job['title'] ?? widget.job['title'],
      fallback: '该岗位',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除岗位'),
        content: Text(
          '确认删除岗位「$title」吗？删除后不可恢复。\n已有投递、面试等业务数据的岗位无法删除，可改为停招或下线。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('job-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingJob = true);
    try {
      await widget.source.deleteJob(_positionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('岗位已删除')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(jobDetailError(error))));
      }
    } finally {
      if (mounted) setState(() => _deletingJob = false);
    }
  }

  void _openInterviews() {
    final job = _detail.data?.job;
    final id = jobPositiveId(job?['posId']);
    if (id == null) {
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => JobInterviewsPage(
          positionId: id,
          positionTitle: jobValue(job?['title']),
          source: widget.source,
          initialRange: _interviewRange,
          onRangeChanged: (range) {
            if (mounted) {
              setState(() => _interviewRange = range);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(
        jobValue(
          _detail.data?.job['title'] ?? widget.job['title'],
          fallback: '岗位详情',
        ),
      ),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: '基础信息'),
          Tab(text: '求职者'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        _DetailTab(
          child: JobBasicInfoTab(
            detail: _detail,
            profile: _profile,
            onReload: _loadDetail,
            onReloadProfile: _loadProfile,
            onInterviews: _openInterviews,
            onPreview: _preview,
            onDelete: _deletingJob ? null : _deleteJob,
            onEdit:
                _editingJob || _parsing || _savingWorkflow || _editingWorkflow
                ? null
                : _editJob,
            workflowTimeline: JobWorkflowTimeline(
              state: _workflow,
              onReload: _loadWorkflow,
              enabled:
                  !_workflow.loading && !_savingWorkflow && !_editingWorkflow,
              onEditStage: (index) => _editWorkflowStage(index),
              onAddStage: () => _editWorkflowStage(null),
              onManage: _editWorkflow,
            ),
            jdSection: JobJdProfileSection(
              positionId: jobPositiveId(widget.job['posId']) ?? 0,
              state: _profile,
              expanded: _jdExpanded,
              onExpanded: (value) => setState(() => _jdExpanded = value),
              parsing: _parsing,
              onReload: _loadProfile,
              onParse: _parseJd,
            ),
            workflowSection: JobWorkflowSection(
              positionId: jobPositiveId(widget.job['posId']) ?? 0,
              state: _workflow,
              expanded: _workflowExpanded,
              onExpanded: (value) => setState(() => _workflowExpanded = value),
              onReload: _loadWorkflow,
            ),
          ),
        ),
        _DetailTab(
          child: JobCandidatesTab(
            detail: _detail,
            scores: _scores,
            loadResume: widget.source.loadCandidateResume,
            actionsSource: widget.source.candidateActionsSource,
            workflowRevision: _workflow.request,
            job: TalentJobContext(
              positionId: _positionId,
              title: jobValue(
                _detail.data?.job['title'] ?? widget.job['title'],
              ),
            ),
            screening: _screening,
            onReloadDetail: _loadDetail,
            onReloadScores: _loadScores,
            onScreen: _rescreen,
            onFullScreen: _fullRescreen,
            onOpen: _openCandidate,
          ),
        ),
      ],
    ),
  );
}

class _DetailTab extends StatefulWidget {
  const _DetailTab({required this.child});
  final Widget child;
  @override
  State<_DetailTab> createState() => _DetailTabState();
}

class _DetailTabState extends State<_DetailTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
