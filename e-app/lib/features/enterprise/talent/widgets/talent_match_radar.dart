import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';

/// Missing dimensions have no plotted point; they are never represented as zero.
class TalentMatchRadar extends StatelessWidget {
  const TalentMatchRadar({super.key, required this.result});
  final Map<String, dynamic> result;

  static const dimensions = <String, String>{
    'skillMatch': '技能匹配',
    'projectMatch': '项目经历',
    'industryMatch': '工作／实习',
    'researchMatch': '科研经历',
    'awardMatch': '荣誉奖项',
    'educationMatch': '教育背景',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final height = 270.0 + (scale - 1).clamp(0, 2) * 100;
      final width = constraints.maxWidth;
      final center = Offset(width / 2, height / 2);
      final radius = math.min(width * .24, 82.0);
      final scores = [
        for (final key in dimensions.keys)
          switch (talentNumber(result[key])) {
            final num score when score >= 0 && score <= 100 => score.toDouble(),
            _ => null,
          },
      ];
      final labelWidth = (width * .32).clamp(68.0, 120.0);
      final labelHeight = 48.0 * scale.clamp(1, 3);
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RadarPainter(
                  scores: scores,
                  center: center,
                  radius: radius,
                ),
              ),
            ),
            for (var i = 0; i < dimensions.length; i++)
              Positioned(
                left:
                    (center.dx +
                            math.cos(-math.pi / 2 + i * math.pi / 3) *
                                (radius + 38) -
                            labelWidth / 2)
                        .clamp(0.0, width - labelWidth),
                top:
                    (center.dy +
                            math.sin(-math.pi / 2 + i * math.pi / 3) *
                                (radius + 38) -
                            labelHeight / 2)
                        .clamp(0.0, height - labelHeight),
                width: labelWidth,
                child: Semantics(
                  label:
                      '${dimensions.values.elementAt(i)}：${scores[i]?.toStringAsFixed(1) ?? '资料不足'}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dimensions.values.elementAt(i),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.bodySoft,
                        ),
                      ),
                      Text(
                        scores[i]?.toStringAsFixed(1) ?? '—',
                        key: ValueKey(
                          'radar-score-${dimensions.keys.elementAt(i)}',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.interactive,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.scores,
    required this.center,
    required this.radius,
  });
  final List<double?> scores;
  final Offset center;
  final double radius;

  Offset point(int index, double ratio) {
    final angle = -math.pi / 2 + index * math.pi / 3;
    return center + Offset(math.cos(angle), math.sin(angle)) * radius * ratio;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      final path = Path()
        ..addPolygon([for (var i = 0; i < 6; i++) point(i, ring / 4)], true);
      canvas.drawPath(path, grid);
    }
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(center, point(i, 1), grid);
    }
    final line = Paint()
      ..color = AppColors.interactive
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (scores.every((value) => value != null)) {
      final polygon = Path()
        ..addPolygon([
          for (var i = 0; i < 6; i++) point(i, scores[i]! / 100),
        ], true);
      canvas.drawPath(
        polygon,
        Paint()..color = AppColors.interactive.withValues(alpha: .12),
      );
      canvas.drawPath(polygon, line);
    } else {
      for (var i = 0; i < 6; i++) {
        final next = (i + 1) % 6;
        if (scores[i] != null && scores[next] != null) {
          canvas.drawLine(
            point(i, scores[i]! / 100),
            point(next, scores[next]! / 100),
            line,
          );
        }
      }
    }
    for (var i = 0; i < 6; i++) {
      if (scores[i] != null) {
        canvas.drawCircle(
          point(i, scores[i]! / 100),
          3.5,
          Paint()..color = AppColors.interactive,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.radius != radius ||
      List.generate(
        6,
        (i) => oldDelegate.scores[i] != scores[i],
      ).any((changed) => changed);
}
