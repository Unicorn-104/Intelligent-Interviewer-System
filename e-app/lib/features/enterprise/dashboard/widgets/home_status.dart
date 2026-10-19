import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';

String homeErrorMessage(Object error) {
  if (error is ApiException) {
    final code = error.code ?? error.statusCode;
    if (code == 401) return '登录已过期，请重新登录';
    if (code == 403) return '暂无访问权限，请联系企业管理员';
    if (code != null && code >= 500) return '服务暂不可用，请稍后重试';
    if (error.message.toLowerCase().contains('timeout') ||
        error.message.contains('超时')) {
      return '连接超时，请检查网络后重试';
    }
    return error.message;
  }
  return '数据暂不可用，请稍后重试';
}

class HomeStatus extends StatelessWidget {
  const HomeStatus({
    super.key,
    required this.message,
    this.error,
    this.onRetry,
    this.icon = Icons.inbox_outlined,
  });
  final String message;
  final Object? error;
  final VoidCallback? onRetry;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Column(
      children: [
        Icon(
          error == null ? icon : Icons.cloud_off_outlined,
          size: 28,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 12),
        Text(
          error == null ? message : homeErrorMessage(error!),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (error != null && onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ],
    ),
  );
}
