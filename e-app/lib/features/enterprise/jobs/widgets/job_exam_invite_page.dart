import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../api/exam_api.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';

const _examPageBackground = Color(0xFFF4F8FF);
const _examBorder = Color(0xFFDCE8F8);
const _examMuted = Color(0xFF8B98AA);
const _examDisabledBackground = Color(0xFFF7F8FA);

enum _CandidateFilter { all, eligible, locked }

/// 按试卷总分折算实际合格线，百分比限制在 1–100，结果不超过满分。
double examPassThresholdScore(double totalScore, int percent) {
  final total = totalScore > 0 ? totalScore : 100.0;
  final safePercent = percent.clamp(1, 100);
  return (total * safePercent / 100).clamp(1, total).toDouble();
}

/// 发起笔试独立页面。
///
/// 当前阶段不在笔试阶段的求职者保留展示，但复选框置灰且不可选择；
/// 页面支持按姓名、手机号和选择状态筛选。
class JobExamInvitePage extends StatefulWidget {
  const JobExamInvitePage({
    super.key,
    required this.positionId,
    required this.jobTitle,
    required this.candidates,
    required this.examStageNames,
    required this.examStageId,
    this.initialCandidateId,
    this.examPassPercent = 70,
    this.paperLoader,
    this.scheduleLoader,
  });

  final int positionId;
  final String jobTitle;
  final List<Map<String, dynamic>> candidates;
  final Set<String> examStageNames;
  final int examStageId;
  final int? initialCandidateId;

  /// 招聘流程中在线笔试阶段配置的通过阈值百分比。
  final int examPassPercent;

  /// 测试或复用场景可注入试卷加载逻辑；为空时请求真实接口。
  final Future<List<Map<String, dynamic>>> Function()? paperLoader;
  final Future<List<Map<String, dynamic>>> Function()? scheduleLoader;

  @override
  State<JobExamInvitePage> createState() => _JobExamInvitePageState();
}

