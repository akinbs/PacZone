import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/avatar_model.dart';

class AvatarWidget extends StatelessWidget {
  final AvatarModel avatar;
  final double size;
  final bool showAura;
  final bool animated;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.size = 48,
    this.showAura = true,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AvatarPainter(
        avatar: avatar,
        showAura: showAura,
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final AvatarModel avatar;
  final bool showAura;

  const _AvatarPainter({required this.avatar, required this.showAura});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;

    // Aura glow
    if (showAura) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * 1.6,
        Paint()
          ..color = avatar.auraColor.withAlpha(40)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
      );
    }

    // Body circle
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = avatar.primaryColor);

    // Highlight
    canvas.drawCircle(
      Offset(cx - r * 0.25, cy - r * 0.25),
      r * 0.35,
      Paint()..color = Colors.white.withAlpha(45),
    );

    // Eyes
    _drawEyes(canvas, cx, cy, r, avatar.eyeType);

    // Accessory
    _drawAccessory(canvas, cx, cy, r, avatar.accessory, avatar.primaryColor);
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r, EyeType type) {
    final eyeColor = const Color(0xFF090040);
    final ex1 = cx - r * 0.28;
    final ex2 = cx + r * 0.28;
    final ey = cy - r * 0.1;
    final er = r * 0.14;

    switch (type) {
      case EyeType.round:
        canvas.drawCircle(Offset(ex1, ey), er, Paint()..color = eyeColor);
        canvas.drawCircle(Offset(ex2, ey), er, Paint()..color = eyeColor);
        canvas.drawCircle(Offset(ex1 + er * 0.3, ey - er * 0.3), er * 0.3,
            Paint()..color = Colors.white.withAlpha(180));
        canvas.drawCircle(Offset(ex2 + er * 0.3, ey - er * 0.3), er * 0.3,
            Paint()..color = Colors.white.withAlpha(180));

      case EyeType.star:
        _drawStar(canvas, Offset(ex1, ey), er, eyeColor);
        _drawStar(canvas, Offset(ex2, ey), er, eyeColor);

      case EyeType.cool:
        // Sunglasses look
        final gl = Paint()
          ..color = eyeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08;
        canvas.drawOval(
            Rect.fromCenter(center: Offset(ex1, ey), width: er * 2.2, height: er * 1.5), gl);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(ex2, ey), width: er * 2.2, height: er * 1.5), gl);
        canvas.drawLine(Offset(ex1 + er * 1.1, ey), Offset(ex2 - er * 1.1, ey), gl);

      case EyeType.happy:
        final hapP = Paint()
          ..color = eyeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCenter(center: Offset(ex1, ey), width: er * 1.8, height: er * 1.8),
            0, math.pi, false, hapP);
        canvas.drawArc(
            Rect.fromCenter(center: Offset(ex2, ey), width: er * 1.8, height: er * 1.8),
            0, math.pi, false, hapP);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawAccessory(
      Canvas canvas, double cx, double cy, double r, AccessoryType acc, Color baseColor) {
    switch (acc) {
      case AccessoryType.none:
        break;
      case AccessoryType.crown:
        final cp = Paint()..color = const Color(0xFFFFD700);
        final crownPath = Path()
          ..moveTo(cx - r * 0.55, cy - r * 0.9)
          ..lineTo(cx - r * 0.3, cy - r * 1.2)
          ..lineTo(cx, cy - r * 1.0)
          ..lineTo(cx + r * 0.3, cy - r * 1.2)
          ..lineTo(cx + r * 0.55, cy - r * 0.9)
          ..close();
        canvas.drawPath(crownPath, cp);
      case AccessoryType.headband:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
          math.pi * 1.1, math.pi * 0.8, false,
          Paint()
            ..color = baseColor.withAlpha(180)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.18,
        );
      case AccessoryType.cap:
        final capP = Paint()..color = const Color(0xFF1C0070);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy - r * 0.85), width: r * 1.4, height: r * 0.5),
          capP,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + r * 0.55, cy - r * 0.85), width: r * 0.5, height: r * 0.18),
          capP,
        );
      case AccessoryType.glasses:
        final gp = Paint()
          ..color = const Color(0xFF6644AA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1;
        canvas.drawCircle(Offset(cx - r * 0.28, cy - r * 0.1), r * 0.2, gp);
        canvas.drawCircle(Offset(cx + r * 0.28, cy - r * 0.1), r * 0.2, gp);
        canvas.drawLine(
            Offset(cx - r * 0.08, cy - r * 0.1), Offset(cx + r * 0.08, cy - r * 0.1), gp);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.avatar.primaryColor != avatar.primaryColor ||
      old.avatar.auraColor != avatar.auraColor ||
      old.avatar.eyeType != avatar.eyeType ||
      old.avatar.accessory != avatar.accessory;
}
