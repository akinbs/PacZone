import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/zone_models.dart';
import '../theme/app_colors.dart';

class MockMapPainter extends CustomPainter {
  final bool gameMode;
  final bool scanMode;
  final double scanAnim;
  final List<Offset> coinPositions;
  final List<Offset> enemyPositions;
  final List<Color> enemyColors;
  final List<PathSegment>? zonePaths; // null → use fixed city paths
  final bool powerUpActive;

  static const _roadH = [0.22, 0.45, 0.68, 0.88];
  static const _roadV = [0.20, 0.42, 0.65, 0.85];
  static const _roadHalfW = 7.0;

  const MockMapPainter({
    this.gameMode = false,
    this.scanMode = false,
    this.scanAnim = 0.0,
    this.coinPositions = const [],
    this.enemyPositions = const [],
    this.enemyColors = const [],
    this.zonePaths,
    this.powerUpActive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawBackground(canvas, w, h);

    if (gameMode && zonePaths != null) {
      // Real zone data: skip the unrelated static city grid.
      // Only draw the actual zone paths, border, coins, and enemies.
      _drawPaths(canvas, w, h);
      _drawZoneBorder(canvas, w, h);
      _drawGameCoins(canvas);
      _drawEnemies(canvas);
    } else {
      // Fallback / scan preview: show the generic city mock.
      _drawBuildingBlocks(canvas, w, h);
      _drawRoads(canvas, w, h);
      _drawPark(canvas, w, h);
      _drawPaths(canvas, w, h);

      if (scanMode) _drawScanZone(canvas, w, h);
      if (gameMode) {
        _drawZoneBorder(canvas, w, h);
        _drawGameCoins(canvas);
        _drawEnemies(canvas);
      }
    }
  }

  void _drawBackground(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = AppColors.mapBg,
    );
  }

