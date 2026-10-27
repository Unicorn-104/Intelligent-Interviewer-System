import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class MessageAvatar extends StatelessWidget {
  const MessageAvatar({
    super.key,
    required this.name,
    this.url,
    this.system = false,
    this.square = false,
  });
  final String name;
  final String? url;
  final bool system, square;
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
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(square ? 6 : 24),
        child: ColoredBox(
          color: AppColors.interactiveSoft,
          child: url == null
              ? fallback
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
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
