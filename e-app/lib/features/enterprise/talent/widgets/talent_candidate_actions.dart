import 'package:flutter/material.dart';

import '../../../../core/constants/application_status.dart';
import '../../../../theme/app_theme.dart';
import '../../notification/conversation_page.dart';
import '../../../../api/talent_api.dart';
import '../../../../core/network/api_exception.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_interview_invite_sheet.dart';
import 'talent_workflow_progress.dart';

/// 资料页与岗位求职者卡片共用打招呼、分阶段邀约及更多操作入口。
///
/// 操作按钮按投递状态（app_status 六态）重排：
/// - 已投递(0)：启动招聘、HR淘汰
/// - 招聘中(1)：安排笔试/面试、查看评审、HR淘汰
/// - 待发Offer(2)：发Offer、终止
/// - 待确认Offer(3)：撤销Offer
/// - 已录用(4)：查看录用（终态，不可再推进）
/// - 未录用(5)：查看原因/历史（终态，不可再推进）
/// HR 淘汰需二次确认并选择终止原因；AI 评分不触发任何自动淘汰。
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
    this.appStatusCode,
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

  /// 投递状态码（t_app_record.app_status），后端候选人记录的 statusCode 字段。
  final Object? appStatusCode;

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

  /// HR 淘汰：二次确认并选择终止原因（落库为 NOT_HIRED + endReason）。
  Future<void> _confirmHrReject() async {
    final messenger = ScaffoldMessenger.of(context);
    ApplicationEndReason reason = ApplicationEndReason.hrRejected;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('确认淘汰该候选人？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('将把该投递置为「未录用」（终态，不可再推进）。候选人：${widget.name}'),
              const SizedBox(height: 12),
              const Text('终止原因', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<ApplicationEndReason>(
                initialValue: reason,
                items: [
                  for (final item in ApplicationEndReason.hrChoices)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: (value) =>
                    setState(() => reason = value ?? ApplicationEndReason.hrRejected),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text('确认淘汰（${reason.label}）'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final positionId = widget.job?.positionId;
    final candidateId = widget.candidateId;
    if (positionId == null || candidateId == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('岗位信息缺失，无法淘汰')));
      return;
    }
    setState(() => _busy = true);
    try {
      await terminateTalentApplication(
        candidateId: candidateId,
        positionId: positionId,
        endReason: reason.code,
      );
      if (!mounted) return;
      setState(() => _workflowRevision++);
      widget.onInvited?.call();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('已标记为未录用（${reason.label}）')));
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '淘汰失败，请刷新后重试';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _more(String action) {
    // HR 淘汰走二次确认 + 原因选择；其余动作待后端接口接入。
    if (action == '淘汰') {
      _confirmHrReject();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$action功能开发中')));
  }

  /// 按投递状态生成「更多」操作项；终态不提供推进类操作。
  List<PopupMenuEntry<String>> _menuItems() {
    final status = ApplicationStatus.byCode(widget.appStatusCode);
    if (status == ApplicationStatus.hired) {
      return const [
        PopupMenuItem(value: '查看录用', child: Text('查看录用')),
      ];
    }
    if (status == ApplicationStatus.notHired) {
      return const [
        PopupMenuItem(value: '查看原因', child: Text('查看原因/历史')),
      ];
    }
    switch (status) {
      case ApplicationStatus.applied:
        return [
          _menuItem('启动招聘', Icons.play_arrow_outlined, AppColors.interactive),
          _rejectItem(),
        ];
      case ApplicationStatus.pendingOffer:
        return [
          _menuItem('发Offer', Icons.send_outlined, AppColors.warning),
          _rejectItem(),
        ];
      case ApplicationStatus.offerPendingConfirmation:
        return [
          _menuItem('撤销Offer', Icons.undo_outlined, AppColors.warning),
          _rejectItem(),
        ];
      case ApplicationStatus.inProgress:
        return [
          _menuItem('查看评审', Icons.fact_check_outlined, AppColors.interactive),
          _rejectItem(),
        ];
      default:
        // 状态未知时保留入口，但不暴露淘汰，避免误操作。
        return [
          _menuItem('录用', Icons.check_circle_outline, AppColors.success),
          _rejectItem(),
        ];
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, Color color) =>
      PopupMenuItem(
        key: ValueKey('${widget.keyPrefix}-$value'),
        value: value,
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: color)),
        ]),
      );

  PopupMenuItem<String> _rejectItem() => PopupMenuItem(
        key: ValueKey('${widget.keyPrefix}-reject'),
        value: '淘汰',
        child: const Row(children: [
          Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
          SizedBox(width: 8),
          Text('HR淘汰', style: TextStyle(color: AppColors.error)),
        ]),
      );

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
      // 终态（已录用/未录用）：普通推进操作（安排面试等）不可再用。
      final terminal = ApplicationStatus.isTerminal(widget.appStatusCode);
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
                onPressed: (_enabled && !terminal) ? _openInvite : null,
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
              itemBuilder: (_) => _menuItems(),
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
