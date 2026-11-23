import 'package:flutter/material.dart';

import '../../../api/send_center_api.dart';
import '../../../core/network/api_exception.dart';

import '../../../theme/app_theme.dart';
import '../talent/talent_detail_page.dart';
import '../talent/models/talent_detail_view_data.dart';
import 'data/job_detail_data_source.dart';
import 'job_interviews_page.dart';
import 'job_preview_page.dart';
import 'job_publish_page.dart';
import 'interested_talent_page.dart';
import 'models/job_detail_view_data.dart';
import 'widgets/job_basic_info_tab.dart';
import 'widgets/job_candidates_tab.dart';
import 'widgets/job_workflow_section.dart';
import 'widgets/job_workflow_timeline.dart';
import 'widgets/job_exam_invite_sheet.dart';

/// 岗位详情页浅灰蓝背景，参考 BOSS 直聘风格。
const jobDetailBackground = Color(0xFFF3F7FA);

enum _JobDetailAction { interviews, preview, delete, interested }

/// 岗位操作菜单的白色气泡形状：顶部右侧的小三角指向 AppBar 加号。
class _JobActionMenuShape extends ShapeBorder {
  const _JobActionMenuShape({
    this.radius = 16,
    this.arrowWidth = 18,
    this.arrowHeight = 8,
    this.arrowRight = 26,
  });

