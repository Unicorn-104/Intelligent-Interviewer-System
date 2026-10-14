import 'package:flutter/material.dart';

import '../../../api/talent_api.dart';
import '../../../api/schedule_api.dart';
import '../schedule/interview_appointment_detail_page.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

/// 模块一：候选人详情页（P1），含简历解析结果视图。
///
/// 依据《业务功能分析》UC-02（简历投递与智能解析）步骤4-5：
/// 智能字段提取输出标准化 JSON；完整度检查标记缺失字段。
/// 数据来源：真实接口（lib/api/talent_api.dart，P8 接入）：
/// getTalentDetail（基本信息/阶段）+ getTalentParsedResume（解析结果/完整度）。
/// 注意：后端简历解析结果无"期望薪资"字段，故不展示该区块（不编造数据）。
class TalentDetailPage extends StatefulWidget {
  const TalentDetailPage({super.key, required this.talent});

  final Map<String, dynamic> talent;

  @override
  State<TalentDetailPage> createState() => _TalentDetailPageState();
}

class _TalentDetailPageState extends State<TalentDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _resume;
  bool _interviewLoading = false;
  bool _tooManyInterviews = false;
  String? _interviewError;
  List<Map<String, dynamic>>? _interviews;
  DateTimeRange? _interviewRange;
  int _interviewRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadInterviews();
  }

  /// 拉取候选人详情与简历解析结果。
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final talentId = int.tryParse('${widget.talent['talentId']}');
      if (talentId == null) {
        setState(() {
          _error = '候选人数据缺少 ID';
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        getTalentDetail(talentId),
        getTalentParsedResume(talentId),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0];
        _resume = results[1];
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

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _chooseInterviewRange() async {
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
      final candidateId = int.tryParse('${widget.talent['talentId']}');
      if (candidateId == null) throw const FormatException('候选人数据缺少 ID');
      final range = _interviewRange;
      final from = range == null ? null : '${_date(range.start)} 00:00:00';
      final to = range == null ? null : '${_date(range.end)} 23:59:59';
      const pageSize = 50;
      final first = await listInterviews(
        pageNum: 1,
        pageSize: pageSize,
        from: from,
        to: to,
      );
      if (first.length > pageSize) throw const FormatException('分页响应异常');
      if (first.length == pageSize) {
        final second = await listInterviews(
          pageNum: 2,
          pageSize: pageSize,
          from: from,
          to: to,
        );
        if (second.length > pageSize) throw const FormatException('分页响应异常');
        first.addAll(second);
        if (second.length == pageSize) {
          // 探测第 101 条；请求异常直接进入 catch，绝不误报超量。
          final probe = await listInterviews(
            pageNum: 3,
            pageSize: pageSize,
            from: from,
            to: to,
          );
          if (probe.isNotEmpty) {
            if (!mounted || request != _interviewRequest) return;
            setState(() {
              _interviews = null;
              _tooManyInterviews = true;
            });
            return;
          }
        }
      }
      if (!mounted || request != _interviewRequest) return;
      setState(
        () => _interviews = first
            .where(
              (item) => int.tryParse('${item['candidateId']}') == candidateId,
            )
            .toList(),
      );
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

  Widget _buildInterviewSection() {
    final range = _interviewRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('面试安排')),
            TextButton.icon(
              onPressed: _chooseInterviewRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('筛选日期'),
            ),
          ],
        ),
        if (range != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_date(range.start)} ~ ${_date(range.end)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
        if (_interviewLoading)
          const SkeletonList(rows: 2)
        else if (_interviewError != null)
          PageMessage(
            icon: Icons.cloud_off_outlined,
            title: '加载失败',
            message: _interviewError!,
            actionLabel: '重试',
            onAction: _loadInterviews,
          )
        else if (_tooManyInterviews)
          PageMessage(
            icon: Icons.filter_alt_outlined,
            title: '数据量过大，请缩小范围',
            message: '面试记录超过 100 条，请选择更短的日期范围',
            actionLabel: '选择日期范围',
            onAction: _chooseInterviewRange,
          )
        else if (_interviews?.isEmpty ?? true)
          const Card(
            child: Padding(padding: EdgeInsets.all(16), child: Text('暂无面试安排')),
          )
        else
          for (final item in _interviews!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text('${item['positionTitle'] ?? '岗位未填写'}'),
                  subtitle: Text('开始：${item['startTime'] ?? '未填写'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          InterviewAppointmentDetailPage(appointment: item),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_textOr(widget.talent['name'], '候选人详情'))),
      body: _buildBody(),
    );
  }

  /// 三态：加载中（骨架屏）/ 失败（可重试）/ 内容。
  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 2);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: _error!,
        actionLabel: '重试',
        onAction: _load,
      );
    }
    if (_detail == null || _detail!.isEmpty) {
      return PageMessage(
        icon: Icons.person_search_outlined,
        title: '暂无候选人详情',
        message: '接口未返回候选人信息',
        actionLabel: '重试',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), _loadInterviews()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildBasicCard(),
          const SizedBox(height: 16),
          const SectionTitle('简历解析结果'),
          ..._buildResumeViews(),
          const SizedBox(height: 16),
          _buildInterviewSection(),
        ],
      ),
    );
  }

  /// 基本信息卡：resume 返回姓名/联系方式/求职方向，detail 返回阶段状态。
  Widget _buildBasicCard() {
    final resume = _resume!;
    final detail = _detail!;
    final name = _textOr(
      resume['name'] ?? detail['name'] ?? widget.talent['name'],
      '未知候选人',
    );
    final stage = _talentStatusLabel(detail['status']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    name.substring(0, 1),
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
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '$stage · 投递方向：${_textOr(resume['jobDirection'] ?? detail['jobDirection'], '未填写')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_textOr(resume['phone'] ?? detail['phone'], '未填写手机号')} · ${_textOr(resume['email'] ?? detail['email'], '未填写邮箱')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// 简历解析结果区块（含完整度/缺失字段，UC-02 步骤5，P8 从列表卡片移入详情页）。
  List<Widget> _buildResumeViews() {
    final resume = _resume!;
    final educationList =
        (resume['educationList'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final workList =
        (resume['workList'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final projectList =
        (resume['projectList'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final skills =
        (resume['skills'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final missing =
        (resume['missingFields'] as List?)?.map((f) => '$f').toList() ??
        const <String>[];
    final integrity =
        num.tryParse('${resume['integrity']}')?.round().clamp(0, 100) ?? 0;
    return [
      // 完整度检查（UC-02 步骤5）
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (integrity / 100).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        backgroundColor: AppColors.hairline,
                        color: integrity >= 90
                            ? AppColors.green
                            : AppColors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '完整度 $integrity%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '缺失：${missing.join('、')}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.orange),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      _ResumeSection(
        title: '教育经历',
        children: educationList.isEmpty
            ? const [_EmptyHint('暂无教育经历记录')]
            : educationList
                  .map(
                    (item) => _InfoRow(
                      title:
                          '${item['school'] ?? '-'} · ${_degreeLabel(item['degree'])}',
                      subtitle:
                          '${item['major'] ?? '-'}（${_period(item['startDate'], item['endDate'])}）',
                    ),
                  )
                  .toList(),
      ),
      _ResumeSection(
        title: '工作经历',
        children: workList.isEmpty
            ? const [_EmptyHint('暂无工作经历记录')]
            : workList
                  .map(
                    (item) => _InfoRow(
                      title:
                          '${item['company'] ?? '-'} · ${item['position'] ?? '-'}',
                      subtitle:
                          '${_period(item['startDate'], item['endDate'])}'
                          '${item['summary'] == null ? '' : '\n${item['summary']}'}',
                    ),
                  )
                  .toList(),
      ),
      _ResumeSection(
        title: '项目经验',
        children: projectList.isEmpty
            ? const [_EmptyHint('暂无项目经验记录')]
            : projectList
                  .map(
                    (item) => _InfoRow(
                      title: '${item['name'] ?? '-'}（${item['role'] ?? '-'}）',
                      subtitle: [
                        if (item['techStack'] != null)
                          '技术栈：${item['techStack']}',
                        if (item['summary'] != null) '${item['summary']}',
                      ].join('\n'),
                    ),
                  )
                  .toList(),
      ),
      _ResumeSection(
        title: '技能标签',
        children: skills.isEmpty
            ? const [_EmptyHint('暂无技能标签记录')]
            : [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skills.map((s) {
                    final level = _levelLabel(s['level']);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        level.isEmpty ? '${s['name']}' : '${s['name']}·$level',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.interactive,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
      ),
    ];
  }
}

/// 接口异常 → 友好文案。
String _friendlyError(Object e) =>
    e is ApiException ? e.message : '网络异常，请检查网络后重试';

/// 候选人状态字典（sys_dict_data: candidate_status）。
/// 与 talent_page.dart 的映射一致（页面层各自维护，不改公共文件）。
String _talentStatusLabel(Object? status) {
  return switch (int.tryParse('$status')) {
    0 => '新入库',
    1 => '初筛通过',
    2 => '面试中',
    3 => '已淘汰',
    4 => '已录用',
    5 => '已入职',
    6 => '已放弃',
    7 => '人才库',
    8 => '黑名单',
    9 => '流程挂起',
    _ => '未知状态',
  };
}

/// 学历字典（t_res_education.edu_degree，与岗位学历字典一致）。
String _degreeLabel(Object? degree) {
  return switch (int.tryParse('$degree')) {
    1 => '中专',
    2 => '大专',
    3 => '本科',
    4 => '硕士',
    5 => '博士',
    _ => '学历未填写',
  };
}

/// 技能熟练度字典（t_res_skill.skl_level：1了解/2熟悉/3精通/4专家）。
String _levelLabel(Object? level) {
  return switch (int.tryParse('$level')) {
    1 => '了解',
    2 => '熟悉',
    3 => '精通',
    4 => '专家',
    _ => '',
  };
}

String _textOr(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// 起止时间拼接（后端已格式化为 yyyy-MM，含"至今"）。
String _period(Object? start, Object? end) {
  final s = start == null ? '' : '$start';
  final e = end == null ? '' : '$end';
  if (s.isEmpty && e.isEmpty) return '时间未填写';
  return '${s.isEmpty ? '时间未填写' : s} ~ ${e.isEmpty ? '时间未填写' : e}';
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
    );
  }
}

class _ResumeSection extends StatelessWidget {
  const _ResumeSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.brand,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
