import 'package:flutter/material.dart';

/// 模块二：AI 初筛与短名单 - 主页面（占位）。
///
/// TODO(P2): 筛选任务/匹配度评分/短名单/推荐报告/招呼语/HR 复核，
/// 数据源见 lib/api/screening_api.dart（当前均为占位函数，不发真实请求）。
class ScreeningPage extends StatelessWidget {
  const ScreeningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 初筛与短名单')),
      body: const Center(child: Text('AI 初筛与短名单 - 待开发')),
    );
  }
}
