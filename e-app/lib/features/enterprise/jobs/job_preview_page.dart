import 'package:flutter/material.dart';

import '../../../api/jobs_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

/// 岗位预览：按求职者端（C-APP 职位详情）视角展示当前岗位的最新公开数据。
///
/// 数据来源与求职者端一致（GET /agent/v1/jobs/{jobId}），仅用于预览，
/// 页面内不提供真实投递、收藏等求职者操作。
class JobPreviewPage extends StatefulWidget {
  const JobPreviewPage({super.key, required this.positionId, this.load});

  final int positionId;
  final Future<Map<String, dynamic>> Function()? load;

  @override
  State<JobPreviewPage> createState() => _JobPreviewPageState();
}

class _JobPreviewPageState extends State<JobPreviewPage> {
  Map<String, dynamic>? _job;
  String? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await (widget.load ??
              () => getCandidateJobPreview(widget.positionId))();
      if (!mounted || request != _request) return;
      final id = int.tryParse('${data['id']}');
      if (id != widget.positionId) {
        throw const FormatException('预览岗位标识不一致');
      }
      setState(() => _job = data);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  static String _friendlyError(Object error) => switch (error) {
    ApiException() => error.message,
    FormatException() => error.message.toString(),
    _ => '预览加载失败，请稍后重试',
  };

  String _text(Object? value, {String fallback = ''}) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  List<String> _lines(Object? value) => value is List
      ? value
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
      : const [];

  String get _salary {
    final text = _text(_job?['salaryText']);
    if (text.isNotEmpty) return text;
    final min = num.tryParse('${_job?['salaryMin']}');
    final max = num.tryParse('${_job?['salaryMax']}');
    if (min == null && max == null) return '面议';
    return '¥${min ?? '未填写'} - ${max ?? '未填写'} / 月';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('岗位预览'),
      backgroundColor: AppColors.canvas,
    ),
    body: _body(context),
    bottomNavigationBar: _bottomBar(),
  );

  Widget _body(BuildContext context) {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null || _job == null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '预览加载失败',
        message: _error ?? '暂无岗位数据',
        onAction: _load,
      );
    }
    final job = _job!;
    final meta = [
      _text(job['workCity'], fallback: '城市未填写'),
      _text(job['experienceRequired'], fallback: '经验不限'),
      _text(job['educationText'], fallback: '学历不限'),
    ].join(' · ');
    final responsibilities = _lines(job['responsibilities']);
    final requirements = _lines(job['requirements']);
    final skills = _lines(job['skills']);
    final companyName = _text(job['companyName'], fallback: '企业未填写');
    final companyMeta = [
      _text(job['companyIndustry']),
      _text(job['companySize']),
      _text(job['companyCity']),
    ].where((s) => s.isNotEmpty).join(' · ');
    final companyIntro = _text(job['companyIntro']);
    final logo = _text(job['companyLogoUrl']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey('job-preview-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            key: const Key('job-preview-banner'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '求职者视角预览 · 与求职者端岗位详情同源数据',
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _text(job['title'], fallback: '未命名岗位'),
            key: const Key('job-preview-title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _salary,
            key: const Key('job-preview-salary'),
            style: const TextStyle(
              color: AppColors.accentOrange,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(meta, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Text('职位描述', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            responsibilities.isEmpty
                ? '岗位职责和详细说明由招聘企业持续完善，请以招聘方最新信息为准。'
                : responsibilities.join('\n'),
          ),
          const SizedBox(height: 24),
          Text('任职要求', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            requirements.isNotEmpty
                ? requirements.map((s) => '• $s').join('\n')
                : skills.isNotEmpty
                ? skills.map((s) => '• 熟悉或掌握 $s').join('\n')
                : '具体任职要求请与招聘方进一步确认。',
          ),
          const SizedBox(height: 24),
          Container(
            key: const Key('job-preview-company-card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.interactive,
                      foregroundImage: logo.isNotEmpty
                          ? NetworkImage(logo)
                          : null,
                      child: Text(
                        companyName.isEmpty ? '企' : companyName.substring(0, 1),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            companyMeta.isEmpty ? '企业信息待完善' : companyMeta,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (companyIntro.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    companyIntro,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          key: const Key('job-preview-apply'),
          onPressed: null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          child: const Text('立即投递（预览，求职者端可操作）'),
        ),
        const SizedBox(height: 6),
        const Text(
          '预览页不可投递、收藏或联系候选人',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}
