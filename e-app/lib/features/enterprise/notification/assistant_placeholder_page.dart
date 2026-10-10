import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 模块六：反馈与通知 - AI 助手入口占位页（P5）。
///
/// 依据《业务功能分析》UC-18（AI 助手 7×24 小时自动应答）：
/// 该用例主要面向候选人——候选人在主动发起咨询时（询问面试进度、
/// 岗位详情、修改联系方式等），系统基于知识库和实时系统状态进行
/// 自然语言应答。企业 APP 按计划仅预留入口，不实现对话逻辑。
///
/// TODO(接口待定): 企业端接入方式待确认，禁止编造接口；
/// 可参考 lib/api/assistant_api.dart 的占位函数。
class AssistantPlaceholderPage extends StatelessWidget {
  const AssistantPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  size: 36,
                  color: AppColors.interactive,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AI 助手 · 候选人端功能占位',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                '该功能面向候选人（UC-18）：候选人可随时咨询面试进度、'
                '岗位详情、修改联系方式等问题，系统基于知识库与实时状态'
                '自动应答，弥补纯自动化通知在"非标问题"上的覆盖盲区。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '企业端接入方式待定，本页为预留入口占位。\n'
                  'TODO: P7阶段与后端确认接口契约后再对接（assistant_api.dart）',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.orange),
                ),
              ),
              const SizedBox(height: 20),
              const OutlinedButton(
                onPressed: null, // 占位：功能待定，禁用
                child: Text('功能待定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
