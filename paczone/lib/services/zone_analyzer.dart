import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../models/scan_result_model.dart';
import '../models/zone_models.dart';
import '../theme/app_colors.dart';
import 'osm_service.dart';

/// Zone generation engine — Instant Dynamic PacZone Generation.
///
/// analyze() uses the player's GPS position as the center of a ~150 m × 150 m
/// square scan area. Real OSM map data within that square is fetched and
/// converted into game objects:
///   • footways / pedestrian / park paths  →  playable maze corridors
///   • buildings / blocked areas           →  maze walls
///   • vehicle roads                       →  blocked / risk areas
///
/// Coins and enemies are placed exclusively on walkable (pedestrian) paths.
/// Falls back to mock scenarios when the network is unavailable.
class ZoneAnalyzer {
  static int _scenarioIndex = 0;

  // Screen pixel radius and the real-world radius it maps to.
  // The OSM fetch uses a radius slightly larger than the 75 m half-side of the
  // 150 m × 150 m square so that paths crossing the boundary are included.
  static const double _zoneRadiusPx = 95.0;
  static const double _zoneRadiusM  = 110.0;
  // Public so game_screen can use the same scale for LatLng↔pixel conversion.
  static const double pixelsPerMeter = _zoneRadiusPx / _zoneRadiusM; // ~0.864

  // Half-side of the game square in meters — all game objects must stay inside.
  static const double _halfSizeM = 100.0;
  static double get _halfSizePx => _halfSizeM * pixelsPerMeter; // ~86.4 px

  // Paths and coins are kept this many pixels away from the zone boundary.
  // Gives visual breathing room so the underlying map remains visible.
  static const double _innerPadPx = 10.0;

  // ─── Public API ──────────────────────────────────────────────────────────

  static LocationValidation validateInput(LocationInput input) {
    if (input.accuracyMeters > 25) {
      return const LocationValidation.fail(
        status: ScanStatus.gpsWeak,
        reason: 'Konum doğruluğu düşük.',
        suggestion: 'Açık alanda birkaç saniye bekleyip tekrar deneyin.',
      );
    }
    if (input.speedKmh > 15) {
      return const LocationValidation.fail(
        status: ScanStatus.speedTooHigh,
        reason: 'Çok hızlı hareket ediyorsun.',
        suggestion: 'PacZone yürüyüş alanlarında oynanabilir. Yaya alanında tekrar dene.',
      );
    }
    return const LocationValidation.ok();
  }

  /// Full async analysis — fetches real OSM data, builds maze from actual
  /// streets. Falls back to mock scenarios if network is unavailable.
  static Future<ZoneAnalysisResult> analyze(LocationInput input) async {
    final validation = validateInput(input);
    if (!validation.passed) {
      return ZoneAnalysisResult(
        scanResult: ScanResultModel(
          status: validation.failStatus!,
          playabilityScore: 0,
          playableDistanceMeters: 0,
          estimatedDuration: Duration.zero,
          modeType: '',
          failReason: validation.failReason,
          suggestion: validation.suggestion,
        ),
      );
    }

    // Fetch real street data centred on the player's location.
    // Radius slightly larger than zone so boundary paths are included.
    final osm = await OsmService.fetchWays(
      input.lat,
      input.lng,
      radiusMeters: _zoneRadiusM + 50,
    );

    if (!osm.isEmpty) {
      return _buildFromOSM(input, osm);
    }

    // Network unavailable — fall back to mock scenarios (no OSM data).
    await Future.delayed(const Duration(milliseconds: 1500));
    final scenario = _scenarioIndex % 4;
    _scenarioIndex++;
    return switch (scenario) {
      0 => _buildParkZone(input),
      1 => _buildCampusZone(input),
      2 => _buildShortZone(input),
      _ => _buildEventZone(input),
    };
  }

  /// Debug helper — returns a result instantly without network (mock only).
  static ZoneAnalysisResult resultForScenario(int index) {
    final input = LocationInput.mockGood();
    return switch (index) {
      0 => _buildParkZone(input),
      1 => _buildCampusZone(input),
      2 => _buildShortZone(input),
      3 => _buildFailedZone(),
      4 => _buildEventZone(input),
      5 => _buildSpeedTooHighResult(),
      6 => _buildNoDataResult(),
      _ => _buildParkZone(input),
    };
  }