  void _drawBuildingBlocks(Canvas canvas, double w, double h) {
    final p = Paint()..color = AppColors.mapBuilding;
    final edgeP = Paint()
      ..color = const Color(0xFF0D0025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final hLines = [0.0, ..._roadH, 1.0];
    final vLines = [0.0, ..._roadV, 1.0];

    for (int r = 0; r < hLines.length - 1; r++) {
      for (int c = 0; c < vLines.length - 1; c++) {
        if (r == 2 && c == 2) continue; // park area

        final top    = r == 0                ? 0.0 : hLines[r] * h + _roadHalfW;
        final bottom = r == hLines.length - 2 ? h   : hLines[r + 1] * h - _roadHalfW;
        final left   = c == 0                ? 0.0 : vLines[c] * w + _roadHalfW;
        final right  = c == vLines.length - 2 ? w   : vLines[c + 1] * w - _roadHalfW;

        if (right - left < 10 || bottom - top < 10) continue;

        final rect  = Rect.fromLTRB(left, top, right, bottom);
        final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(rRect, p);
        canvas.drawRRect(rRect, edgeP);

        if (right - left > 30 && bottom - top > 30) {
          final divP = Paint()
            ..color = const Color(0xFF0A0018)
            ..strokeWidth = 0.8;
          if (bottom - top > 50) {
            canvas.drawLine(Offset(left + 4, (top + bottom) / 2),
                Offset(right - 4, (top + bottom) / 2), divP);
          }
          if (right - left > 50) {
            canvas.drawLine(Offset((left + right) / 2, top + 4),
                Offset((left + right) / 2, bottom - 4), divP);
          }
        }
      }
    }
  }

  void _drawRoads(Canvas canvas, double w, double h) {
    final rp = Paint()
      ..color = AppColors.mapRoad
      ..strokeCap = StrokeCap.square;

    for (final rh in _roadH) {
      rp.strokeWidth = _roadHalfW * 2;
      canvas.drawLine(Offset(0, rh * h), Offset(w, rh * h), rp);
    }
    for (final rv in _roadV) {
      rp.strokeWidth = _roadHalfW * 2;
      canvas.drawLine(Offset(rv * w, 0), Offset(rv * w, h), rp);
    }

    final dashP = Paint()
      ..color = const Color(0xFF1A0040)
      ..strokeWidth = 1.2;
    for (final rh in _roadH) {
      canvas.drawLine(Offset(0, rh * h), Offset(w, rh * h), dashP);
    }
    for (final rv in _roadV) {
      canvas.drawLine(Offset(rv * w, 0), Offset(rv * w, h), dashP);
    }
  }

  void _drawPark(Canvas canvas, double w, double h) {
    final left   = _roadV[1] * w + _roadHalfW;
    final right  = _roadV[2] * w - _roadHalfW;
    final top    = _roadH[1] * h + _roadHalfW;
    final bottom = _roadH[2] * h - _roadHalfW;
    if (right <= left || bottom <= top) return;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom), const Radius.circular(4)),
      Paint()..color = AppColors.mapPark,
    );

    final center = Offset((left + right) / 2, (top + bottom) / 2);
    final rx = (right - left) * 0.35;
    final ry = (bottom - top) * 0.35;
    final parkP = Paint()
      ..color = gameMode ? AppColors.mapPath.withAlpha(120) : const Color(0xFF1A4025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = gameMode ? 2.5 : 1.5;
    if (gameMode) parkP.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(
        Rect.fromCenter(center: center, width: rx * 2, height: ry * 2), parkP);

    final treeP = Paint()..color = const Color(0xFF0C2A14);
    for (final o in [
      Offset(-rx * 0.7, -ry * 0.6), Offset(rx * 0.6, -ry * 0.5),
      Offset(-rx * 0.5, ry * 0.6),  Offset(rx * 0.7, ry * 0.55),
    ]) {
      canvas.drawCircle(center + o, 5, treeP);
    }
  }

  void _drawPaths(Canvas canvas, double w, double h) {
    if (gameMode && zonePaths != null) {
      // Draw zone-specific paths with glow
      _drawZonePaths(canvas, w, h, zonePaths!);
    } else {
      // Default fixed city sidewalks
      final pathColor = gameMode ? AppColors.mapPath : AppColors.mapPathDim;
      if (gameMode) {
        _paintCityPathLines(canvas, w, h, Paint()
          ..color = AppColors.mapPathGlow
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
      _paintCityPathLines(canvas, w, h, Paint()
        ..color = pathColor
        ..strokeWidth = gameMode ? 2.8 : 1.5
        ..strokeCap = StrokeCap.round);
    }
  }

  void _drawZonePaths(Canvas canvas, double w, double h, List<PathSegment> paths) {
    final cx = w / 2;
    final cy = h / 2;

    // Build a single Path for all segments — one drawPath call instead of
    // N*2 drawLine calls, which is much faster with many OSM segments.
    final combined = Path();
    for (final seg in paths) {
      if (seg.points.length < 2) continue;
      combined.moveTo(cx + seg.points[0].dx, cy + seg.points[0].dy);
      for (int i = 1; i < seg.points.length; i++) {
        combined.lineTo(cx + seg.points[i].dx, cy + seg.points[i].dy);
      }
    }

    // Glow pass
    canvas.drawPath(
      combined,
      Paint()
        ..color = powerUpActive
            ? AppColors.secondary.withAlpha(180)
            : AppColors.mapPathGlow
        ..strokeWidth = powerUpActive ? 10 : 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, powerUpActive ? 6 : 4),
    );

    // Main path pass
    canvas.drawPath(
      combined,
      Paint()
        ..color = powerUpActive ? AppColors.secondary : AppColors.mapPath
        ..strokeWidth = powerUpActive ? 3.5 : 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintCityPathLines(Canvas canvas, double w, double h, Paint p) {
    const offset = _roadHalfW + 2;
    for (final rh in _roadH) {
      canvas.drawLine(Offset(0, rh * h - offset), Offset(w, rh * h - offset), p);
      canvas.drawLine(Offset(0, rh * h + offset), Offset(w, rh * h + offset), p);
    }
    for (final rv in _roadV) {
      canvas.drawLine(Offset(rv * w - offset, 0), Offset(rv * w - offset, h), p);
      canvas.drawLine(Offset(rv * w + offset, 0), Offset(rv * w + offset, h), p);
    }
  }

  void _drawScanZone(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    const half = 95.0;

    // Fog outside zone
    final fogPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRect(Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half));
    fogPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(fogPath, Paint()..color = const Color(0x55000000));

    final pulse = 0.5 + 0.5 * math.sin(scanAnim * 2 * math.pi);

    canvas.drawRect(
      Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
      Paint()..color = Color.lerp(AppColors.zoneFill, const Color(0x25B13BFF), scanAnim)!,
    );

    canvas.drawRect(
      Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
      Paint()
        ..color = AppColors.zoneBorder.withAlpha((120 + 135 * pulse).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Corner brackets
    const cl = 14.0;
    final cp = Paint()
      ..color = AppColors.zoneBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final corner in [
      [Offset(cx - half, cy - half + cl), Offset(cx - half, cy - half), Offset(cx - half + cl, cy - half)],
      [Offset(cx + half - cl, cy - half), Offset(cx + half, cy - half), Offset(cx + half, cy - half + cl)],
      [Offset(cx - half, cy + half - cl), Offset(cx - half, cy + half), Offset(cx - half + cl, cy + half)],
      [Offset(cx + half - cl, cy + half), Offset(cx + half, cy + half), Offset(cx + half, cy + half - cl)],
    ]) {
      canvas.drawLine(corner[0], corner[1], cp);
      canvas.drawLine(corner[1], corner[2], cp);
    }

    // Sweep line
    final sweepY = (cy - half) + (half * 2) * ((scanAnim + 0.25) % 1.0);
    canvas.drawLine(
      Offset(cx - half, sweepY),
      Offset(cx + half, sweepY),
      Paint()
        ..color = AppColors.primary.withAlpha(60)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _drawZoneBorder(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    const half = 95.0;

    final fog = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRect(Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half));
    fog.fillType = PathFillType.evenOdd;
    canvas.drawPath(fog, Paint()..color = const Color(0x70000000));

    canvas.drawRect(
      Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
      Paint()
        ..color = AppColors.zoneBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawGameCoins(Canvas canvas) {
    final glow = Paint()
      ..color = AppColors.coinGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final fill = Paint()..color = AppColors.coin;
    const inner = Color(0xFFFFF176);

    for (final pos in coinPositions) {
      canvas.drawCircle(pos, 7, glow);
      canvas.drawCircle(pos, 4.5, fill);
      canvas.drawCircle(pos, 2.5, Paint()..color = inner);
    }
  }

  void _drawEnemies(Canvas canvas) {
    for (int i = 0; i < enemyPositions.length; i++) {
      final pos = enemyPositions[i];
      final color = i < enemyColors.length ? enemyColors[i] : AppColors.ghost1;
      _paintGhost(canvas, pos, color);
    }
  }

  void _paintGhost(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center, 14,
      Paint()
        ..color = color.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final path = Path();
    const r = 10.0;
    path.addArc(
      Rect.fromCircle(center: Offset(center.dx, center.dy - 2), radius: r),
      math.pi, math.pi,
    );
    path.lineTo(center.dx + r, center.dy + 8);
    for (int i = 0; i < 3; i++) {
      path.quadraticBezierTo(
        center.dx + r - i * (r * 2 / 3) - r / 3,
        center.dy + (i.isEven ? 14 : 8),
        center.dx + r - (i + 0.5) * (r * 2 / 3),
        center.dy + 8,
      );
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);

    canvas.drawCircle(Offset(center.dx - 3.5, center.dy - 2), 2.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(center.dx + 3.5, center.dy - 2), 2.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(center.dx - 3, center.dy - 1.5), 1.2, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(center.dx + 4, center.dy - 1.5), 1.2, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(MockMapPainter old) =>
      old.gameMode != gameMode ||
      old.scanMode != scanMode ||
      old.scanAnim != scanAnim ||
      old.coinPositions != coinPositions ||
      old.enemyPositions != enemyPositions ||
      old.powerUpActive != powerUpActive ||
      old.zonePaths != zonePaths;
}
