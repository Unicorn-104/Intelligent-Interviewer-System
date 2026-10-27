import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Keeps the assistant within its page, with drag gestures distinct from taps.
class EnterpriseAiLauncher extends StatefulWidget {
  const EnterpriseAiLauncher({
    super.key,
    required this.child,
    required this.onPressed,
  });

  final Widget child;
  final VoidCallback onPressed;

  @override
  State<EnterpriseAiLauncher> createState() => _EnterpriseAiLauncherState();
}

class _EnterpriseAiLauncherState extends State<EnterpriseAiLauncher> {
  // Fractions retain the chosen position when the available viewport changes.
  double _x = 1;
  double _y = 1;
  bool _dragging = false;

  void _snap() => setState(() {
    _dragging = false;
    _x = _x < 0.5 ? 0 : 1;
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final diameter = math.min(
        64.0,
        math.min(constraints.maxWidth, constraints.maxHeight),
      );
      if (diameter <= 0) return widget.child;
      final insetX = math.min(4.0, (constraints.maxWidth - diameter) / 2);
      final insetY = math.min(16.0, (constraints.maxHeight - diameter) / 2);
      final rangeX = math.max(
        0.0,
        constraints.maxWidth - diameter - 2 * insetX,
      );
      final rangeY = math.max(
        0.0,
        constraints.maxHeight - diameter - 2 * insetY,
      );

      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          AnimatedPositioned(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: insetX + _x * rangeX,
            top: insetY + _y * rangeY,
            width: diameter,
            height: diameter,
            child: Semantics(
              button: true,
              label: '打开 AI 助手',
              onTap: widget.onPressed,
              child: Tooltip(
                message: 'AI 助手',
                excludeFromSemantics: true,
                child: GestureDetector(
                  dragStartBehavior: DragStartBehavior.down,
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: widget.onPressed,
                  onPanStart: (_) => setState(() => _dragging = true),
                  onPanUpdate: (details) => setState(() {
                    if (rangeX > 0) {
                      _x = (_x + details.delta.dx / rangeX).clamp(0.0, 1.0);
                    }
                    if (rangeY > 0) {
                      _y = (_y + details.delta.dy / rangeY).clamp(0.0, 1.0);
                    }
                  }),
                  onPanEnd: (_) => _snap(),
                  onPanCancel: _snap,
                  child: DecoratedBox(
                    key: const ValueKey('ai-assistant-orb'),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFCBEAFF),
                          Color(0xFFA5D8FF),
                          Color(0xFF85C7FD),
                        ],
                        stops: [0, 0.5, 1],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF78BBF1)
                              .withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CustomPaint(painter: _BotPainter()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// A vector bot matching the reference: round eyes, antenna, and rounded ears.
class _BotPainter extends CustomPainter {
  const _BotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 8.5, 14, 11),
        const Radius.circular(3.2),
      ),
      stroke,
    );
    canvas.drawLine(const Offset(12, 5), const Offset(12, 8.5), stroke);
    canvas.drawCircle(const Offset(12, 3.8), 1.5, fill);
    canvas.drawLine(const Offset(2.5, 12), const Offset(2.5, 16), stroke);
    canvas.drawLine(const Offset(21.5, 12), const Offset(21.5, 16), stroke);
    canvas.drawCircle(const Offset(9.5, 14), 1.15, fill);
    canvas.drawCircle(const Offset(14.5, 14), 1.15, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BotPainter oldDelegate) => false;
}
