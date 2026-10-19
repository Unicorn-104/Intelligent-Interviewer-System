import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class ProfileAvatarView extends StatelessWidget {
  const ProfileAvatarView({
    super.key,
    required this.name,
    required this.url,
    this.size = 64,
    this.revision = 0,
  });
  final String name;
  final String? url;
  final double size;
  final int revision;
  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        name.isEmpty ? '企' : name.characters.first,
        style: TextStyle(
          color: AppColors.interactive,
          fontSize: size * .4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.interactiveSoft,
          child: url == null
              ? fallback
              : Image.network(
                  '$url${url!.contains('?') ? '&' : '?'}v=$revision',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
