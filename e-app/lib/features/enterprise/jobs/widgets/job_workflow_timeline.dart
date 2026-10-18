import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/job_detail_view_data.dart';

/// 展示岗位真实流程顺序；灰色节点仅提示可添加，不属于招聘阶段。
class JobWorkflowTimeline extends StatelessWidget {
  const JobWorkflowTimeline({
    super.key,
    required this.state,
    required this.onReload,
    this.onEditStage,
    this.onAddStage,
    this.onManage,
    this.enabled = true,
  });
  final JobSectionState<Map<String, dynamic>> state;
  final VoidCallback onReload;
  final ValueChanged<int>? onEditStage;
  final VoidCallback? onAddStage;
  final VoidCallback? onManage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              '招聘流程加载中',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (state.error != null || state.data == null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '招聘流程暂不可用',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onReload, child: const Text('重试')),
        ],
      );
    }
    final raw = state.data!['stages'];
    final stages = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
    final hasPlaceholder = stages.length < 2 || onAddStage != null;
    final count = stages.length + (hasPlaceholder ? 1 : 0);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = math.max(
          80 * scale,
          constraints.maxWidth / math.min(count, 3),
        );
        return SingleChildScrollView(
          key: const Key('job-workflow-timeline-scroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: cellWidth * count,
            child: Stack(
              children: [
                if (count > 1)
                  Positioned(
                    top: 11,
                    left: cellWidth / 2,
                    right: cellWidth / 2,
                    child: Container(
                      key: const Key('job-workflow-timeline-line'),
                      height: 2,
                      color: hasPlaceholder
                          ? AppColors.hairline
                          : AppColors.interactive.withValues(alpha: .3),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < count; index++)
                      SizedBox(
                        width: cellWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _node(index, index >= stages.length, stages),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _node(int index, bool placeholder, List<Map> stages) {
    final name = placeholder
        ? '可继续添加'
        : jobValue(stages[index]['name'], fallback: '未命名阶段');
    final color = placeholder ? AppColors.textMuted : AppColors.interactive;
    return Semantics(
      label: placeholder ? '可继续添加招聘阶段' : '第${index + 1}阶段：$name',
      button:
          enabled && (placeholder ? onAddStage != null : onEditStage != null),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: !enabled
              ? null
              : placeholder
              ? onAddStage
              : onEditStage == null
              ? null
              : () => onEditStage!(index),
          onLongPress: enabled && !placeholder ? onManage : null,
          borderRadius: BorderRadius.circular(4),
          child: Tooltip(
            triggerMode: onManage == null ? null : TooltipTriggerMode.manual,
            message: placeholder
                ? '新增招聘阶段'
                : onManage == null
                ? name
                : '$name：点击编辑，长按调整流程顺序',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: placeholder
                      ? const Key('job-workflow-placeholder')
                      : ValueKey('job-workflow-node-$index'),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.canvas,
                    border: Border.all(
                      color: placeholder
                          ? AppColors.hairline
                          : AppColors.interactiveSoft,
                      width: 4,
                    ),
                  ),
                  child: placeholder
                      ? const Icon(
                          Icons.add,
                          size: 12,
                          color: AppColors.textMuted,
                        )
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: name,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: placeholder
                          ? AppColors.textMuted
                          : AppColors.brand,
                      fontSize: 13,
                      fontWeight: placeholder
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
