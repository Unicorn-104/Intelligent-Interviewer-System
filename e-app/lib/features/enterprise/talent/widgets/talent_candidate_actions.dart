import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_greeting_sheet.dart';
import 'talent_interview_invite_sheet.dart';
import 'talent_workflow_progress.dart';

/// 资料页与岗位求职者卡片共用原打招呼、分阶段邀约及更多操作入口。
class TalentCandidateActions extends StatefulWidget {
  const TalentCandidateActions({
    super.key,
    required this.candidateId,
    required this.name,
    required this.source,
    this.job,
    this.onInvited,
    this.workflowRevision = 0,
    this.keyPrefix = 'talent',
  });

  final int? candidateId;
  final String name;
  final TalentDetailDataSource source;
  final TalentJobContext? job;
  final VoidCallback? onInvited;
  final String keyPrefix;
  final int workflowRevision;

  @override
  State<TalentCandidateActions> createState() => _TalentCandidateActionsState();
}

class _TalentCandidateActionsState extends State<TalentCandidateActions> {
  bool _busy = false;
  int _workflowRevision = 0;
  bool get _enabled => !_busy && widget.candidateId != null;

  Future<void> _open({required bool invite}) async {
    if (!_enabled) return;
    setState(() => _busy = true);
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: !invite,
        enableDrag: !invite,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .9,
          child: invite
              ? TalentInterviewInviteSheet(
                  candidateId: widget.candidateId!,
                  candidateName: widget.name,
                  source: widget.source,
                  job: widget.job,
                )
              : TalentGreetingSheet(
                  candidateId: widget.candidateId!,
                  name: widget.name,
                  source: widget.source,
                  job: widget.job,
                ),
        ),
      );
      if (!mounted || !invite || result != true) return;
      setState(() => _workflowRevision++);
      widget.onInvited?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请在面试安排中核对邀约结果')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _more(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$action功能开发中')));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TalentWorkflowProgress(
        candidateId: widget.candidateId,
        source: widget.source,
        job: widget.job,
        revision: widget.workflowRevision + _workflowRevision,
      ),
      const SizedBox(height: 8),
      _buttons(context),
    ],
  );

  Widget _buttons(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final greeting = OutlinedButton.icon(
        key: ValueKey('${widget.keyPrefix}-greeting'),
        onPressed: _enabled ? () => _open(invite: false) : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: AppColors.interactive,
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const FittedBox(fit: BoxFit.scaleDown, child: Text('打招呼')),
      );
      final invitation = DecoratedBox(
        decoration: BoxDecoration(
          color: _enabled
              ? AppColors.interactive
              : AppColors.interactive.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: ValueKey('${widget.keyPrefix}-invite'),
                onPressed: _enabled ? () => _open(invite: true) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: AppColors.canvas.withValues(alpha: 0),
                  disabledBackgroundColor: AppColors.canvas.withValues(
                    alpha: 0,
                  ),
                  foregroundColor: AppColors.canvas,
                  disabledForegroundColor: AppColors.canvas.withValues(
                    alpha: .7,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(4),
                    ),
                  ),
                ),
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('邀请面试'),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: AppColors.canvas.withValues(alpha: .3),
            ),
            PopupMenuButton<String>(
              key: ValueKey('${widget.keyPrefix}-more'),
              enabled: _enabled,
              tooltip: '更多候选人操作',
              onSelected: _more,
              position: PopupMenuPosition.under,
              color: AppColors.canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: EdgeInsets.zero,
              iconSize: 20,
              iconColor: AppColors.canvas,
              icon: const Icon(Icons.keyboard_arrow_down),
              constraints: const BoxConstraints(minWidth: 150),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: ValueKey('${widget.keyPrefix}-hire'),
                  value: '录用',
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('录用', style: TextStyle(color: AppColors.success)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  key: ValueKey('${widget.keyPrefix}-reject'),
                  value: '淘汰',
                  child: const Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: AppColors.error,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('淘汰', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [greeting, const SizedBox(height: 8), invitation],
        );
      }
      return Row(
        children: [
          Expanded(flex: 3, child: greeting),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: invitation),
        ],
      );
    },
  );
}
