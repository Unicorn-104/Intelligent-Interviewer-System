import 'package:flutter/material.dart';

import '../../../api/jd_api.dart';
import '../../../api/jobs_api.dart';
import '../../../api/schedule_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import '../schedule/interview_appointment_detail_page.dart';
import '../talent/talent_detail_page.dart';

/// 模块一：岗位详情页（P1），含 JD 画像展示。
///
/// 依据《业务功能分析》UC-01（发布岗位并生成 JD 画像）：
/// 系统自动解析 JD 文本，提取学历、年限、技能标签等硬性指标与软性要求，
/// 生成结构化"岗位画像（JD Profile）"。
/// 数据来源：真实接口（lib/api/jd_api.dart，P8 接入）；
/// 加载中（骨架屏）/ 失败（可重试）/ 未生成（可解析）三态处理。
class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key, required this.job});

  final Map<String, dynamic> job;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _candidateLoading = false;
  bool _candidateTooMany = false;
  bool _candidatesRequested = false;
  String? _candidateError;
  List<Map<String, dynamic>>? _candidates;

  bool _interviewLoading = false;
  bool _interviewsRequested = false;
  bool _tooManyInterviews = false;
  String? _interviewError;
  DateTimeRange? _interviewRange;
  List<Map<String, dynamic>>? _interviews;
  int _interviewRequest = 0;
  bool _loading = true;
  bool _parsing = false;
  bool _editingJd = false;
  String? _error;
  // getJdProfile 返回：{positionId, title, department, jdProfile(未生成时 null), skills}
  Map<String, dynamic>? _jdResult;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
    _loadProfile();
  }

  /// 拉取岗位画像；未生成时后端返回 jdProfile=null。
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || !mounted) return;
    if (_tabs.index == 1 && !_candidatesRequested) {
      _candidatesRequested = true;
      _loadCandidates();
    } else if (_tabs.index == 2 && !_interviewsRequested) {
      _interviewsRequested = true;
      _loadInterviews();
    }
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _candidateLoading = true;
      _candidateError = null;
      _candidateTooMany = false;
    });
    try {
      final posId = int.tryParse('${widget.job['posId']}');
      if (posId == null) throw const FormatException('岗位数据缺少 ID');
      final data = await getJobDetail(posId);
      final entries = data['candidates'];
      if (entries is! List) throw const FormatException('投递候选人数据缺失');
      if (entries.length > 100) {
        if (mounted) setState(() => _candidateTooMany = true);
        return;
      }
      final candidates = entries
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      if (!mounted) return;
      setState(() => _candidates = candidates);
    } catch (e) {
      if (!mounted) return;
      setState(() => _candidateError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _candidateLoading = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickInterviewRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _interviewRange,
    );
    if (selected == null || !mounted) return;
    setState(() => _interviewRange = selected);
    await _loadInterviews();
  }

  Future<void> _loadInterviews() async {
    final request = ++_interviewRequest;
    setState(() {
      _interviewLoading = true;
      _interviewError = null;
      _tooManyInterviews = false;
    });
    try {
      final posId = int.tryParse('${widget.job['posId']}');
      if (posId == null) throw const FormatException('岗位数据缺少 ID');
      final from = _interviewRange == null
          ? null
          : '${_formatDate(_interviewRange!.start)} 00:00:00';
      final to = _interviewRange == null
          ? null
          : '${_formatDate(_interviewRange!.end)} 23:59:59';
      // 服务端只能按日期/状态筛选；每次最多 50 条，聚合最多 100 条。
      const pageSize = 50;
      final rows = await listInterviews(
        pageNum: 1,
        pageSize: pageSize,
        from: from,
        to: to,
      );
      if (rows.length > pageSize) throw const FormatException('分页响应异常');
      if (rows.length == pageSize) {
        final second = await listInterviews(
          pageNum: 2,
          pageSize: pageSize,
          from: from,
          to: to,
        );
        if (second.length > pageSize) throw const FormatException('分页响应异常');
        rows.addAll(second);
        if (second.length == pageSize) {
          // pageNum=3,pageSize=1 查到的是第 3 条，不能探测第 101 条。
          // 第三页仍用 pageSize=50；失败统一走 catch，不会误报超量。
          final probe = await listInterviews(
            pageNum: 3,
            pageSize: pageSize,
            from: from,
            to: to,
          );
          if (probe.isNotEmpty) {
            if (!mounted || request != _interviewRequest) return;
            setState(() {
              _tooManyInterviews = true;
              _interviews = null;
            });
            return;
          }
        }
      }
      if (!mounted || request != _interviewRequest) return;
      setState(() {
        _interviews = rows
            .where((row) => int.tryParse('${row['positionId']}') == posId)
            .toList();
      });
    } catch (_) {
      if (!mounted || request != _interviewRequest) return;
      setState(() {
        _interviews = null;
        _interviewError = '请求失败，请重试';
      });
    } finally {
      if (mounted && request == _interviewRequest) {
        setState(() => _interviewLoading = false);
      }
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final posId = int.tryParse('${widget.job['posId']}');
      if (posId == null) {
        setState(() {
          _error = '岗位数据缺少 ID';
          _loading = false;
        });
        return;
      }
      final data = await getJdProfile(posId);
      if (!mounted) return;
      setState(() {
        _jdResult = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  /// 弹出 JD 文本输入框 → 解析生成画像 → 刷新展示。
  Future<void> _parseJd() async {
    if (_editingJd || _parsing) return;
    final positionId = int.tryParse('${widget.job['posId']}');
    if (positionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('岗位数据缺少 ID，无法解析 JD')));
      return;
    }
    setState(() => _editingJd = true);
    final formKey = GlobalKey<FormState>();
    var jdText = '';
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '解析 JD 生成画像',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '粘贴岗位 JD 全文，系统将提取学历、年限、技能标签等硬性指标与软性要求',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                onChanged: (value) => jdText = value,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入 JD 文本' : null,
                maxLines: 8,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText: '例如：本科及以上学历，3年以上 Java 开发经验，熟悉 Spring Boot、MySQL…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(sheetContext, jdText.trim());
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('开始解析'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _editingJd = false);
    if (text == null) return;
    setState(() => _parsing = true);
    try {
      await parseJdProfile(positionId: positionId, jdText: text);
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.job['title']}'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'JD 画像'),
            Tab(text: '投递候选人'),
            Tab(text: '面试安排'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildJdTab(), _buildCandidatesTab(), _buildInterviewsTab()],
      ),
    );
  }

  Widget _buildJdTab() {
    final job = widget.job;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${job['title']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${job['dept']} · ${job['location']}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '薪资 ${job['salary']} · 投递 ${job['applicants']} 人',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('岗位画像（JD Profile）'),
        _buildJdSection(),
      ],
    );
  }

  Widget _buildCandidatesTab() {
    if (_candidateLoading) return const SkeletonList(rows: 4);
    if (_candidateError != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: _candidateError!,
        actionLabel: '重试',
        onAction: _loadCandidates,
      );
    }
    final candidates = _candidates ?? const <Map<String, dynamic>>[];
    if (_candidateTooMany) {
      return const PageMessage(
        icon: Icons.people_outline,
        title: '数据量过大，请缩小范围',
        message: '当前岗位详情接口没有候选人筛选或分页参数，无法安全展示完整列表',
      );
    }
    if (candidates.isEmpty) {
      return const PageMessage(
        icon: Icons.people_outline,
        title: '暂无投递候选人',
        message: '该岗位暂无候选人投递',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadCandidates,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          // t_process_instance.pin_candidate_id -> t_tal.tal_id；
          // talId 与人才详情的 talentId 均为同一表主键，已核对实际响应。
          final talentId = int.tryParse('${candidate['talId']}');
          final score = num.tryParse('${candidate['matchScore']}');
          final stage = candidate['currentStage']?.toString().trim() ?? '';
          final status = candidate['statusLabel']?.toString().trim() ?? '';
          return Card(
            child: ListTile(
              title: Text('${candidate['name'] ?? '姓名未填写'}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status.isNotEmpty) Text(status),
                  if (stage.isNotEmpty) Text('当前阶段：$stage'),
                  if (score != null) Text('匹配度：$score'),
                  if (talentId == null) const Text('候选人 ID 缺失，无法查看详情'),
                ],
              ),
              trailing: talentId == null
                  ? null
                  : const Icon(Icons.chevron_right),
              onTap: talentId == null
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TalentDetailPage(
                          talent: {
                            'talentId': talentId,
                            'name': candidate['name'],
                          },
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInterviewsTab() {
    final range = _interviewRange;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickInterviewRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  range == null
                      ? '选择日期范围'
                      : '${_formatDate(range.start)} ~ ${_formatDate(range.end)}',
                ),
              ),
              if (range != null)
                TextButton(
                  onPressed: () {
                    setState(() => _interviewRange = null);
                    _loadInterviews();
                  },
                  child: const Text('清除筛选'),
                ),
            ],
          ),
        ),
        Expanded(child: _buildInterviewResults()),
      ],
    );
  }

  Widget _buildInterviewResults() {
    if (_interviewLoading) return const SkeletonList(rows: 4);
    if (_interviewError != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: _interviewError!,
        actionLabel: '重试',
        onAction: _loadInterviews,
      );
    }
    if (_tooManyInterviews) {
      return PageMessage(
        icon: Icons.filter_alt_outlined,
        title: '数据量过大，请缩小范围',
        message: '面试记录超过 100 条，请选择更短的日期范围',
        actionLabel: '选择日期范围',
        onAction: _pickInterviewRange,
      );
    }
    final interviews = _interviews ?? const <Map<String, dynamic>>[];
    if (interviews.isEmpty) {
      return const PageMessage(
        icon: Icons.event_busy_outlined,
        title: '暂无面试安排',
        message: '当前岗位和日期范围内没有面试记录',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInterviews,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: interviews.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final interview = interviews[index];
          return Card(
            child: ListTile(
              title: Text('${interview['candidateName'] ?? '候选人未填写'}'),
              subtitle: Text('开始：${interview['startTime'] ?? '未填写'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InterviewAppointmentDetailPage(appointment: interview),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 画像区：加载中（骨架屏）/ 失败（可重试）/ 未生成（可解析）/ 已生成。
  Widget _buildJdSection() {
    if (_loading) return const SkeletonList(rows: 1);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: _error!,
        actionLabel: '重试',
        onAction: _loadProfile,
      );
    }
    final result = _jdResult ?? const <String, dynamic>{};
    if (result.isEmpty) {
      return const PageMessage(
        icon: Icons.work_off_outlined,
        title: '暂无岗位画像数据',
        message: '接口未返回岗位信息，请稍后刷新',
      );
    }
    final profile = result['jdProfile'];
    if (profile is! Map || profile.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('尚未生成岗位画像', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                '粘贴 JD 文本后，系统将解析学历、年限、技能标签等硬性指标与软性要求，生成结构化岗位画像',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _parsing || _editingJd ? null : _parseJd,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_parsing ? '解析中…' : '解析 JD 生成画像'),
              ),
            ],
          ),
        ),
      );
    }
    return _buildProfileCard(result, profile);
  }

  /// 已生成画像：按后端扁平结构渲染
  /// （summary/education/years/softRequirements/skills/parsedAt，
  ///  必备/加分技能来自外层 skills：t_pos_skill 真实数据）。
  Widget _buildProfileCard(Map<String, dynamic> result, Map profile) {
    final skills =
        (profile['skills'] as List?)
            ?.whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final softRequirements = (profile['softRequirements'] as List?) ?? const [];
    final positionSkills =
        (result['skills'] as List?)
            ?.whereType<Map>()
            .where(
              (s) =>
                  s['name'] is String &&
                  (s['name'] as String).trim().isNotEmpty,
            )
            .toList() ??
        const <Map>[];
    final requiredSkills = positionSkills
        .where((s) => int.tryParse('${s['required']}') == 1)
        .map((s) => '${s['name']}')
        .toList();
    final bonusSkills = positionSkills
        .where((s) => int.tryParse('${s['required']}') == 0)
        .map((s) => '${s['name']}')
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${profile['summary'] ?? ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _GroupLabel('硬性指标'),
            _ProfileRow(field: '学历', value: '${profile['education'] ?? '不限'}'),
            _ProfileRow(field: '工作年限', value: '${profile['years'] ?? '不限'}'),
            _ProfileRow(
              field: '必备技能',
              value: requiredSkills.isNotEmpty
                  ? requiredSkills.join('、')
                  : skills.isNotEmpty
                  ? skills.join('、')
                  : '未设置',
            ),
            if (bonusSkills.isNotEmpty)
              _ProfileRow(field: '加分技能', value: bonusSkills.join('、')),
            const SizedBox(height: 12),
            _GroupLabel('软性要求'),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                softRequirements.isEmpty
                    ? '未设置'
                    : softRequirements.map((s) => '$s').join('；'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.interactive,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '解析时间：${profile['parsedAt'] ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _parsing || _editingJd ? null : _parseJd,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重新解析'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 接口异常 → 友好文案。
String _friendlyError(Object e) =>
    e is ApiException ? e.message : '网络异常，请检查网络后重试';

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: AppColors.brand, fontSize: 14),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.field, required this.value});

  final String field;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(field, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
