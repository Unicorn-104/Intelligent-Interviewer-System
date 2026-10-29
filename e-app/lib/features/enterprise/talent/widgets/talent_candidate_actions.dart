import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../notification/conversation_page.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_interview_invite_sheet.dart';
import 'talent_workflow_progress.dart';

/// 资料页与岗位求职者卡片共用原打招呼、分阶段邀约及更多操作入口。
class TalentCandidateActions extends StatefulWidget {
  const TalentCandidateActions({
    super.key,
    required this.candidateId,
    required this.name,
    required this.source,
    this.peerId,
    this.job,
    this.onInvited,
    this.workflowRevision = 0,
    this.keyPrefix = 'talent',
  });

  final int? candidateId;
  final String name;
  final TalentDetailDataSource source;

  /// 求职者真实 sys_user userId；「打招呼」直接进入聊天页时作为对方 peerId。
  final int? peerId;
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

  /// 打招呼：跳过招呼语预览弹窗，直接进入与该求职者的聊天页。
  Future<void> _openChat() async {
    final peerId = widget.peerId;
    if (_busy || peerId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('求职者信息缺失，暂时无法发起对话')));
      return;
    }
    // 仅需对方真实 userId；无历史会话时聊天页允许直接编辑首条消息，
    // 发送首条消息时后端自动创建会话，不发送占位消息。
    final session = <String, dynamic>{
      'peerId': peerId,
      'peerName': widget.name,
      'fromTalentDiscovery': true,
    };
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => ChatPage(session: session)),
    );
  }

  /// 邀请面试：打开分阶段邀约面板（保留原有流程）。
  Future<void> _openInvite() async {
    if (!_enabled) return;
    setState(() => _busy = true);
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .9,
          child: TalentInterviewInviteSheet(
            candidateId: widget.candidateId!,
            candidateName: widget.name,
            source: widget.source,
            job: widget.job,
          ),
        ),
      );
      if (!mounted || result != true) return;
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
        onPressed: _openChat,
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
                onPressed: _enabled ? _openInvite : null,
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
