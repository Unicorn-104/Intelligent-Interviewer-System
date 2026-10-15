import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import 'mock_interview.dart';

/// 模块四：面试入口与准备 - 设备检测页（P3）。
///
/// 依据《业务功能分析》UC-10 步骤5-7：
/// 依次执行摄像头检测（捕获视频流）、麦克风检测（音量波形）、
/// 网络检测（RTT<300ms 且带宽>1Mbps 为"良好"），
/// 生成绿/黄/红设备检测报告卡；全部绿色才启用"进入面试"按钮，
/// 黄色/红色显示修复建议（E4/E5 扩展流程）。
///
/// 模拟说明：Flutter 无法直接调用摄像头/麦克风权限（需原生插件），
/// 本页用定时器模拟检测流程依次点亮状态灯。
/// TODO: P7接入真实设备检测插件（camera/permission_handler 等），
/// 并替换为真实接口（lib/api/interview_room_api.dart 的 checkEnvironment）。
class DeviceCheckPage extends StatefulWidget {
  const DeviceCheckPage({super.key});

  @override
  State<DeviceCheckPage> createState() => _DeviceCheckPageState();
}

/// 检测状态：idle=待检测 / checking=检测中 / pass / warn / fail
enum _CheckState { idle, checking, pass, warn, fail }

class _DeviceCheckPageState extends State<DeviceCheckPage> {
  final Map<String, _CheckState> _states = {
    'camera': _CheckState.idle,
    'mic': _CheckState.idle,
    'network': _CheckState.idle,
  };
  bool _checking = false;

  /// 模拟设备检测流程：定时器依次点亮摄像头绿灯 → 麦克风绿灯 → 网络黄灯。
  /// TODO: P7接入真实设备检测插件后替换本方法。
  Future<void> _startCheck() async {
    setState(() {
      _checking = true;
      for (final key in _states.keys) {
        _states[key] = _CheckState.idle;
      }
    });
    const sequence = [
      ('camera', _CheckState.checking, Duration(milliseconds: 500)),
      ('camera', _CheckState.pass, Duration(milliseconds: 500)),
      ('mic', _CheckState.checking, Duration(milliseconds: 500)),
      ('mic', _CheckState.pass, Duration(milliseconds: 500)),
      ('network', _CheckState.checking, Duration(milliseconds: 500)),
      ('network', _CheckState.warn, Duration(milliseconds: 300)),
    ];
    for (final (key, state, delay) in sequence) {
      if (!mounted) return;
      setState(() => _states[key] = state);
      await Future<void>.delayed(delay);
    }
    if (mounted) setState(() => _checking = false);
  }

  bool get _allPass =>
      _states.values.every((s) => s == _CheckState.pass) && !_checking;

  bool get _hasWarnOrFail =>
      _states.values.contains(_CheckState.warn) ||
      _states.values.contains(_CheckState.fail);

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('设备检测')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 检测报告卡（UC-10 步骤6：绿/黄/红状态灯，页面固定展示）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _CheckItem(
                      icon: Icons.videocam_outlined,
                      label:
                          mockDeviceCheckResult['camera']!['label'] as String,
                      state: _states['camera']!,
                      message:
                          mockDeviceCheckResult['camera']!['message'] as String,
                      suggestion:
                          mockDeviceCheckResult['camera']!['suggestion']
                              as String?,
                    ),
                    const Divider(height: 20),
                    _CheckItem(
                      icon: Icons.mic_none,
                      label: mockDeviceCheckResult['mic']!['label'] as String,
                      state: _states['mic']!,
                      message:
                          mockDeviceCheckResult['mic']!['message'] as String,
                      suggestion:
                          mockDeviceCheckResult['mic']!['suggestion']
                              as String?,
                    ),
                    const Divider(height: 20),
                    _CheckItem(
                      icon: Icons.wifi_outlined,
                      label:
                          mockDeviceCheckResult['network']!['label'] as String,
                      state: _states['network']!,
                      message:
                          mockDeviceCheckResult['network']!['message']
                              as String,
                      suggestion:
                          mockDeviceCheckResult['network']!['suggestion']
                              as String?,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_checking &&
                _states.values.every((s) => s == _CheckState.idle))
              FilledButton.icon(
                onPressed: _startCheck,
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始检测'),
              )
            else if (_checking)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('正在检测设备与环境…'),
                ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: _startCheck,
                icon: const Icon(Icons.refresh),
                label: const Text('重新检测'),
              ),
              const SizedBox(height: 10),
              // 全部绿色才启用"进入面试"（UC-10 步骤7）
              FilledButton.icon(
                onPressed: _allPass ? _enterInterview : null,
                icon: const Icon(Icons.meeting_room_outlined),
                label: Text(_allPass ? '准备就绪，进入面试' : '存在异常项，进入面试按钮已禁用'),
              ),
              if (_hasWarnOrFail && !_allPass) ...[
                const SizedBox(height: 10),
                // E5：允许候选人忽略风险继续进入（记录风险标记）
                OutlinedButton.icon(
                  onPressed: _enterInterview,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: const Text('忽略风险，继续进入（记录风险标记）'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 模拟进入面试（会话状态标记"已就绪"，控制权交接模块五）。
  /// TODO: P7阶段替换为真实接口（interview_room_api.startSession）。
  void _enterInterview() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('会话状态已标记"已就绪"（模拟），进入模块五面试房间')));
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.icon,
    required this.label,
    required this.state,
    required this.message,
    this.suggestion,
  });

  final IconData icon;
  final String label;
  final _CheckState state;
  final String message;
  final String? suggestion;

  @override
  Widget build(BuildContext context) {
    final (lightColor, stateLabel) = switch (state) {
      _CheckState.pass => (AppColors.green, '正常'),
      _CheckState.warn => (AppColors.orange, '不佳'),
      _CheckState.fail => (AppColors.red, '失败'),
      _CheckState.checking => (AppColors.interactive, '检测中'),
      _ => (AppColors.hairline, '待检测'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.bodySoft),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  // 状态灯
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: lightColor,
                      shape: BoxShape.circle,
                      boxShadow: state != _CheckState.idle
                          ? [
                              BoxShadow(
                                color: lightColor.withValues(alpha: 0.5),
                                blurRadius: 5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    stateLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: lightColor),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
              if (suggestion != null &&
                  (state == _CheckState.warn || state == _CheckState.fail)) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '修复建议：$suggestion',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.orange),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
