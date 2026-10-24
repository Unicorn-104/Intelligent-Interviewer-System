import 'package:flutter/material.dart';

/// 参考图中的独立漏斗轮廓，不包含图片下方的字母标记。
class TalentFilterIcon extends StatelessWidget {
  const TalentFilterIcon({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(28), painter: _FunnelPainter(color));
}

class _FunnelPainter extends CustomPainter {
  const _FunnelPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 28, size.height / 28);
    final path = Path()
      ..moveTo(4.5, 3.5)
      ..lineTo(23.5, 3.5)
      ..quadraticBezierTo(25.5, 3.5, 25.1, 5.8)
      ..lineTo(24.7, 8.3)
      ..quadraticBezierTo(24.5, 9.2, 23.6, 10.2)
      ..lineTo(17.8, 16.2)
      ..quadraticBezierTo(17.3, 16.8, 17.2, 17.8)
      ..lineTo(16.5, 22.2)
      ..quadraticBezierTo(16.3, 23, 15.6, 23.5)
      ..lineTo(12, 25.6)
      ..quadraticBezierTo(11.2, 26.1, 11.1, 24.9)
      ..lineTo(10.3, 18)
      ..quadraticBezierTo(10.2, 16.9, 9.6, 16.3)
      ..lineTo(3.9, 10.3)
      ..quadraticBezierTo(3, 9.4, 2.9, 8.3)
      ..lineTo(2.6, 5.8)
      ..quadraticBezierTo(2.3, 3.5, 4.5, 3.5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FunnelPainter oldDelegate) =>
      oldDelegate.color != color;
}
