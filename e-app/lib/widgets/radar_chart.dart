import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 多维度雷达图（P2 新增通用可视化组件，基于 CustomPaint，无第三方依赖）。
///
/// 用于展示候选人匹配度各维度评分（技能/项目/教育/行业），
/// 依据《业务功能分析》UC-05 步骤3-4 的多维度语义匹配。
class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.values,
    required this.labels,
    this.size = 230,
  });

  /// 各维度得分（0-100），与 [labels] 一一对应。
  final List<double> values;

  /// 各维度名称（建议不超过 5 个字符，避免标签溢出）。
  final List<String> labels;

  final double size;

  @override
  Widget build(BuildContext context) {
    assert(values.length == labels.length && values.length >= 3);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          values: values,
          labels: labels,
          gridColor: AppColors.hairline,
          fillColor: AppColors.interactive.withValues(alpha: 0.16),
          strokeColor: AppColors.interactive,
          dotColor: AppColors.interactive,
          labelColor: AppColors.bodySoft,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.values,
    required this.labels,
    required this.gridColor,
    required this.fillColor,
    required this.strokeColor,
    required this.dotColor,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color gridColor;
  final Color fillColor;
  final Color strokeColor;
  final Color dotColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 36;
    final count = values.length;
    final angleStep = 2 * math.pi / count;

    Offset pointAt(int i, double r) {
      final angle = -math.pi / 2 + i * angleStep;
      return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;

    // 同心网格（25% / 50% / 75% / 100%）
    for (final level in const [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = pointAt(i, radius * level);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 轴线
    for (var i = 0; i < count; i++) {
      canvas.drawLine(center, pointAt(i, radius), gridPaint);
    }

    // 数值多边形
    final valuePath = Path();
    for (var i = 0; i < count; i++) {
      final p = pointAt(i, radius * values[i].clamp(0, 100) / 100);
      i == 0 ? valuePath.moveTo(p.dx, p.dy) : valuePath.lineTo(p.dx, p.dy);
    }
    valuePath.close();
    canvas.drawPath(
      valuePath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor,
    );
    canvas.drawPath(
      valuePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = strokeColor,
    );

    // 顶点圆点
    for (var i = 0; i < count; i++) {
      final p = pointAt(i, radius * values[i].clamp(0, 100) / 100);
      canvas.drawCircle(p, 3.5, Paint()..color = dotColor);
    }

    // 维度标签（按方向对齐，避免溢出）
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      final p = pointAt(i, radius + 12);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 12,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var anchorX = p.dx - tp.width / 2;
      var anchorY = p.dy - tp.height / 2;
      if (dx > 0.5) {
        anchorX = p.dx; // 右侧顶点：左对齐
      } else if (dx < -0.5) {
        anchorX = p.dx - tp.width; // 左侧顶点：右对齐
      }
      if (dy > 0.5) {
        anchorY = p.dy - tp.height; // 底部顶点：标签在点上方
      } else if (dy < -0.5) {
        anchorY = p.dy; // 顶部顶点：标签在点下方
      }
      tp.paint(canvas, Offset(anchorX, anchorY));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.fillColor != fillColor;
}

/// 环形总分指示器：展示百分制综合匹配度。
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 64});

  /// 综合匹配度（0-100）。
  final double score;

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? AppColors.green
        : score >= 70
        ? AppColors.interactive
        : AppColors.orange;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              backgroundColor: AppColors.hairline,
              color: color,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Text(
                  '综合',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
