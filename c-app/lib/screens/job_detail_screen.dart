import 'package:flutter/material.dart';

import '../models/job.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/companies/presentation/company_screen.dart';
import '../theme/app_theme.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.job, required this.session, this.onApply});

  final Job job;
  final AuthSession session;
  final Future<bool> Function(Job job)? onApply;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _applying = false;
  bool _applied = false;

  Job get job => widget.job;

  @override
  void initState() {
    super.initState();
    _applied = job.applied;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('职位详情'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_border)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          Text(job.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            job.salary,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text('${job.city} · ${job.experience} · ${job.educationLabel}'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.interactive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 匹配度 ${job.matchLabel}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.interactive,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(job.matchAvailable ? '简历与岗位要求契合度较高，建议投递。AI 结果仅供参考。' : '暂未提供匹配评估，请结合岗位要求判断是否投递。'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('职位描述', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            job.description?.isNotEmpty == true
                ? job.description!
                : '岗位职责和详细说明由招聘企业持续完善，请以招聘方最新信息为准。',
          ),
          const SizedBox(height: 24),
          Text('任职要求', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            job.tags.isEmpty
                ? '具体任职要求请与招聘方进一步确认。'
                : job.tags.map((tag) => '• 熟悉或掌握 $tag').join('\n'),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              onTap: job.companyId != null && job.companyId! > 0
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CompanyScreen(
                          session: widget.session,
                          companyId: job.companyId!,
                        ),
                      ),
                    )
                  : null,
                            contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: job.accent,
                child: Text(
                  job.company.isEmpty ? '企' : job.company.substring(0, 1),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(job.company),
              subtitle: Text(job.companyVerified ? '认证企业' : '企业信息待认证'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: FilledButton(
          onPressed: _applied || _applying || widget.onApply == null
              ? null
              : _apply,
          child: _applying
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_applied ? '已投递' : '立即投递'),
        ),
      ),
    );
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    final success = await widget.onApply!(job);
    if (!mounted) return;
    setState(() {
      _applying = false;
      if (success) _applied = true;
    });
  }
}
