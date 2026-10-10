import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import 'mock_interview.dart';

/// 模块四：面试入口与准备 - 在线实操环境预加载页（P3）。
///
/// 依据《业务功能分析》UC-11（在线实操环境预加载）：
/// 技术类岗位且面试模式包含实操环节的场次，在准备阶段异步预加载
/// 在线实操考核环境（代码沙箱、云端 IDE），确保候选人正式进入
/// 面试时无需等待环境初始化。
/// 数据来源：本地 Mock 数据（mock_interview.dart 的 mockPracticeSteps），
/// TODO: P7阶段替换为真实接口（lib/api/practice_api.dart 的
/// preloadPracticeEnvironment / getPracticePreloadStatus）。
class PracticePreloadPage extends StatefulWidget {
  const PracticePreloadPage({super.key});

  @override
  State<PracticePreloadPage> createState() => _PracticePreloadPageState();
}

/// 步骤状态：waiting=待执行 / running=进行中 / done=已完成
enum _StepState { waiting, running, done }

class _PracticePreloadPageState extends State<PracticePreloadPage> {
  final List<_StepState> _steps = List.filled(
    mockPracticeSteps.length,
    _StepState.waiting,
  );
  bool _preloading = false;
  bool _ready = false;
  double _progress = 0;

  /// 模拟实操环境预加载：逐步推进各步骤直至就绪。
  /// TODO: P7阶段替换为真实接口（practice_api.preloadPracticeEnvironment）。
  Future<void> _startPreload() async {
    setState(() {
      _preloading = true;
      _ready = false;
      _progress = 0;
      for (var i = 0; i < _steps.length; i++) {
        _steps[i] = _StepState.waiting;
      }
    });
    for (var i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() => _steps[i] = _StepState.running);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _steps[i] = _StepState.done;
        _progress = (i + 1) / _steps.length;
      });
    }
    if (!mounted) return;
    setState(() {
      _preloading = false;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('实操环境预加载')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.terminal_outlined,
                          size: 20,
                          color: _ready
                              ? AppColors.green
                              : AppColors.interactive,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ready ? '实操环境已就绪' : '在线实操考核环境',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '技术类岗位面试前异步预加载代码沙箱与云端 IDE，'
                      '确保候选人正式进入面试时无需等待环境初始化（UC-11，模拟）',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_preloading || _ready) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 6,
                          backgroundColor: AppColors.hairline,
                          color: _ready
                              ? AppColors.green
                              : AppColors.interactive,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('预加载进度'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (var i = 0; i < mockPracticeSteps.length; i++)
                      _StepRow(
                        index: i,
                        step: mockPracticeSteps[i],
                        state: _steps[i],
                        isLast: i == mockPracticeSteps.length - 1,
                      ),
                  ],
                ),
              ),
            ),
            if (_ready) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            size: 18,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '环境信息',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '云端 IDE：https://ide.example.com/s/8801（模拟）',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '考核入口将在候选人进入面试房间后自动加载，无需二次等待',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!_preloading && !_ready)
              FilledButton.icon(
                onPressed: _startPreload,
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('开始预加载'),
              )
            else if (_preloading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('环境预加载中…'),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _startPreload,
                icon: const Icon(Icons.refresh),
                label: const Text('重新预加载'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.state,
    required this.isLast,
  });

  final int index;
  final Map<String, dynamic> step;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      _StepState.done => (Icons.check_circle, AppColors.green),
      _StepState.running => (Icons.hourglass_top, AppColors.interactive),
      _ => (Icons.radio_button_unchecked, AppColors.hairline),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(icon, size: 20, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: state == _StepState.done
                        ? AppColors.green
                        : AppColors.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${step['name']}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: state == _StepState.done
                          ? AppColors.green
                          : AppColors.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${step['desc']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
