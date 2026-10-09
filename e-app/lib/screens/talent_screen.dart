import 'package:flutter/material.dart';

import '../features/enterprise/enterprise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/page_states.dart';

class TalentScreen extends StatefulWidget {
  const TalentScreen({super.key, required this.repository});
  final EnterpriseRepository repository;

  @override
  State<TalentScreen> createState() => _TalentScreenState();
}

class _TalentScreenState extends State<TalentScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>>? _candidates;
  Map<String, dynamic>? _interview;
  String? _candidateError;
  String? _interviewError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadCandidates();
    _loadInterview();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    setState(() => _candidateError = null);
    try {
      final data = await widget.repository.candidates();
      if (mounted) setState(() => _candidates = data);
    } catch (e) {
      if (mounted) setState(() => _candidateError = e.toString());
    }
  }

  Future<void> _loadInterview() async {
    setState(() => _interviewError = null);
    try {
      final data = await widget.repository.currentInterview();
      if (mounted) setState(() => _interview = data ?? const {});
    } catch (e) {
      if (mounted) setState(() => _interviewError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text('人才与面试', style: Theme.of(context).textTheme.titleLarge),
          ),
          TabBar(controller: _tabs, tabs: const [Tab(text: '候选人'), Tab(text: '面试安排')]),
          Expanded(child: TabBarView(controller: _tabs, children: [_candidateBody(), _interviewBody()])),
        ],
      );

  Widget _candidateBody() {
    if (_candidates == null && _candidateError == null) return const PageLoading();
    if (_candidateError != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '候选人加载失败', message: _candidateError!, onAction: _loadCandidates);
    if (_candidates!.isEmpty) return PageMessage(icon: Icons.people_outline, title: '暂无候选人', message: '候选人将在投递岗位并进入招聘流程后显示', onAction: _loadCandidates);
    return RefreshIndicator(
      onRefresh: _loadCandidates,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _candidates!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final item = _candidates![index];
          final score = item['matchScore'] ?? 0;
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(backgroundColor: AppColors.primarySoft, child: Text(_initial('${item['name'] ?? '候'}'))),
              title: Row(children: [Expanded(child: Text('${item['name'] ?? '候选人'}')), Text('$score%', style: const TextStyle(color: AppColors.interactive, fontWeight: FontWeight.w600))]),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${item['positionTitle'] ?? '未关联岗位'} · ${item['currentStage'] ?? item['statusLabel'] ?? '流程处理中'}'),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }

  Widget _interviewBody() {
    if (_interview == null && _interviewError == null) return const PageLoading();
    if (_interviewError != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '面试安排加载失败', message: _interviewError!, onAction: _loadInterview);
    if (_interview!.isEmpty) return PageMessage(icon: Icons.event_available_outlined, title: '暂无待开始面试', message: '后端当前返回当前用户最近的待开始或进行中场次', onAction: _loadInterview);
    final item = _interview!;
    return RefreshIndicator(
      onRefresh: _loadInterview,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.ink, AppColors.brandDeep]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.video_call_outlined, color: Colors.white), SizedBox(width: 8), Text('即将开始的面试', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
              const SizedBox(height: 18),
              Text('${item['positionTitle'] ?? item['title'] ?? '面试场次'}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('候选人：${item['candidateName'] ?? '-'}', style: const TextStyle(color: Colors.white70)),
              Text('时间：${item['startTime'] ?? item['scheduledAt'] ?? '-'}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 18),
              const Text('AI 面试建议仅供辅助参考', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),
          const Card(child: ListTile(leading: Icon(Icons.devices_outlined, color: AppColors.interactive), title: Text('设备检测与会议入口'), subtitle: Text('音视频能力沿用后端 Conference 场次接口；进入会议前请检查摄像头、麦克风和网络。'))),
        ],
      ),
    );
  }

  String _initial(String value) => value.isEmpty ? '候' : value.characters.first;
}
