import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_execution.dart';

/// 模块五：面试执行与级联评估 - 面试回放页（P4）。
///
/// 依据《业务功能分析》UC-12 后置条件1：面试全过程的音视频录制与存储（合规存档）。
/// 提供录播列表、回放入口、下载码申请与下载入口（模拟）。
/// 数据来源：本地 Mock 数据（mock_execution.dart 的 mockRecordings），
/// TODO: P7阶段替换为真实接口（lib/api/interview_room_api.dart 的
/// listRecordings / getRecordingPlayback / requestRecordingDownloadCode /
/// downloadRecording / getStoragePolicy）。
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  List<Map<String, dynamic>>? _recordings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载录播列表。
  /// TODO: P7阶段替换为真实接口（interview_room_api.listRecordings）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _recordings = List.of(mockRecordings);
      _loading = false;
    });
  }

  /// 模拟申请下载码。
  /// TODO: P7阶段替换为真实接口（requestRecordingDownloadCode / downloadRecording）。
  Future<void> _download(Map<String, dynamic> item) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('申请下载码'),
        content: Text(
          '「${item['candidateName']}」的面试录制（${item['size']}）\n'
          '下载码：${(item['sessionId'] as int) * 7}${'0' * 6}-DL（模拟）\n'
          '下载码 24 小时内有效，下载行为将被审计记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('已发起下载（模拟）')),
              );
            },
            child: const Text('开始下载'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('面试回放')),
        body: _loading
            ? const SkeletonList(rows: 3)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // 存储策略提示（UC-12 合规存档）
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: AppColors.interactive,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '录制存储策略：本地加密存储，保留 90 天，下载需审计授权（模拟）',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final item
                        in _recordings ?? const <Map<String, dynamic>>[])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['candidateName']} · ${item['positionName']}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${item['mode']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item['date']} · ${item['duration']} · ${item['size']}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '开始回放「${item['candidateName']}」的面试（模拟）',
                                              ),
                                            ),
                                          ),
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                        size: 16,
                                      ),
                                      label: const Text('回放'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _download(item),
                                      icon: const Icon(
                                        Icons.download_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('下载'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 34),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