class _JobExamInvitePageState extends State<JobExamInvitePage> {
  late final TextEditingController _searchController;
  late final Set<int> _selectedCandidates;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<Map<String, dynamic>> _papers = const [];
  List<Map<String, dynamic>> _schedules = const [];
  int? _paperId;
  int? _scheduleId;
  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));
  _CandidateFilter _filter = _CandidateFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedCandidates = {};
    for (final row in widget.candidates) {
      final id = _candidateId(row);
      final shouldSelect = widget.initialCandidateId == null
          ? true
          : id == widget.initialCandidateId;
      if (id != null && shouldSelect && _isEligible(row)) {
        _selectedCandidates.add(id);
      }
    }
    _loadPapers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int? _candidateId(Map<String, dynamic> row) {
    final id = int.tryParse('${row['talId']}');
    return id != null && id > 0 ? id : null;
  }

  String _candidateStage(Map<String, dynamic> row) =>
      '${row['currentStage'] ?? ''}'.trim();

  bool _isEligible(Map<String, dynamic> row) {
    final currentStageId = int.tryParse('${row['currentStageId']}');
    if (currentStageId != null) {
      return currentStageId == widget.examStageId;
    }
    final currentStageType = int.tryParse('${row['currentStageType']}');
    if (currentStageType != null) {
      return currentStageType == 1;
    }
    final stage = _candidateStage(row);
    return stage.isNotEmpty && widget.examStageNames.contains(stage);
  }

  String get _examStageLabel =>
      widget.examStageNames.isEmpty ? '笔试' : widget.examStageNames.join(' / ');

  int get _passPercent => widget.examPassPercent.clamp(1, 100).toInt();

  double _paperPassScore(Map<String, dynamic> paper) => examPassThresholdScore(
    double.tryParse('${paper['totalScore']}') ?? 100,
    _passPercent,
  );

  String _scoreText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  String _candidateSearchText(Map<String, dynamic> row) => [
    row['name'],
    row['candidateName'],
    row['nickName'],
    row['phone'],
    row['statusLabel'],
    row['currentStage'],
  ].whereType<Object>().join(' ').toLowerCase();

  List<Map<String, dynamic>> get _filteredCandidates {
    final query = _query.trim().toLowerCase();
    return widget.candidates
        .where((row) {
          if (_candidateId(row) == null) {
            return false;
          }
          if (query.isNotEmpty && !_candidateSearchText(row).contains(query)) {
            return false;
          }
          final eligible = _isEligible(row);
          return switch (_filter) {
            _CandidateFilter.all => true,
            _CandidateFilter.eligible => eligible,
            _CandidateFilter.locked => !eligible,
          };
        })
        .toList(growable: false);
  }

  Set<int> get _visibleEligibleIds => {
    for (final row in _filteredCandidates)
      if (_isEligible(row))
        if (_candidateId(row) case final int id) id,
  };

  int get _eligibleCount => widget.candidates.where(_isEligible).length;

  int get _lockedCount => widget.candidates.length - _eligibleCount;

  Map<String, dynamic>? get _selectedPaper {
    for (final paper in _papers) {
      if (int.tryParse('${paper['paperId']}') == _paperId) {
        return paper;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _requestPapers() {
    final loader = widget.paperLoader;
    return loader == null
        ? listExamPapers(positionId: widget.positionId)
        : loader();
  }

  Future<void> _loadPapers() async {
    if (!_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
      if (widget.paperLoader == null) {
        await _loadSchedules();
      }
    }
    try {
      final raw = await _requestPapers();
      final papers = raw
          .where(
            (paper) =>
                (paper['status'] == 1 || '${paper['status']}' == '1') &&
                int.tryParse('${paper['paperId']}') != null,
          )
          .toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _papers = papers;
        _paperId = papers.isEmpty
            ? null
            : int.tryParse('${papers.first['paperId']}');
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '试卷加载失败，请稍后重试';
      });
    }
  }

  Future<void> _loadSchedules() async {
    try {
      final loader = widget.scheduleLoader;
      final rows = await (loader == null
          ? listExamSchedules(positionId: widget.positionId)
          : loader());
      if (!mounted) return;
      final active = rows.where((row) {
        final status = int.tryParse('${row['status']}');
        final stageId = int.tryParse('${row['stageId']}');
        return (status == 0 || status == 1) && stageId == widget.examStageId;
      }).toList(growable: false);
      setState(() => _schedules = active);
    } catch (_) {
      // 场次列表加载失败不阻断新建场次，提交时仍由后端校验。
    }
  }

  Future<void> _pickStartAt() async {
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: _startAt,
    );
    if (day == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _startAt = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    });
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _displayTime(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)} '
      '${_two(value.hour)}:${_two(value.minute)}';

  String _apiTime(DateTime value) => '${_displayTime(value)}:00';

  void _toggleCandidate(int id, bool? value) {
    if (_submitting) {
      return;
    }
    setState(() {
      if (value == true) {
        _selectedCandidates.add(id);
      } else {
        _selectedCandidates.remove(id);
      }
    });
  }

  void _selectVisibleEligible() {
    final ids = _visibleEligibleIds;
    if (ids.isEmpty) {
      return;
    }
    setState(() => _selectedCandidates.addAll(ids));
  }

  Future<void> _submit() async {
    if (_submitting || _paperId == null || _selectedCandidates.isEmpty) {
      return;
    }
    final paper = _selectedPaper;
    if (paper == null) {
      showCompactError(context, '请选择有效的试卷');
      return;
    }
    final passThreshold = _paperPassScore(paper);
    setState(() => _submitting = true);
    try {
      final scheduleId = _scheduleId ?? await createExamSchedule(
            positionId: widget.positionId,
            paperId: _paperId!,
            stageId: widget.examStageId,
            startAt: _apiTime(_startAt),
            endAt: _apiTime(_startAt.add(const Duration(hours: 24))),
            passThreshold: passThreshold,
            passThresholdPercent: _passPercent,
          );
      if (scheduleId == null) {
        throw const ApiException('笔试安排创建失败，请重试');
      }
      final assignment = await assignExamCandidates(
        scheduleId,
        candidateIds: _selectedCandidates.toList(),
      );
      if ((int.tryParse('${assignment['assigned']}') ?? 0) == 0) {
        throw const ApiException('没有候选人成功加入笔试场次，请刷新流程后重试');
      }
      await sendExamNotify(
        scheduleId,
        candidateIds: _selectedCandidates.toList(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showCompactError(
        context,
        error is ApiException ? error.message : '笔试发起失败，请稍后重试',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCandidates;
    return Scaffold(
      key: const Key('job-exam-page'),
      backgroundColor: _examPageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.interactive,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '笔试安排',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _hero(),
                const SizedBox(height: 12),
                _settingsCard(),
                const SizedBox(height: 12),
                _candidatesCard(filtered),
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B7FFF), Color(0xFF5B9DFF)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.jobTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '当前笔试阶段：$_examStageLabel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '仅处于笔试阶段的求职者可勾选发送',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _settingsCard() => _ExamCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(icon: Icons.tune_rounded, title: '笔试设置'),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (_error != null)
          _errorState()
        else if (_papers.isEmpty)
          _emptyPapersState()
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                key: const Key('job-exam-pass-percent'),
                icon: Icons.verified_outlined,
                text: '通过阈值 $_passPercent%',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _paperSelector(),
          if (_schedules.isNotEmpty) ...[
            const SizedBox(height: 10),
            _scheduleSelector(),
          ],
          if (_selectedPaper case final paper?) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.timer_outlined,
                  text: '${paper['durationMin'] ?? 0} 分钟',
                ),
                _InfoPill(
                  icon: Icons.workspace_premium_outlined,
                  text: '满分 ${paper['totalScore'] ?? 100}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '按当前试卷总分折算，合格线 ≥ ${_scoreText(_paperPassScore(paper))} 分',
              key: const Key('job-exam-pass-score'),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (_scheduleId == null) _startTimeField() else _selectedScheduleHint(),
          const SizedBox(height: 8),
          const Text(
            '笔试链接在开始后 24 小时内有效',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _paperSelector() => DropdownButtonFormField<int>(
    key: const Key('job-exam-paper'),
    initialValue: _paperId,
    isExpanded: true,
    decoration: _fieldDecoration('选择试卷'),
    items: [
      for (final paper in _papers)
        DropdownMenuItem(
          value: int.tryParse('${paper['paperId']}'),
          child: Text(
            '${paper['name'] ?? '未命名试卷'} · ${paper['durationMin'] ?? 0}分钟',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: _submitting ? null : (value) => setState(() => _paperId = value),
  );

  Widget _scheduleSelector() => DropdownButtonFormField<int?>(
    key: const Key('job-exam-schedule'),
    initialValue: _scheduleId,
    isExpanded: true,
    decoration: _fieldDecoration('复用进行中的笔试场次（可选）'),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('新建笔试场次')),
      for (final row in _schedules)
        DropdownMenuItem<int?>(
          value: int.tryParse('${row['scheduleId']}'),
          child: Text(
            '${row['paperName'] ?? '笔试场次'} · ${row['startAt'] ?? ''} 至 ${row['endAt'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: _submitting
        ? null
        : (value) {
            final selected = _schedules.where(
              (row) => int.tryParse('${row['scheduleId']}') == value,
            );
            setState(() {
              _scheduleId = value;
              if (selected.isNotEmpty) {
                _paperId = int.tryParse('${selected.first['paperId']}');
              }
            });
          },
  );

  Widget _startTimeField() => InkWell(
    key: const Key('job-exam-start-at'),
    borderRadius: BorderRadius.circular(12),
    onTap: _submitting ? null : _pickStartAt,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _examBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.interactive,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '开始时间',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  _displayTime(_startAt),
                  style: const TextStyle(
                    color: AppColors.body,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 20,
          ),
        ],
      ),
    ),
  );

  Widget _selectedScheduleHint() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _examBorder),
    ),
    child: const Row(
      children: [
        Icon(Icons.link_rounded, color: AppColors.interactive, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '已选择进行中的笔试场次，新增候选人将沿用该场次的时间和规则。',
            style: TextStyle(color: AppColors.bodySoft, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _errorState() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFDF2F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF4C9C9)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(
              color: AppColors.red,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        TextButton(
          key: const Key('job-exam-paper-retry'),
          onPressed: _loadPapers,
          child: const Text('重试'),
        ),
      ],
    ),
  );

  Widget _emptyPapersState() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _examBorder),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: AppColors.interactive,
          size: 20,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '当前岗位没有可用试卷，请先在笔试管理中启用试卷。',
            style: TextStyle(
              color: AppColors.bodySoft,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _candidatesCard(List<Map<String, dynamic>> filtered) => _ExamCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle(
                icon: Icons.people_outline_rounded,
                title: '选择求职者',
              ),
            ),
            Text(
              '可选 $_eligibleCount / ${widget.candidates.length}',
              style: const TextStyle(
                color: AppColors.interactive,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('job-exam-search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: '搜索姓名、手机号或当前阶段',
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.interactive,
              size: 20,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: const Key('job-exam-search-clear'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
            filled: true,
            fillColor: const Color(0xFFF7FAFF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _examBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _examBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.interactive,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _filterChips(),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${filtered.length} 人',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const Spacer(),
            TextButton(
              key: const Key('job-exam-select-eligible'),
              onPressed: _submitting || _visibleEligibleIds.isEmpty
                  ? null
                  : _selectVisibleEligible,
              child: const Text('全选可选'),
            ),
            TextButton(
              key: const Key('job-exam-clear'),
              onPressed: _submitting || _selectedCandidates.isEmpty
                  ? null
                  : () => setState(() => _selectedCandidates.clear()),
              child: const Text('清空'),
            ),
          ],
        ),
        if (_eligibleCount == 0) _noEligibleHint(),
        if (_filteredCandidates.isEmpty)
          _emptyCandidatesState()
        else
          for (final row in _filteredCandidates) _candidateTile(row),
      ],
    ),
  );

  Widget _filterChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _filterChip(
        key: const Key('job-exam-filter-all'),
        label: '全部 ${widget.candidates.length}',
        filter: _CandidateFilter.all,
      ),
      _filterChip(
        key: const Key('job-exam-filter-eligible'),
        label: '可发起 $_eligibleCount',
        filter: _CandidateFilter.eligible,
      ),
      _filterChip(
        key: const Key('job-exam-filter-locked'),
        label: '不可选 $_lockedCount',
        filter: _CandidateFilter.locked,
      ),
    ],
  );

  Widget _filterChip({
    required Key key,
    required String label,
    required _CandidateFilter filter,
  }) {
    final selected = _filter == filter;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: _submitting ? null : (_) => setState(() => _filter = filter),
      selectedColor: AppColors.primarySoft,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.interactive : _examBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: selected ? AppColors.interactive : AppColors.bodySoft,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  Widget _noEligibleHint() => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAFF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _examBorder),
    ),
    child: const Text(
      '当前没有处于笔试阶段的求职者，以下名单仅做展示，不能勾选。',
      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
    ),
  );

  Widget _emptyCandidatesState() => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    alignment: Alignment.center,
    child: const Text(
      '没有匹配的求职者',
      style: TextStyle(color: AppColors.muted, fontSize: 13),
    ),
  );

  Widget _candidateTile(Map<String, dynamic> row) {
    final id = _candidateId(row)!;
    final eligible = _isEligible(row);
    final selected = eligible && _selectedCandidates.contains(id);
    final stage = _candidateStage(row);
    final name = '${row['name'] ?? row['candidateName'] ?? '未填写姓名'}'.trim();
    final status = '${row['statusLabel'] ?? ''}'.trim();
    return Container(
      key: Key('job-exam-candidate-$id'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.interactive : _examBorder,
          width: selected ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: eligible ? Colors.white : _examDisabledBackground,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: eligible && !_submitting
              ? () => _toggleCandidate(id, !selected)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
            child: Row(
              children: [
                Checkbox(
                  key: Key('job-exam-checkbox-$id'),
                  value: selected,
                  onChanged: eligible && !_submitting
                      ? (value) => _toggleCandidate(id, value)
                      : null,
                  activeColor: AppColors.interactive,
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: eligible
                        ? AppColors.interactive
                        : const Color(0xFFC5CEDB),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                _avatar(name: name, eligible: eligible),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: eligible ? AppColors.body : _examMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _candidateBadge(eligible),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.route_rounded,
                            size: 14,
                            color: eligible
                                ? AppColors.interactive
                                : const Color(0xFFA5AFBF),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '当前阶段：${stage.isEmpty ? '未进入流程' : stage}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: eligible
                                    ? AppColors.bodySoft
                                    : _examMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          status,
                          style: TextStyle(
                            color: eligible
                                ? AppColors.muted
                                : const Color(0xFF9AA4B2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (!eligible) ...[
                        const SizedBox(height: 4),
                        Text(
                          '仅当前阶段为「$_examStageLabel」时可勾选',
                          style: const TextStyle(
                            color: Color(0xFF9AA4B2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar({required String name, required bool eligible}) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: eligible ? AppColors.primarySoft : const Color(0xFFEDEFF3),
      shape: BoxShape.circle,
    ),
    child: Text(
      name.isEmpty ? '?' : name[0],
      style: TextStyle(
        color: eligible ? AppColors.interactive : _examMuted,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _candidateBadge(bool eligible) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: eligible ? AppColors.primarySoft : const Color(0xFFECEEF2),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      eligible ? '可发起' : '不可选',
      style: TextStyle(
        color: eligible ? AppColors.interactive : _examMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _bottomBar() {
    final canSubmit =
        !_submitting &&
        !_loading &&
        _error == null &&
        _paperId != null &&
        _selectedCandidates.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _examBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已选 ${_selectedCandidates.length} 人',
                    style: TextStyle(
                      color: _selectedCandidates.isEmpty
                          ? AppColors.muted
                          : AppColors.body,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _bottomHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('job-exam-submit'),
              onPressed: canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.interactive,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD7E1EF),
                disabledForegroundColor: const Color(0xFF8B99AD),
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
              : Text(
                  _scheduleId == null ? '发送笔试链接' : '加入并发送',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String get _bottomHint {
    if (_loading) {
      return '正在加载试卷';
    }
    if (_error != null) {
      return '试卷加载失败，请重试';
    }
    if (_papers.isEmpty) {
      return '暂无可用试卷';
    }
    if (_selectedCandidates.isEmpty) {
      return '请选择处于笔试阶段的求职者';
    }
    if (_scheduleId != null) {
      return '候选人将加入已选择的笔试场次';
    }
    return '发送后候选人会收到站内信与邮件';
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF7FAFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _examBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _examBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.interactive, width: 1.2),
    ),
  );
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _examBorder),
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.interactive, size: 17),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.body,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.interactive, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.interactive,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