  final double radius;
  final double arrowWidth;
  final double arrowHeight;
  final double arrowRight;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(top: arrowHeight);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Rect.fromLTRB(
      rect.left,
      rect.top + arrowHeight,
      rect.right,
      rect.bottom,
    );
    final arrowCenter = rect.right - arrowRight;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)))
      ..moveTo(arrowCenter - arrowWidth / 2, body.top)
      ..lineTo(arrowCenter, rect.top)
      ..lineTo(arrowCenter + arrowWidth / 2, body.top)
      ..close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _JobActionMenuShape(
    radius: radius * t,
    arrowWidth: arrowWidth * t,
    arrowHeight: arrowHeight * t,
    arrowRight: arrowRight * t,
  );
}

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
    Future<T> Function() fetch, {
    void Function(Object error)? onError,
  }) async {
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
      onError?.call(error);
    } finally {
      if (mounted && request == state.request) {
        setState(() => state.loading = false);
      }
    }
  }

  Future<void> _loadDetail() async {
    await _load(
      _detail,
      () async {
        final data = JobDetailViewData.fromJson(
          await widget.source.loadDetail(_positionId),
        );
        if (jobPositiveId(data.job['posId']) != _positionId) {
          throw const FormatException('岗位详情标识不一致');
        }
        return data;
      },
      onError: (_) {
        if (mounted) showCompactError(context, '加载失败，请检查网络后重试');
      },
    );
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
      onError: (_) {
        if (mounted) showCompactError(context, '评分加载失败，请稍后重试');
      },
    );
  }

  /// 弹窗只展示一句用户能理解的原因，不把后台长提示堆到页面上。
  String _conciseErrorMessage(Object error, {String fallback = '操作失败，请稍后重试'}) {
    final raw = jobDetailError(error);
    if (raw.contains('AI 服务未配置') || raw.contains('AI服务未配置')) {
      return 'AI 模型未启用，请联系管理员';
    }
    if (raw.contains('鉴权')) return 'AI 模型鉴权失败，请联系管理员';
    if (raw.contains('限流') || raw.contains('额度')) {
      return 'AI 模型额度不足，请稍后重试';
    }
    if (raw.contains('超时')) return 'AI 分析超时，请稍后重试';
    if (raw.contains('尚未部署新版AI筛选服务') || raw.contains('No static resource')) {
      return '服务版本过低，请更新后端';
    }
    final message = raw
        .split('；')
        .first
        .replaceAll(RegExp(r'，?原有结果未变更'), '')
        .trim();
    if (message.isEmpty || message.length > 18) return fallback;
    return message;
  }

  String _conciseSuccessMessage(String message) {
    if (message.contains('没有待补充') || message.contains('已优先读取')) {
      return '分析结果已是最新';
    }
    if (message.contains('完成') || message.contains('成功')) {
      return '人岗匹配完成';
    }
    return '人岗匹配已更新';
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

  Future<void> _rescreen() async {
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
      final summary = await widget.source.startScreening(_positionId);
      if (!mounted) {
        return;
      }
      if (jobPositiveId(summary['taskId']) != _positionId) {
        showCompactError(context, '分析结果异常，请重试');
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            compactSnackBar(
              _conciseSuccessMessage(summary['message'] as String),
            ),
          );
      }
    } catch (error) {
      if (mounted) {
        showCompactError(
          context,
          _conciseErrorMessage(error, fallback: '人岗匹配失败，请稍后重试'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _screening = false);
      }
    }
  }

  Future<void> _editJob() async {
    if (_editingJob || _savingWorkflow || _editingWorkflow) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1500),
            content: Text('岗位信息已更新'),
          ),
        );
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
                applicationId: jobPositiveId(candidate['applicationId']),
              ),
            ),
      ),
    );
  }

  bool get _hasExamStage {
    final raw = _workflow.data?['stages'];
    if (raw is! List) return false;
    return raw.any((stage) {
      if (stage is! Map) return false;
      final type = int.tryParse('${stage['type']}');
      final skipped =
          stage['skip'] == true ||
          '${stage['skip']}' == '1' ||
          '${stage['skip']}' == 'true';
      return type == 1 && !skipped;
    });
  }

  Future<void> _openExamInvite() async {
    final candidates =
        _detail.data?.candidates ?? const <Map<String, dynamic>>[];
    if (!_hasExamStage || candidates.isEmpty) return;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .88,
        child: JobExamInviteSheet(
          positionId: _positionId,
          candidates: candidates,
        ),
      ),
    );
    if (sent == true && mounted) {
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('笔试链接已发送给选中求职者')));
    }
  }

  Future<bool> _beforeInvite(Map<String, dynamic> candidate) async {
    final candidateId = jobPositiveId(candidate['talId']);
    if (candidateId == null) return false;
    try {
      final contextData = await getSendCenterContext(
        candidateId: candidateId,
        positionId: _positionId,
      );
      if (contextData['examPassed'] == true) return true;
      final stages = contextData['stages'];
      final examStages = stages is List
          ? stages
                .whereType<Map>()
                .where((stage) => int.tryParse('${stage['type']}') == 1)
                .toList()
          : const <Map>[];
      if (examStages.isEmpty) return true;
      final required = examStages.any(
        (stage) =>
            stage['required'] == true ||
            '${stage['required']}' == '1' ||
            '${stage['required']}' == 'true',
      );
      if (required) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('暂不能邀请面试'),
              content: const Text('该岗位的笔试阶段为必选流程，请先发起笔试并等待求职者完成。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
        return false;
      }
      if (!mounted) return false;
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认跳过笔试'),
              content: Text(
                '求职者“${candidate['name'] ?? '未填写姓名'}”尚未完成笔试，是否跳过笔试并继续邀请面试？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('跳过并邀请'),
                ),
              ],
            ),
          ) ??
          false;
    } on ApiException catch (error) {
      if (mounted) {
        showCompactError(context, _conciseErrorMessage(error));
      }
      return false;
    } catch (_) {
      if (mounted) {
        showCompactError(context, '无法读取笔试流程，请重试');
      }
      return false;
    }
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
    final applicants = _detail.data?.funnel['total'];
    final warning = applicants is num && applicants > 0
        ? '该岗位已有 $applicants 人投递，删除后投递、面试、笔试等相关数据将一并删除，不可恢复。'
        : '删除后不可恢复。';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除岗位'),
        content: Text('确认删除岗位「$title」吗？$warning'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1500),
          content: Text('岗位已删除'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text(jobDetailError(error)),
          ),
        );
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

  Future<void> _openInterestedTalents() async {
    final data = _detail.data;
    final id = jobPositiveId(data?.job['posId'] ?? widget.job['posId']);
    if (id == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InterestedTalentPage(
          positionId: id,
          positionTitle: jobValue(
            data?.job['title'] ?? widget.job['title'],
            fallback: '岗位',
          ),
          initialCount: int.tryParse('${data?.job['interestCount']}'),
        ),
      ),
    );
  }

  PopupMenuItem<_JobDetailAction> _actionMenuItem({
    required Key key,
    required _JobDetailAction value,
    required IconData icon,
    required String label,
    Color color = AppColors.interactive,
  }) => PopupMenuItem<_JobDetailAction>(
    key: key,
    value: value,
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color == AppColors.error ? AppColors.error : AppColors.brand,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  void _handleAction(_JobDetailAction action) {
    switch (action) {
      case _JobDetailAction.interviews:
        _openInterviews();
      case _JobDetailAction.preview:
        _preview();
      case _JobDetailAction.delete:
        _deleteJob();
      case _JobDetailAction.interested:
        _openInterestedTalents();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: jobDetailBackground,
    appBar: AppBar(
      backgroundColor: jobDetailBackground,
      title: Text(
        jobValue(
          _detail.data?.job['title'] ?? widget.job['title'],
          fallback: '岗位详情',
        ),
      ),
      actions: [
        if (_hasExamStage && (_detail.data?.candidates.isNotEmpty ?? false))
          TextButton.icon(
            key: const Key('job-start-exam'),
            onPressed: _openExamInvite,
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: const Text('发起笔试'),
          ),
        PopupMenuButton<_JobDetailAction>(
          key: const Key('job-action-menu'),
          icon: const Icon(Icons.add_circle_outline, size: 30),
          color: AppColors.canvas,
          elevation: 10,
          shadowColor: AppColors.brand.withValues(alpha: .18),
          position: PopupMenuPosition.under,
          shape: const _JobActionMenuShape(),
          padding: EdgeInsets.zero,
          menuPadding: const EdgeInsets.only(top: 8, bottom: 8),
          offset: const Offset(0, 8),
          constraints: const BoxConstraints(minWidth: 204),
          splashRadius: 24,
          enableFeedback: true,
          tooltip: '岗位操作',
          onSelected: _handleAction,
          itemBuilder: (context) => [
            _actionMenuItem(
              key: const Key('job-interviews-entry'),
              value: _JobDetailAction.interviews,
              icon: Icons.event_outlined,
              label: '面试安排',
            ),
            _actionMenuItem(
              key: const Key('job-preview-entry'),
              value: _JobDetailAction.preview,
              icon: Icons.visibility_outlined,
              label: '预览',
            ),
            _actionMenuItem(
              key: const Key('job-interested-entry'),
              value: _JobDetailAction.interested,
              icon: Icons.bookmark_border,
              label: '感兴趣',
            ),
            if (!_deletingJob)
              _actionMenuItem(
                key: const Key('job-delete-entry'),
                value: _JobDetailAction.delete,
                icon: Icons.delete_outline,
                label: '删除岗位',
                color: AppColors.error,
              ),
          ],
        ),
        const SizedBox(width: 6),
      ],
      bottom: TabBar(
        controller: _tabs,
        labelColor: AppColors.interactive,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.interactive,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
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
            onEdit: _editingJob || _savingWorkflow || _editingWorkflow
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
            beforeInvite: _beforeInvite,
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
