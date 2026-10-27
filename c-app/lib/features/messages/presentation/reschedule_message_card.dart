import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 服务端生成的改期消息；审批操作仅在企业端提供。
class RescheduleMessageCard extends StatelessWidget {
  const RescheduleMessageCard({
    super.key,
    required this.data,
    this.mine = false,
  });

  final Map<String, dynamic> data;
  final bool mine;

  String _text(String key) => data[key]?.toString().trim().isNotEmpty == true
      ? data[key].toString()
      : '—';

  @override
  Widget build(BuildContext context) {
    final status = _text('status');
    final color = mine ? Colors.white : AppColors.body;
    final title = switch (status) {
      'changed' => '企业已调整面试时间',
      'approved' => '改期申请已同意',
      'rejected' => '改期申请未通过',
      _ => '改期申请已提交',
    };
    return SizedBox(
      width: 248,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color, fontSize: 12, height: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat, color: color, size: 19),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _text('positionName'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '原时间：${_text('originalStartTime')} ～ ${_text('originalEndTime')}',
            ),
            Text(
              '${status == 'pending' || status == 'rejected' ? '申请时间' : '新时间'}：${_text('newStartTime')} ～ ${_text('newEndTime')}',
            ),
            if (status == 'rejected') const Text('面试仍按原安排进行，请核对最新日程。'),
            if (_text('reason') != '—') ...[
              const SizedBox(height: 5),
              Text('申请原因：${_text('reason')}'),
            ],
            if (_text('reviewNote') != '—') ...[
              const SizedBox(height: 5),
              Text('审批说明：${_text('reviewNote')}'),
            ],
          ],
        ),
      ),
    );
  }
}
