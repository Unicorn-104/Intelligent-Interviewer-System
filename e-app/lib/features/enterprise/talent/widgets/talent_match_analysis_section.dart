import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_match_radar.dart';

/// Local to candidate details so shared app components stay unchanged.
class TalentAiInfoButton extends StatefulWidget {
  const TalentAiInfoButton({super.key});

  static const message = 'AI 结果仅供参考，评分和报告基于模型分析，不构成录用结论';

  @override
  State<TalentAiInfoButton> createState() => _TalentAiInfoButtonState();
}

class _TalentAiInfoButtonState extends State<TalentAiInfoButton> {
  final _tooltip = GlobalKey<TooltipState>();

  void _show() => _tooltip.currentState?.ensureTooltipVisible();

  @override
  Widget build(BuildContext context) => Tooltip(
    key: _tooltip,
    message: TalentAiInfoButton.message,
    triggerMode: TooltipTriggerMode.manual,
    showDuration: const Duration(seconds: 6),
    constraints: const BoxConstraints(maxWidth: 280),
    child: GestureDetector(
      onLongPress: _show,
      child: IconButton(
        onPressed: _show,
        icon: const Icon(Icons.info_outline, size: 18),
        color: AppColors.muted,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    ),
  );
}

class TalentSectionFrame extends StatelessWidget {
  const TalentSectionFrame({
    super.key,
    required this.title,
    this.loading = false,
    this.error,
    this.empty = false,
    this.emptyText = '暂无数据',
    required this.onRetry,
    this.child,
    this.ai = false,
    this.embedded = false,
  });

  final String title;
  final bool loading, empty, ai, embedded;
  final String? error;
  final String emptyText;
  final VoidCallback onRetry;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty || ai) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (ai) const TalentAiInfoButton(),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (loading)
          const LinearProgressIndicator()
        else if (error != null) ...[
          Text(error!),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ] else if (empty) ...[
          Text(emptyText, style: const TextStyle(color: AppColors.muted)),
          TextButton(onPressed: onRetry, child: const Text('刷新')),
        ] else
          ?child,
      ],
    );
    if (embedded) return content;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(padding: const EdgeInsets.all(14), child: content),
      ),
    );
  }
}

/// Preserve the full source text while keeping long summaries compact initially.
class TalentExpandableText extends StatefulWidget {
  const TalentExpandableText({
    super.key,
    required this.text,
    this.maxLines = 3,
  });
  final String text;
  final int maxLines;

  @override
  State<TalentExpandableText> createState() => _TalentExpandableTextState();
}

class _TalentExpandableTextState extends State<TalentExpandableText> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant TalentExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.bodySoft);
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final canExpand = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_expanded)
            SelectableText(widget.text, style: style)
          else
            Text(
              widget.text,
              maxLines: widget.maxLines,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          if (canExpand)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                minimumSize: const Size(48, 36),
                alignment: Alignment.centerLeft,
              ),
              child: Text(_expanded ? '收起' : '展开全文'),
            ),
        ],
      );
    },
  );
}

class TalentMatchAnalysisSection extends StatelessWidget {
  const TalentMatchAnalysisSection({
    super.key,
    required this.detail,
    required this.match,
    this.job,
    required this.onDetailRetry,
    required this.onMatchRetry,
    this.embedded = false,
    this.fallbackReport,
  });
  final TalentSectionState<Map<String, dynamic>> detail;
  final TalentSectionState<TalentMatchData> match;
  final TalentSectionState<Map<String, dynamic>>? fallbackReport;
  final TalentJobContext? job;
  final VoidCallback onDetailRetry, onMatchRetry;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final result = job == null ? fallbackReport?.data : match.data?.result;
    final analyzed = result?['source'] == 'llm';
    final score = analyzed ? talentNumber(result?['totalScore']) : null;
    return TalentSectionFrame(
      title: '',
      ai: !embedded,
      embedded: embedded,
      loading: job == null ? fallbackReport?.loading ?? false : match.loading,
      error: job == null ? fallbackReport?.error : match.error,
      empty: !analyzed,
      emptyText: job == null ? '暂无AI分析，请在岗位中运行AI辅助筛选' : '尚未分析，请在求职者列表点击AI辅助筛选',
      onRetry: job == null ? onDetailRetry : onMatchRetry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '综合匹配度',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job?.title ??
                          talentText(result?['positionTitle'], '岗位匹配分析'),
                      style: const TextStyle(
                        color: AppColors.bodySoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                score == null ? '—' : score.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.interactive,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          TalentMatchRadar(result: result ?? const {}),
          if (analyzed)
            const Text(
              '未提供相关材料的维度按0分计入综合分',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}
