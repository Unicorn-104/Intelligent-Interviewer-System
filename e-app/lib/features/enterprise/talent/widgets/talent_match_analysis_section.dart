import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';

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
  });
  final TalentSectionState<Map<String, dynamic>> detail;
  final TalentSectionState<TalentMatchData> match;
  final TalentJobContext? job;
  final VoidCallback onDetailRetry, onMatchRetry;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final result = match.data?.result;
    final score = talentNumber(
      result?['totalScore'] ?? detail.data?['matchedScore'],
    );
    final skills = match.data?.requiredSkills ?? const <String>[];
    final skillScore = talentNumber(result?['skillMatch']);
    final validSkillScore =
        skillScore != null && skillScore >= 0 && skillScore <= 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalentSectionFrame(
          title: '通用评分，非岗位维度',
          ai: !embedded,
          embedded: embedded,
          loading: detail.loading && result == null,
          error: result == null ? detail.error : null,
          empty: score == null,
          emptyText: '暂无评分数据',
          onRetry: onDetailRetry,
          child: Text(
            score == null ? '暂无评分数据' : '$score 分',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.interactive,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (embedded)
          const Divider(height: 24, thickness: 1, color: AppColors.hairline),
        TalentSectionFrame(
          title: '岗位技能分析',
          ai: !embedded,
          embedded: embedded,
          loading: job != null && match.loading,
          error: job == null ? null : match.error,
          empty: job == null,
          emptyText: '选择岗位后查看',
          onRetry: onMatchRetry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                job?.title ?? '',
                style: const TextStyle(color: AppColors.bodySoft, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (skills.isEmpty)
                const Text('暂无岗位技能依据', style: TextStyle(color: AppColors.muted))
              else ...[
                Text(
                  validSkillScore ? '技能重合度：$skillScore%' : '技能重合度：暂无分析',
                  style: const TextStyle(
                    color: AppColors.interactive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (validSkillScore) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: skillScore / 100,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: AppColors.primarySoft,
                    color: AppColors.interactive,
                    semanticsLabel: '岗位必备技能重合度',
                    semanticsValue: '$skillScore%',
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  '按岗位必备技能计算的重合度',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in skills)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final dimension in const {
                    'projectMatch': '项目',
                    'educationMatch': '学历',
                    'industryMatch': '行业',
                  }.entries)
                    Text(
                      '${dimension.value}：${talentNumber(result?[dimension.key]) ?? '暂无分析'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
