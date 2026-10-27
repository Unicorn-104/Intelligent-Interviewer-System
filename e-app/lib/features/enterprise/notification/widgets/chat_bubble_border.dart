import 'package:flutter/material.dart';

/// 气泡与尖角使用同一路径，边线不会穿过二者的连接处。
class ChatBubbleBorder extends ShapeBorder {
  const ChatBubbleBorder({required this.mine});

  final bool mine;
  static const tailWidth = 7.0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    const radius = 5.0;
    final top = rect.top, bottom = rect.bottom;
    final left = rect.left, right = rect.right;
    final tailTop = top + 18, tailBottom = top + 30;
    final path = Path()
      ..moveTo(left + radius, top)
      ..lineTo(right - radius, top)
      ..quadraticBezierTo(right, top, right, top + radius);
    if (mine) {
      path
        ..lineTo(right, tailTop)
        ..lineTo(right + tailWidth, (tailTop + tailBottom) / 2)
        ..lineTo(right, tailBottom);
    }
    path
      ..lineTo(right, bottom - radius)
      ..quadraticBezierTo(right, bottom, right - radius, bottom)
      ..lineTo(left + radius, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - radius);
    if (!mine) {
      path
        ..lineTo(left, tailBottom)
        ..lineTo(left - tailWidth, (tailTop + tailBottom) / 2)
        ..lineTo(left, tailTop);
    }
    return path
      ..lineTo(left, top + radius)
      ..quadraticBezierTo(left, top, left + radius, top)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (!mine) {
      canvas.drawPath(
        getOuterPath(rect, textDirection: textDirection),
        Paint()
          ..color = const Color(0xFFE7E7E7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }
}
