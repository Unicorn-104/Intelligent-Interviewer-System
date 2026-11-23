import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class MessageAvatar extends StatelessWidget {
  const MessageAvatar({
    super.key,
    required this.name,
    this.url,
    this.system = false,
    this.square = false,
    this.size = 48,
  });
  final String name;
  final String? url;
  final bool system, square;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: system
          ? const Icon(
              Icons.notifications_none,
              color: AppColors.interactive,
              size: 25,
            )
          : Text(
              name.isEmpty ? '聊' : name.characters.first,
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
    final content = ColoredBox(
      color: AppColors.interactiveSoft,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              headers: const {'Referer': 'http://localhost/'},
              errorBuilder: (_, _, _) => fallback,
            ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: square
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: content,
            )
          : ClipOval(child: content),
    );
  }
}

class MessageUnreadBadge extends StatelessWidget {
  const MessageUnreadBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => count <= 0
      ? const SizedBox(
          width: 7,
          height: 7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.hairline,
              shape: BoxShape.circle,
            ),
          ),
        )
      : Semantics(
          label: '$count条未读',
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: AppColors.canvas,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
}
