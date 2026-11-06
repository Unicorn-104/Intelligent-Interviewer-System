import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 岗位投递状态（t_app_record.app_status）统一映射 —— 六态口径。
///
/// 与后端 com.ruoyi.common.enums.ApplicationStatus 对齐：
/// 0 APPLIED 已投递 / 1 IN_PROGRESS 招聘中 / 2 PENDING_OFFER 待发Offer /
/// 3 OFFER_PENDING_CONFIRMATION 待确认Offer / 4 HIRED 已录用 / 5 NOT_HIRED 未录用。
///
/// 前端所有投递状态的中文标签、颜色、终态判断一律从这里取，
/// 禁止在各页面散落硬编码「待筛选/初筛通过/初筛淘汰/已约面/待笔试…」等旧状态名。
class ApplicationStatus {
  const ApplicationStatus._({
    required this.code,
    required this.label,
    required this.color,
    required this.icon,
    required this.terminal,
  });

  /// 0 已投递
  static const applied = ApplicationStatus._(
    code: 0,
    label: '已投递',
    color: AppColors.muted,
    icon: Icons.mail_outline,
    terminal: false,
  );

  /// 1 招聘中
  static const inProgress = ApplicationStatus._(
    code: 1,
    label: '招聘中',
    color: AppColors.interactive,
    icon: Icons.how_to_reg_outlined,
    terminal: false,
  );

  /// 2 待发Offer
  static const pendingOffer = ApplicationStatus._(
    code: 2,
    label: '待发Offer',
    color: AppColors.warning,
    icon: Icons.mark_email_unread_outlined,
    terminal: false,
  );

  /// 3 待确认Offer
  static const offerPendingConfirmation = ApplicationStatus._(
    code: 3,
    label: '待确认Offer',
    color: AppColors.purple,
    icon: Icons.mail_outline,
    terminal: false,
  );

  /// 4 已录用（终态）
  static const hired = ApplicationStatus._(
    code: 4,
    label: '已录用',
    color: AppColors.success,
    icon: Icons.verified_outlined,
    terminal: true,
  );

  /// 5 未录用（终态）
  static const notHired = ApplicationStatus._(
    code: 5,
    label: '未录用',
    color: AppColors.error,
    icon: Icons.cancel_outlined,
    terminal: true,
  );

  static const List<ApplicationStatus> values = [
    applied,
    inProgress,
    pendingOffer,
    offerPendingConfirmation,
    hired,
    notHired,
  ];

  final int code;
  final String label;
  final Color color;
  final IconData icon;

  /// 终态（已录用/未录用）：终态下普通操作按钮不可再推进。
  final bool terminal;

  static ApplicationStatus? byCode(Object? value) {
    final code = int.tryParse('$value');
    if (code == null) return null;
    for (final item in values) {
      if (item.code == code) return item;
    }
    return null;
  }

  /// 码值 → 中文标签；无法识别时返回「状态未提供」。
  static String labelOf(Object? value) => byCode(value)?.label ?? '状态未提供';

  /// 码值 → 颜色；无法识别时取中性色。
  static Color colorOf(Object? value) => byCode(value)?.color ?? AppColors.muted;

  /// 是否终态（已录用/未录用）。
  static bool isTerminal(Object? value) => byCode(value)?.terminal ?? false;
}

/// 未录用终止原因（与后端 ApplicationEndReason 对齐，落库为枚举名字符串）。
class ApplicationEndReason {
  const ApplicationEndReason._(this.code, this.label);

  /// HR 主动淘汰
  static const hrRejected = ApplicationEndReason._('HR_REJECTED', 'HR淘汰');

  /// 候选人主动撤回
  static const candidateWithdrawn =
      ApplicationEndReason._('CANDIDATE_WITHDRAWN', '候选人撤回');

  /// 候选人拒绝 Offer
  static const offerRejected = ApplicationEndReason._('OFFER_REJECTED', 'Offer拒绝');

  /// Offer 超时未确认
  static const offerExpired = ApplicationEndReason._('OFFER_EXPIRED', 'Offer过期');

  /// HR 撤销 Offer
  static const offerCancelled =
      ApplicationEndReason._('OFFER_CANCELLED', 'Offer取消');

  /// 历史遗留：旧初筛淘汰数据迁移（新流程不再产生）
  static const legacyScreeningRejected =
      ApplicationEndReason._('LEGACY_SCREENING_REJECTED', '初筛淘汰(历史)');

  static const List<ApplicationEndReason> values = [
    hrRejected,
    candidateWithdrawn,
    offerRejected,
    offerExpired,
    offerCancelled,
    legacyScreeningRejected,
  ];

  /// HR 淘汰时可选择的原因（不含系统事件类原因）。
  static const List<ApplicationEndReason> hrChoices = [
    hrRejected,
    candidateWithdrawn,
    offerRejected,
    offerExpired,
    offerCancelled,
  ];

  final String code;
  final String label;

  static ApplicationEndReason? byCode(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    for (final item in values) {
      if (item.code == text) return item;
    }
    return null;
  }

  static String labelOf(Object? value) =>
      byCode(value)?.label ?? value?.toString().trim() ?? '未提供';
}

/// 「招聘中 · 当前环节」旁注组件。
///
/// 文案仅展示、不写库；当前环节文案来自后端流程节点实例数据
/// （对应后端 ProcessStageInstanceService.currentNodeLabel / describe，
/// 接口字段预留：currentStage / currentNodeLabel，例如「第 2 轮笔试」「待安排下一环节」）。
/// 接口暂未提供时不展示旁注，不做猜测式拼接。
class ApplicationStageSuffix extends StatelessWidget {
  const ApplicationStageSuffix({super.key, required this.appStatus, this.currentStage});

  /// 投递状态码（app_status）。
  final Object? appStatus;

  /// 后端当前节点文案（字段来源：currentStage / currentNodeLabel）。
  final String? currentStage;

  @override
  Widget build(BuildContext context) {
    final stage = currentStage?.trim() ?? '';
    if (ApplicationStatus.byCode(appStatus) != ApplicationStatus.inProgress ||
        stage.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ApplicationStatus.inProgress.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '招聘中 · $stage',
        style: TextStyle(
          color: ApplicationStatus.inProgress.color,
          fontSize: 11,
        ),
      ),
    );
  }
}
