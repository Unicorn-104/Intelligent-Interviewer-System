import 'package:flutter/material.dart';

import '../../../config/app_config.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatar,
    required this.name,
    required this.radius,
    this.backgroundColor = Colors.white,
    this.foregroundColor,
  });

  final String? avatar;
  final String name;
  final double radius;
  final Color backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(avatar);
    final fallback = _AvatarFallback(
      name: name,
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );

    if (imageUrl == null) return fallback;
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  String? _resolveImageUrl(String? value) {
    final path = value?.trim();
    if (path == null || path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri?.hasScheme == true) return path;
    return '${AppConfig.apiBaseUrl}${path.startsWith('/') ? '' : '/'}$path';
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.name,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String name;
  final double radius;
  final Color backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final value = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        value.isEmpty ? '用' : value.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: foregroundColor ?? Theme.of(context).colorScheme.primary,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
