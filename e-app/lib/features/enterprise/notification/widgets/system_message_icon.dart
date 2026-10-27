import 'package:flutter/material.dart';

/// 消息列表与通知详情共享同一绿色系统铃铛。
class SystemMessageIcon extends StatelessWidget {
  const SystemMessageIcon({super.key, this.size = 48});
  final double size;
  static const accent = Color(0xFF179E89);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFE1F7F2),
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.notifications_active_outlined,
      color: accent,
      size: size * .54,
    ),
  );
}