  // ─── OSM-based Zone Builder ───────────────────────────────────────────────

  static ZoneAnalysisResult _buildFromOSM(LocationInput input, OsmData osm) {
    final pedestrianSegs = <PathSegment>[];
    final allSegs        = <PathSegment>[];

    const clipR = _zoneRadiusPx + 8.0; // clip boundary (slight margin)

    for (final way in osm.ways) {
      // OSM way now carries geometry (LatLng list) directly from `out geom`
      if (way.geometry.length < 2) continue;

      final pts = way.geometry.map((ll) => OsmService.latLngToOffset(
        ll.latitude, ll.longitude, input.lat, input.lng, pixelsPerMeter,
      )).toList();

      // Only include ways with at least one node inside the zone.
      if (!pts.any((p) => p.distance <= clipR)) continue;

      // Clip to zone circle first, then to the inner square boundary.
      // Inner padding keeps paths away from the edge → underlying map visible.
      final circleSubs = _clipPolyline(pts, clipR);
      for (final circleSub in circleSubs) {
        if (circleSub.length < 2) continue;
        final squareSubs = _clipPolylineToSquare(
          circleSub, _halfSizePx - _innerPadPx,
        );
        for (final sub in squareSubs) {
          if (sub.length < 2) continue;
          final geo = sub.map((p) => OsmService.offsetToLatLng(
            p, input.lat, input.lng, pixelsPerMeter,
          )).toList();
          final seg = PathSegment(
            id: 'osm_${way.id}_s${allSegs.length}',
            type: way.isPedestrian ? PathType.footway : PathType.pedestrian,
            points: sub,
            geoPoints: geo,
          );
          allSegs.add(seg);
          if (way.isPedestrian) pedestrianSegs.add(seg);
        }
      }
    }

    // If OSM returned no usable paths, fall back to mock.
    if (allSegs.isEmpty) {
      debugPrint('[ZoneAnalyzer] No usable paths in OSM data — using mock');
      return _buildParkZone(input);
    }

    // Keep only paths that belong to the largest connected component.
    // Isolated paths (no shared nodes with any other path) are discarded.
    final connectedSegs = _keepLargestComponent(allSegs);
    final connectedIds   = {for (final s in connectedSegs) s.id};
    final connectedPeds  = pedestrianSegs.where((s) => connectedIds.contains(s.id)).toList();

    debugPrint('[ZoneAnalyzer] Built zone from OSM: ${connectedSegs.length} segs '
        '(${allSegs.length - connectedSegs.length} isolated removed), '
        '${connectedPeds.length} pedestrian');

    // Coins placed on pedestrian/footway paths only (playable corridors).
    // Enemies patrol ALL paths; coins never appear on vehicle roads.
    final coinPaths = connectedPeds.isNotEmpty ? connectedPeds : connectedSegs;

    // Total path length in real-world metres (use connected segments only).
    final totalPx = connectedSegs.fold(0.0, (s, seg) => s + seg.lengthPixels);
    final totalM  = totalPx / pixelsPerMeter;

    final difficulty = totalM >= 500
        ? DifficultyLevel.hard
        : totalM >= 250
            ? DifficultyLevel.normal
            : DifficultyLevel.easy;

    final vehicleCount = connectedSegs.length - connectedPeds.length;
    final roadRisk = vehicleCount / math.max(1.0, connectedPeds.length.toDouble());

    final breakdown = _calcScore(
      pathLengthM:   totalM,
      connected:     connectedSegs.length >= 2,
      roadRiskRatio: roadRisk,
      safeStart:     connectedPeds.isNotEmpty,
      gpsAccuracy:   input.accuracyMeters,
      hasDiversity:  connectedSegs.length >= 4,
      isOpenArea:    connectedPeds.isNotEmpty,
    );

    final durationSec = (totalM / 40).round().clamp(60, 360); // ~40 m/min walk
    final duration    = Duration(seconds: durationSec);
    final status      = totalM >= 80 ? ScanStatus.success : ScanStatus.partial;

    final zone = DynamicZoneData(
      zoneId: 'zone_osm_${DateTime.now().millisecondsSinceEpoch}',
      layout: ZoneLayout.park,
      paths:  connectedSegs,
      // Coins sampled along pedestrian paths at ~25 m intervals.
      coins:   _placeCoins(coinPaths, spacingPixels: 12),
      // Ghosts patrol ALL connected paths (including vehicle roads).
      enemies: _buildEnemies(connectedSegs, difficulty),
      totalPathLengthMeters: totalM,
      playabilityBreakdown:  breakdown,
      estimatedDuration:     duration,
      difficulty:            difficulty,
      modeType:              'Street Run',
      centerLat: input.lat,
      centerLng: input.lng,
    );

    return ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status:                status,
        playabilityScore:      breakdown.total,
        playableDistanceMeters: totalM,
        estimatedDuration:     duration,
        modeType:              'Street Run',
        failReason: status == ScanStatus.partial
            ? 'Bu alanda sınırlı yaya yolu bulundu.'
            : null,
      ),
      zoneData: zone,
    );
  }

  // ─── Playability Scoring (spec §11.2) ────────────────────────────────────

  static PlayabilityBreakdown _calcScore({
    required double pathLengthM,
    required bool connected,
    required double roadRiskRatio,
    required bool safeStart,
    required double gpsAccuracy,
    required bool hasDiversity,
    required bool isOpenArea,
  }) {
    final pathScore = pathLengthM >= 350 ? 25
        : pathLengthM >= 250 ? 21
        : pathLengthM >= 180 ? 17
        : pathLengthM >= 120 ? 12
        : pathLengthM >= 80  ? 7
        : 2;

    final connScore  = connected ? 20 : 8;

    final roadScore  = roadRiskRatio < 0.2 ? 20
        : roadRiskRatio < 0.5 ? 15
        : roadRiskRatio < 1.0 ? 8
        : roadRiskRatio < 2.0 ? 3
        : 0;

    final safeScore  = safeStart ? 15 : 5;

    final gpsScore   = gpsAccuracy <= 8  ? 10
        : gpsAccuracy <= 15 ? 7
        : gpsAccuracy <= 20 ? 4
        : 1;

    final divScore   = hasDiversity ? 5 : 2;
    final openScore  = isOpenArea   ? 5 : 2;

    return PlayabilityBreakdown(
      pathLengthScore:   pathScore,
      connectivityScore: connScore,
      roadRiskScore:     roadScore,
      safeStartScore:    safeScore,
      gpsScore:          gpsScore,
      diversityScore:    divScore,
      openAreaScore:     openScore,
    );
  }

  // ─── Coin Placement ───────────────────────────────────────────────────────

  static List<CoinModel> _placeCoins(
    List<PathSegment> paths, {
    double spacingPixels = 32,
    double powerCoinChance = 0.12,
  }) {
    final coins = <CoinModel>[];
    int idx = 0;
    final rng = math.Random(42);

    final halfPx = _halfSizePx - _innerPadPx;
    for (final seg in paths) {
      for (final pt in seg.samplePoints(spacingPixels)) {
        if (pt.distance < 22) continue;
        // Keep coins within the padded boundary (same as path clipping)
        if (pt.dx.abs() > halfPx || pt.dy.abs() > halfPx) continue;

        final isPower = idx % 8 == 7 ||
            (rng.nextDouble() < powerCoinChance && idx % 4 == 0);
        coins.add(CoinModel(
          id:       'coin_$idx',
          position: pt,
          type:     isPower ? CoinType.power : CoinType.normal,
          points:   isPower ? 500 : 100,
        ));
        idx++;
      }
    }
    return coins;
  }

  // ─── Enemy Route Generation ───────────────────────────────────────────────

  static List<ZoneEnemy> _buildEnemies(
    List<PathSegment> paths,
    DifficultyLevel difficulty,
  ) {
    final count = switch (difficulty) {
      DifficultyLevel.easy   => 1,
      DifficultyLevel.normal => 2,
      DifficultyLevel.hard   => 3,
    };

    final colors = [AppColors.ghost1, AppColors.ghost2, AppColors.ghost3];

    // Ghosts start on the paths furthest from the player's position.
    final sortedPaths = List<PathSegment>.from(paths)
      ..sort((a, b) {
        final aDist = a.points.map((p) => p.distance).reduce(math.max);
        final bDist = b.points.map((p) => p.distance).reduce(math.max);
        return bDist.compareTo(aDist);
      });

    final halfPx = _halfSizePx - _innerPadPx;
    final enemies = <ZoneEnemy>[];
    for (int i = 0; i < math.min(count, sortedPaths.length); i++) {
      final route = sortedPaths[i].points
          .where((p) => p.distance > 20 && p.dx.abs() <= halfPx && p.dy.abs() <= halfPx)
          .toList();
      if (route.length < 2) continue;
      enemies.add(ZoneEnemy(
        id:          'enemy_${i + 1}',
        color:       colors[i % colors.length],
        routePoints: route,
        speedFactor: 0.8 + i * 0.15,
      ));
    }
    return enemies;
  }

  // ─── Connectivity Filter ─────────────────────────────────────────────────

  /// Returns only the segments that belong to the largest connected component.
  /// Two segments are "connected" when any point of one lies within [snapPx]
  /// pixels of any point of the other (shared OSM nodes have ~0 px distance).
  static List<PathSegment> _keepLargestComponent(
    List<PathSegment> segs, {
    double snapPx = 5.0,
  }) {
    if (segs.length <= 1) return segs;

    final n = segs.length;
    final adj = List.generate(n, (_) => <int>[]);

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if (_segmentsTouch(segs[i].points, segs[j].points, snapPx)) {
          adj[i].add(j);
          adj[j].add(i);
        }
      }
    }

    final visited = List.filled(n, false);
    var largest = <int>[];

    for (int s = 0; s < n; s++) {
      if (visited[s]) continue;
      final comp = <int>[];
      final queue = [s];
      visited[s] = true;
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        comp.add(cur);
        for (final nb in adj[cur]) {
          if (!visited[nb]) {
            visited[nb] = true;
            queue.add(nb);
          }
        }
      }
      if (comp.length > largest.length) largest = comp;
    }

    final kept = largest.toSet();
    return [for (int i = 0; i < n; i++) if (kept.contains(i)) segs[i]];
  }

  /// Returns true if any point of [a] is within [snap] pixels of any point of [b].
  static bool _segmentsTouch(List<Offset> a, List<Offset> b, double snap) {
    for (final pa in a) {
      for (final pb in b) {
        if ((pa - pb).distance <= snap) return true;
      }
    }
    return false;
  }

  // ─── Square Clipping (Liang–Barsky) ──────────────────────────────────────

  /// Clips a polyline to the square [-half, half]×[-half, half].
  /// Returns one or more sub-segments fully inside the square.
  static List<List<Offset>> _clipPolylineToSquare(
      List<Offset> pts, double half) {
    final out = <List<Offset>>[];
    var cur = <Offset>[];

    for (int i = 0; i < pts.length - 1; i++) {
      final clip = _clipSegToSquare(pts[i], pts[i + 1], half);
      if (clip == null) {
        if (cur.length >= 2) out.add(List.from(cur));
        cur = [];
        continue;
      }
      final (a, b) = clip;
      if (cur.isEmpty) {
        cur = [a, b];
      } else if ((cur.last - a).distance > 0.5) {
        if (cur.length >= 2) out.add(List.from(cur));
        cur = [a, b];
      } else {
        cur.add(b);
      }
    }
    if (cur.length >= 2) out.add(cur);
    return out;
  }

  /// Liang–Barsky clip of [p1]→[p2] to [-half, half]×[-half, half].
  /// Returns the clipped endpoints, or null if the segment lies entirely outside.
  static (Offset, Offset)? _clipSegToSquare(Offset p1, Offset p2, double half) {
    double t0 = 0, t1 = 1;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;

    // p·t ≤ q for each of the four half-planes
    final ps = <double>[-dx, dx, -dy, dy];
    final qs = <double>[p1.dx + half, half - p1.dx, p1.dy + half, half - p1.dy];

    for (int i = 0; i < 4; i++) {
      if (ps[i] == 0) {
        if (qs[i] < 0) return null; // parallel and outside
      } else {
        final t = qs[i] / ps[i];
        if (ps[i] < 0) {
          if (t > t0) t0 = t;
        } else {
          if (t < t1) t1 = t;
        }
      }
      if (t0 > t1) return null;
    }
    return (
      Offset(p1.dx + t0 * dx, p1.dy + t0 * dy),
      Offset(p1.dx + t1 * dx, p1.dy + t1 * dy),
    );
  }

  // ─── Polyline Clipping ────────────────────────────────────────────────────

  /// Clips a polyline to a circle of radius [r] centred at the origin.
  /// Returns one or more sub-segments that lie inside the circle.
  /// This prevents long OSM roads from extending far off-screen.
  static List<List<Offset>> _clipPolyline(List<Offset> pts, double r) {
    final out = <List<Offset>>[];
    var cur = <Offset>[];
    for (int i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final aIn = a.distance <= r, bIn = b.distance <= r;
      if (aIn && bIn) {
        if (cur.isEmpty) cur.add(a);
        cur.add(b);
      } else if (aIn && !bIn) {
        if (cur.isEmpty) cur.add(a);
        final c = _circleExit(a, b, r);
        if (c != null) cur.add(c);
        if (cur.length >= 2) out.add(List.from(cur));
        cur = [];
      } else if (!aIn && bIn) {
        // re-entering: find entry point from b's perspective
        final c = _circleExit(b, a, r);
        cur = c != null ? [c] : [];
        cur.add(b);
      }
      // both outside → skip
    }
    if (cur.length >= 2) out.add(cur);
    return out;
  }

  /// Parametric line-circle intersection: finds where [p1]→[p2] crosses
  /// the circle of radius [r], where [p1] is inside the circle.
  static Offset? _circleExit(Offset p1, Offset p2, double r) {
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final a = dx * dx + dy * dy;
    if (a == 0) return null;
    final b = 2 * (p1.dx * dx + p1.dy * dy);
    final c = p1.dx * p1.dx + p1.dy * p1.dy - r * r;
    final disc = b * b - 4 * a * c;
    if (disc < 0) return null;
    final t = (-b + math.sqrt(disc)) / (2 * a);
    if (t < 0 || t > 1) return null;
    return Offset(p1.dx + t * dx, p1.dy + t * dy);
  }

  // ─── Mock / Fallback Zone Builders ───────────────────────────────────────

  static ZoneAnalysisResult _buildSpeedTooHighResult() {
    return const ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.speedTooHigh,
        playabilityScore: 0,
        playableDistanceMeters: 0,
        estimatedDuration: Duration.zero,
        modeType: '',
        failReason: 'Çok hızlı hareket ediyorsun.',
        suggestion: 'PacZone yürüyüş hızında oynanabilir. Dur ve tekrar tara.',
      ),
    );
  }

  static ZoneAnalysisResult _buildNoDataResult() {
    return const ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.noData,
        playabilityScore: 0,
        playableDistanceMeters: 0,
        estimatedDuration: Duration.zero,
        modeType: '',
        failReason: 'Konum verisi alınamadı.',
        suggestion: 'İnternet bağlantınızı ve GPS ayarlarını kontrol edin.',
      ),
    );
  }

  static ZoneAnalysisResult _buildParkZone(LocationInput input) {
    final breakdown = _calcScore(
      pathLengthM: 420, connected: true, roadRiskRatio: 0.15,
      safeStart: true, gpsAccuracy: input.accuracyMeters,
      hasDiversity: true, isOpenArea: true,
    );
    final paths = _parkPaths();
    final zone = DynamicZoneData(
      zoneId: 'zone_park_${DateTime.now().millisecondsSinceEpoch}',
      layout: ZoneLayout.park,
      paths:   paths,
      coins:   _placeCoins(paths, spacingPixels: 30),
      enemies: _buildEnemies(paths, DifficultyLevel.normal),
      totalPathLengthMeters: 420,
      playabilityBreakdown:  breakdown,
      estimatedDuration: const Duration(minutes: 2, seconds: 30),
      difficulty: DifficultyLevel.normal,
      modeType:   'Classic Run',
      centerLat: input.lat,
      centerLng: input.lng,
    );
    return ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.success,
        playabilityScore: breakdown.total,
        playableDistanceMeters: 420,
        estimatedDuration: const Duration(minutes: 2, seconds: 30),
        modeType: 'Classic Run',
      ),
      zoneData: zone,
    );
  }

  static ZoneAnalysisResult _buildCampusZone(LocationInput input) {
    final breakdown = _calcScore(
      pathLengthM: 320, connected: true, roadRiskRatio: 0.25,
      safeStart: true, gpsAccuracy: input.accuracyMeters,
      hasDiversity: true, isOpenArea: false,
    );
    final paths = _campusPaths();
    final zone = DynamicZoneData(
      zoneId: 'zone_campus_${DateTime.now().millisecondsSinceEpoch}',
      layout: ZoneLayout.campusGrid,
      paths:   paths,
      coins:   _placeCoins(paths, spacingPixels: 34),
      enemies: _buildEnemies(paths, DifficultyLevel.normal),
      totalPathLengthMeters: 320,
      playabilityBreakdown:  breakdown,
      estimatedDuration: const Duration(minutes: 2),
      difficulty: DifficultyLevel.normal,
      modeType:   'Classic Run',
      centerLat: input.lat,
      centerLng: input.lng,
    );
    return ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.success,
        playabilityScore: breakdown.total,
        playableDistanceMeters: 320,
        estimatedDuration: const Duration(minutes: 2),
        modeType: 'Classic Run',
      ),
      zoneData: zone,
    );
  }

  static ZoneAnalysisResult _buildShortZone(LocationInput input) {
    final breakdown = _calcScore(
      pathLengthM: 170, connected: true, roadRiskRatio: 0.8,
      safeStart: true, gpsAccuracy: input.accuracyMeters,
      hasDiversity: false, isOpenArea: false,
    );
    final paths = _shortPaths();
    final zone = DynamicZoneData(
      zoneId: 'zone_short_${DateTime.now().millisecondsSinceEpoch}',
      layout: ZoneLayout.shortLoop,
      paths:   paths,
      coins:   _placeCoins(paths, spacingPixels: 26),
      enemies: _buildEnemies(paths, DifficultyLevel.easy),
      totalPathLengthMeters: 170,
      playabilityBreakdown:  breakdown,
      estimatedDuration: const Duration(minutes: 1, seconds: 15),
      difficulty: DifficultyLevel.easy,
      modeType:   'Short Run',
      centerLat: input.lat,
      centerLng: input.lng,
    );
    return ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.partial,
        playabilityScore: breakdown.total,
        playableDistanceMeters: 170,
        estimatedDuration: const Duration(minutes: 1, seconds: 15),
        modeType: 'Short Run',
        failReason: '150 m çevrende sınırlı yaya yolu bulundu.',
      ),
      zoneData: zone,
    );
  }

  static ZoneAnalysisResult _buildFailedZone() {
    return const ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.failed,
        playabilityScore: 18,
        playableDistanceMeters: 0,
        estimatedDuration: Duration.zero,
        modeType: '',
        failReason:
            'Bu alan PacZone için güvenli değil. '
            'Yaya yolu yoğunluğu düşük veya araç yolları fazla olabilir.',
        suggestion:
            'Park, kampüs, sahil yolu veya meydan gibi bir alanda tekrar deneyin.',
      ),
    );
  }

  // EventZone is NOT a separate game mode — it is a bonus layer on top of normal
  // dynamic PacZone generation. When the user's location falls inside a known
  // event area, this fallback simulates the extra XP / mode bonus that would be
  // applied to the real-world generated zone.
  static ZoneAnalysisResult _buildEventZone(LocationInput input) {
    final breakdown = _calcScore(
      pathLengthM: 680, connected: true, roadRiskRatio: 0.05,
      safeStart: true, gpsAccuracy: input.accuracyMeters,
      hasDiversity: true, isOpenArea: true,
    );
    final paths = [..._parkPaths(), ..._campusPaths()];
    final zone = DynamicZoneData(
      zoneId: 'zone_event_${DateTime.now().millisecondsSinceEpoch}',
      layout: ZoneLayout.eventArena,
      paths:   paths,
      coins:   _placeCoins(paths, spacingPixels: 24, powerCoinChance: 0.18),
      enemies: _buildEnemies(paths, DifficultyLevel.hard),
      totalPathLengthMeters: 680,
      playabilityBreakdown:  breakdown,
      estimatedDuration: const Duration(minutes: 3, seconds: 45),
      difficulty: DifficultyLevel.hard,
      modeType:   'SpeedRun',
      centerLat: input.lat,
      centerLng: input.lng,
    );
    return ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.success,
        playabilityScore: breakdown.total,
        playableDistanceMeters: 680,
        estimatedDuration: const Duration(minutes: 3, seconds: 45),
        modeType:    'SpeedRun',
        isEventZone: true,
        eventName:   'Campus Rush',
        eventBonus:  '2x XP Aktif',
      ),
      zoneData: zone,
    );
  }

  // ─── Mock Path Definitions (fallback) ────────────────────────────────────

  static List<PathSegment> _parkPaths() => [
    PathSegment(
      id: 'park_oval', type: PathType.park,
      points: ovalPoints(rx: 82, ry: 68, steps: 24),
    ),
    const PathSegment(
      id: 'park_h', type: PathType.footway,
      points: [Offset(-82, 0), Offset(-40, 0), Offset(0, 0), Offset(40, 0), Offset(82, 0)],
    ),
    const PathSegment(
      id: 'park_v', type: PathType.footway,
      points: [Offset(0, -68), Offset(0, -34), Offset(0, 0), Offset(0, 34), Offset(0, 68)],
    ),
    const PathSegment(
      id: 'park_nw', type: PathType.pedestrian,
      points: [Offset(-82, -68), Offset(-41, -34), Offset(0, 0)],
    ),
    const PathSegment(
      id: 'park_se', type: PathType.pedestrian,
      points: [Offset(82, 68), Offset(41, 34), Offset(0, 0)],
    ),
  ];

  static List<PathSegment> _campusPaths() => [
    const PathSegment(
      id: 'campus_h1', type: PathType.campus,
      points: [Offset(-78, -52), Offset(-39, -52), Offset(0, -52), Offset(39, -52), Offset(78, -52)],
    ),
    const PathSegment(
      id: 'campus_h2', type: PathType.campus,
      points: [Offset(-78, 52), Offset(-39, 52), Offset(0, 52), Offset(39, 52), Offset(78, 52)],
    ),
    const PathSegment(
      id: 'campus_v1', type: PathType.campus,
      points: [Offset(-52, -72), Offset(-52, -52), Offset(-52, 0), Offset(-52, 52), Offset(-52, 72)],
    ),
    const PathSegment(
      id: 'campus_v2', type: PathType.campus,
      points: [Offset(52, -72), Offset(52, -52), Offset(52, 0), Offset(52, 52), Offset(52, 72)],
    ),
    const PathSegment(
      id: 'campus_center', type: PathType.pedestrian,
      points: [Offset(-78, 0), Offset(-52, 0), Offset(0, 0), Offset(52, 0), Offset(78, 0)],
    ),
  ];

  static List<PathSegment> _shortPaths() => [
    const PathSegment(
      id: 'short_left', type: PathType.footway,
      points: [Offset(-62, -48), Offset(-62, 0), Offset(-62, 48)],
    ),
    const PathSegment(
      id: 'short_bottom', type: PathType.footway,
      points: [Offset(-62, 48), Offset(-31, 48), Offset(0, 48), Offset(31, 48), Offset(62, 48)],
    ),
    const PathSegment(
      id: 'short_right', type: PathType.footway,
      points: [Offset(62, 48), Offset(62, 0), Offset(62, -48)],
    ),
    const PathSegment(
      id: 'short_top', type: PathType.footway,
      points: [Offset(-62, -48), Offset(0, -48), Offset(62, -48)],
    ),
  ];
}
