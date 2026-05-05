import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChompWidget extends StatefulWidget {
  final Color bodyColor;
  final Color auraColor;
  final double size;
  final bool animated;

  const ChompWidget({
    super.key,
    required this.bodyColor,
    required this.auraColor,
    this.size = 64,
    this.animated = true,
  });

  @override
  State<ChompWidget> createState() => _ChompWidgetState();
}

class _ChompWidgetState extends State<ChompWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _mouthAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _mouthAnim = Tween<double>(begin: 0.05, end: 0.42)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);
    if (widget.animated) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChompWidget old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animated && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mouthAnim,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ChompPainter(
          bodyColor: widget.bodyColor,
          auraColor: widget.auraColor,
          mouthOpenFraction: _mouthAnim.value,
        ),
      ),
    );
  }
}

class _ChompPainter extends CustomPainter {
  final Color bodyColor;
  final Color auraColor;
  final double mouthOpenFraction; // 0.0 – 0.5

  const _ChompPainter({
    required this.bodyColor,
    required this.auraColor,
    required this.mouthOpenFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // Aura glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.5,
      Paint()
        ..color = auraColor.withAlpha(50)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.1,
      Paint()
        ..color = bodyColor.withAlpha(40)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
    );

    // Body – chomp arc (mouth opens to the right, 0° = right)
    final halfMouth = mouthOpenFraction * math.pi;
    final startAngle = halfMouth;
    final sweepAngle = 2 * math.pi - 2 * halfMouth;

    final bodyPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    canvas.drawPath(bodyPath, Paint()..color = bodyColor);

    // Body highlight
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx - r * 0.18, cy - r * 0.18), radius: r * 0.45),
      math.pi * 1.1, math.pi * 0.6, false,
      Paint()
        ..color = Colors.white.withAlpha(35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.2,
    );

    // Eye
    final eyeOffset = Offset(cx - r * 0.12, cy - r * 0.45);
    canvas.drawCircle(eyeOffset, r * 0.14, Paint()..color = Colors.black.withAlpha(210));
    canvas.drawCircle(
      eyeOffset + Offset(r * 0.04, -r * 0.04),
      r * 0.05,
      Paint()..color = Colors.white.withAlpha(200),
    );
  }

  @override
  bool shouldRepaint(_ChompPainter old) =>
      old.mouthOpenFraction != mouthOpenFraction ||
      old.bodyColor != bodyColor ||
      old.auraColor != auraColor;
}
