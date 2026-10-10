import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_screening.dart';

/// 模块二：AI 初筛与短名单 - 个性化招呼语页（P2）。
///
/// 依据《业务功能分析》UC-05 步骤8：
/// 为短名单 Top 3 候选人调用话术生成模板，填充简历亮点，
/// 生成个性化招呼语，HR 复核确认后发送。
/// 数据来源：本地 Mock 数据（mock_screening.dart 的 greeting 字段），
/// TODO: P7阶段替换为真实接口（lib/api/screening_api.dart 的 getGreetingMessage）。
class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage> {
  List<Map<String, dynamic>>? _top3;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载 Top 3 个性化招呼语。
  /// TODO: P7阶段替换为真实接口（screening_api.getGreetingMessage）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _top3 = mockScreeningResults
          .where((c) => c['top3'] == true && c['greeting'] != null)
          .toList();
      _loading = false;
    });
  }

  Future<void> _copy(Map<String, dynamic> candidate) async {
    await Clipboard.setData(ClipboardData(text: '${candidate['greeting']}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制「${candidate['name']}」的招呼语（模拟）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('Top 3 个性化招呼语')),
        body: _loading ? const SkeletonList(rows: 3) : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final top3 = _top3 ?? const <Map<String, dynamic>>[];
    if (top3.isEmpty) {
      return const PageMessage(
        icon: Icons.waving_hand_outlined,
        title: '暂无招呼语',
        message: '筛选完成后，系统将为短名单 Top 3 自动生成个性化招呼语',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: top3.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final candidate = top3[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          '${candidate['name']}'.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.interactive,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${candidate['name']}（#${candidate['rank']} · ${candidate['totalScore']} 分）',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'AI 生成',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.interactive,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${candidate['greeting']}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copy(candidate),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
