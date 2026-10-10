import 'dart:async';

import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import 'mock_execution.dart';

/// 模块五：面试执行工作台（P4 核心页）——AI 面试实时监控 + HR 协同提词。
///
/// 依据《业务功能分析》UC-12（多模式 AI 面试执行）与 UC-14（HR 协同面试与实时提词）：
/// - 上方：面试对话区（实时字幕流，ASR 转写）
/// - 下方：AI 提词建议卡片（考察维度 + 评分要点 + 参考答案），
///   HR 可"采纳提问/编辑后提问/忽略，自由提问"（UC-14 B4）
/// - 操作：人工接管 / 结束面试 / 异常终止（UC-12 E1 强制中断兜底）
///
/// 数据来源：本地 Mock 数据（mock_execution.dart），字幕自动滚动模拟实时转写。
/// TODO: P7阶段替换为真实接口（lib/api/interview_room_api.dart 的
/// getCaptions / getCopilotSuggestions / handleCopilotSuggestion /
/// takeOverSession / finishSession / abortSession）。
class InterviewWorkbenchPage extends StatefulWidget {
  const InterviewWorkbenchPage({super.key});

  @override
  State<InterviewWorkbenchPage> createState() => _InterviewWorkbenchPageState();
}

class _InterviewWorkbenchPageState extends State<InterviewWorkbenchPage> {
  final ScrollController _captionsScroll = ScrollController();
  final List<Map<String, dynamic>> _captions = [];
  List<Map<String, dynamic>> _copilotQueue = List.of(mockCopilotQueue);
  Map<String, dynamic>? _currentSuggestion;
  Timer? _timer;
  int _captionCursor = 0;
  int _elapsed = 18;
  bool _takenOver = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _currentSuggestion = _copilotQueue.isNotEmpty ? _copilotQueue.first : null;
    // 模拟实时字幕流：每 3.5 秒推进一句
    _timer = Timer.periodic(
      const Duration(milliseconds: 3500),
      (_) => _advance(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _captionsScroll.dispose();
    super.dispose();
  }

  /// 模拟字幕推进（UC-12 A2：ASR 实时获取回答文本）。
  /// TODO: P7阶段替换为真实接口（interview_room_api.getCaptions 增量轮询）。
  void _advance() {
    if (_ended || !mounted) return;
    if (_captionCursor >= mockCaptionQueue.length) {
      _timer?.cancel();
      return;
    }
    setState(() {
      _captions.add(
        Map<String, dynamic>.from(mockCaptionQueue[_captionCursor]),
      );
      _captionCursor++;
      _elapsed = (_elapsed + 3).clamp(18, 44);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_captionsScroll.hasClients) {
        _captionsScroll.animateTo(
          _captionsScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 采纳提词建议（UC-14 B4：采纳提问）。
  /// TODO: P7阶段替换为真实接口（interview_room_api.handleCopilotSuggestion）。
  void _adopt(String? text) {
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _captions.add({
        'seq': 900 + _captions.length,
        'speaker': 'HR',
        'text': text.trim(),
        'time': '刚刚',
      });
      _nextSuggestion();
    });
  }

  /// 编辑后采纳（UC-14 B4：编辑后提问）。
  void _editAndAdopt() {
    final controller = TextEditingController(
      text: '${_currentSuggestion?['question']}',
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑提问'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '修改 AI 建议的提问内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _adopt(controller.text);
            },
            child: const Text('提问'),
          ),
        ],
      ),
    );
  }

  /// 忽略建议，自由提问（UC-14 B4）。
  void _ignore() => setState(_nextSuggestion);

  void _nextSuggestion() {
    if (_copilotQueue.isEmpty) {
      _currentSuggestion = null;
      return;
    }
    _copilotQueue = _copilotQueue.sublist(1);
    _currentSuggestion = _copilotQueue.isNotEmpty ? _copilotQueue.first : null;
  }

  /// 人工接管 / 结束 / 异常终止（模拟，弹确认）。
  /// TODO: P7阶段替换为真实接口（takeOverSession / finishSession / abortSession）。
  Future<void> _action(String type) async {
    final messenger = ScaffoldMessenger.of(context);
    final (title, message) = switch (type) {
      'takeover' => ('人工接管', '接管后 AI 转为静默监听，由 HR 主导对话（模拟）'),
      'finish' => ('结束面试', '结束后将自动进入评估阶段，生成五维评分卡与评语（模拟）'),
      _ => ('异常终止', '将礼貌挂断并释放资源，面试标记为"异常终止"，通知 HR 复核（模拟）'),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确认$title'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      switch (type) {
        case 'takeover':
          _takenOver = true;
        case 'finish':
        case 'abort':
          _ended = true;
          _timer?.cancel();
      }
    });
    messenger.showSnackBar(SnackBar(content: Text('已$title（模拟）')));
  }

  @override
  Widget build(BuildContext context) {
    final session = mockExecutionSession;
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${session['candidateName']} · ${session['positionName']}',
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${session['mode']}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.interactive,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildProgressBar(session),
            // 上：对话区（字幕流）
            Expanded(flex: 5, child: _buildCaptionArea()),
            // 下：AI 提词建议卡片
            Expanded(flex: 6, child: _buildCopilotArea()),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Map<String, dynamic> session) {
    final total = session['totalMinutes'] as int;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _elapsed / total,
                    minHeight: 6,
                    backgroundColor: AppColors.hairline,
                    color: _ended ? AppColors.muted : AppColors.interactive,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_elapsed / $total 分钟',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _ended
                    ? '面试已结束'
                    : _takenOver
                    ? 'HR 主导模式（AI 静默监听）'
                    : 'AI 实时监控中 · 第 ${session['questionIndex']} / ${session['totalQuestions']} 问',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _ended ? AppColors.muted : AppColors.green,
                ),
              ),
              const Spacer(),
              if (!_ended)
                TextButton.icon(
                  onPressed: _advance,
                  icon: const Icon(Icons.fast_forward, size: 16),
                  label: const Text('模拟推进'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.subtitles_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  '实时字幕（ASR 转写）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _captions.isEmpty
                ? const Center(child: Text('等待对话开始…'))
                : ListView.builder(
                    controller: _captionsScroll,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _captions.length,
                    itemBuilder: (_, index) =>
                        _CaptionBubble(item: _captions[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopilotArea() {
    final suggestion = _currentSuggestion;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.interactive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.interactive,
              ),
              const SizedBox(width: 6),
              Text('AI 提词建议', style: Theme.of(context).textTheme.titleMedium),
              if (_ended) ...[
                const SizedBox(width: 8),
                Text('（面试已结束）', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (suggestion == null)
            const Expanded(child: Center(child: Text('暂无更多建议，HR 可自由提问')))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.interactive),
                          ),
                          child: Text(
                            '考察维度：${suggestion['dimension']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.interactive,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '建议 #${suggestion['id']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${suggestion['question']}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '评分要点',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final point
                        in (suggestion['scoringPoints'] as List).cast<String>())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(
                                Icons.circle,
                                size: 5,
                                color: AppColors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${suggestion['reference']}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (suggestion != null && !_ended)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _ignore, child: const Text('忽略，自由提问')),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _editAndAdopt,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text('编辑'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _adopt('${suggestion['question']}'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 34)),
                  child: const Text('采纳提问'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _ended ? null : () => _action('takeover'),
              icon: const Icon(Icons.pan_tool_alt_outlined, size: 16),
              label: const Text('人工接管'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _ended ? null : () => _action('finish'),
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('结束面试'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _ended ? null : () => _action('abort'),
              icon: const Icon(Icons.warning_amber_outlined, size: 16),
              label: const Text('异常终止'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                side: const BorderSide(color: AppColors.orange),
                foregroundColor: AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 字幕气泡：AI/HR 左侧、候选人右侧。
class _CaptionBubble extends StatelessWidget {
  const _CaptionBubble({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final speaker = item['speaker'] as String;
    final isCandidate = speaker == 'CAND';
    final (label, color, bg) = switch (speaker) {
      'CAND' => (
        '候选人',
        AppColors.green,
        AppColors.green.withValues(alpha: 0.08),
      ),
      'HR' => (
        'HR',
        AppColors.purple,
        AppColors.purple.withValues(alpha: 0.06),
      ),
      _ => ('AI', AppColors.interactive, AppColors.primarySoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isCandidate ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: isCandidate
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item['text']}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
