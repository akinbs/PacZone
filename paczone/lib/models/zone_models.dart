import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'game_models.dart';
import 'scan_result_model.dart';

enum PathType { footway, pedestrian, park, campus, waterfront }

enum ZoneLayout { park, campusGrid, shortLoop, eventArena }

enum DifficultyLevel { easy, normal, hard }

// Walkable path segment
// [points]    — screen-relative pixel offsets from center (game logic / mock)
// [geoPoints] — real-world LatLng coordinates (populated from OSM, null for mock)
class PathSegment {
  final String id;
  final List<Offset> points;
  final PathType type;
  final List<LatLng>? geoPoints; // direct map coordinates when sourced from OSM

  const PathSegment({
    required this.id,
    required this.points,
    required this.type,
    this.geoPoints,
  });

  double get lengthPixels {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  // Returns evenly-spaced sample points along the segment
  List<Offset> samplePoints(double spacingPixels) {
    final result = <Offset>[];
    if (points.length < 2) return points;
    result.add(points.first);
    double carry = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      final segLen = (to - from).distance;
      double walked = spacingPixels - carry;
      while (walked <= segLen) {
        result.add(Offset.lerp(from, to, walked / segLen)!);
        walked += spacingPixels;
      }
      carry = segLen - (walked - spacingPixels);
    }
    return result;
  }
}

// Enemy patrol data
class ZoneEnemy {
  final String id;
  final Color color;
  final List<Offset> routePoints; // screen-relative offsets from center
  final double speedFactor;       // 1.0 = baseline

  const ZoneEnemy({
    required this.id,
    required this.color,
    required this.routePoints,
    required this.speedFactor,
  });
}

// 7-component playability score breakdown (per spec section 11.2)
class PlayabilityBreakdown {
  final int pathLengthScore;   // 0-25
  final int connectivityScore; // 0-20
  final int roadRiskScore;     // 0-20
  final int safeStartScore;    // 0-15
  final int gpsScore;          // 0-10
  final int diversityScore;    // 0-5
  final int openAreaScore;     // 0-5

  const PlayabilityBreakdown({
    required this.pathLengthScore,
    required this.connectivityScore,
    required this.roadRiskScore,
    required this.safeStartScore,
    required this.gpsScore,
    required this.diversityScore,
    required this.openAreaScore,
  });

  int get total =>
      pathLengthScore + connectivityScore + roadRiskScore +
      safeStartScore + gpsScore + diversityScore + openAreaScore;

  @override
  String toString() =>
      'path=$pathLengthScore conn=$connectivityScore road=$roadRiskScore '
      'start=$safeStartScore gps=$gpsScore div=$diversityScore open=$openAreaScore → $total';
}

// Full generated zone, ready to drive the game screen
class DynamicZoneData {
  final String zoneId;
  final ZoneLayout layout;
  final List<PathSegment> paths;
  final List<CoinModel> coins;
  final List<ZoneEnemy> enemies;
  final double totalPathLengthMeters;
  final PlayabilityBreakdown playabilityBreakdown;
  final Duration estimatedDuration;
  final DifficultyLevel difficulty;
  final String modeType;
  // GPS center — user's position when PacZone was created
  final double centerLat;
  final double centerLng;

  const DynamicZoneData({
    required this.zoneId,
    required this.layout,
    required this.paths,
    required this.coins,
    required this.enemies,
    required this.totalPathLengthMeters,
    required this.playabilityBreakdown,
    required this.estimatedDuration,
    required this.difficulty,
    required this.modeType,
    required this.centerLat,
    required this.centerLng,
  });

  int get playabilityScore => playabilityBreakdown.total;
}

// GPS + motion data sent to ZoneAnalyzer
class LocationInput {
  final double lat;
  final double lng;
  final double accuracyMeters;
  final double speedKmh;
  final double headingDegrees;
  final DateTime timestamp;

  const LocationInput({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.speedKmh,
    required this.headingDegrees,
    required this.timestamp,
  });

  static LocationInput mockGood() => LocationInput(
        lat: 41.0082, lng: 28.9784,
        accuracyMeters: 4.5, speedKmh: 3.2, headingDegrees: 45,
        timestamp: DateTime.now(),
      );

  static LocationInput mockGpsWeak() => LocationInput(
        lat: 41.0082, lng: 28.9784,
        accuracyMeters: 35.0, speedKmh: 1.5, headingDegrees: 0,
        timestamp: DateTime.now(),
      );

  static LocationInput mockVehicle() => LocationInput(
        lat: 41.0082, lng: 28.9784,
        accuracyMeters: 5.0, speedKmh: 52.0, headingDegrees: 90,
        timestamp: DateTime.now(),
      );
}

// Validation result before analysis starts
class LocationValidation {
  final bool passed;
  final ScanStatus? failStatus;
  final String? failReason;
  final String? suggestion;

  const LocationValidation.ok() : passed = true, failStatus = null, failReason = null, suggestion = null;

  const LocationValidation.fail({
    required ScanStatus status,
    required String reason,
    this.suggestion,
  })  : passed = false,
        failStatus = status,
        failReason = reason;
}

// Combined output of ZoneAnalyzer.analyze()
class ZoneAnalysisResult {
  final ScanResultModel scanResult;
  final DynamicZoneData? zoneData;

  const ZoneAnalysisResult({required this.scanResult, this.zoneData});

  bool get isPlayable => zoneData != null &&
      (scanResult.status == ScanStatus.success ||
          scanResult.status == ScanStatus.partial);
}

// Power-up state (activated by power coins)
class PowerUpState {
  final bool active;
  final int remainingSeconds;
  static const int _fullDuration = 6;

  const PowerUpState({this.active = false, this.remainingSeconds = 0});

  static const inactive = PowerUpState();

  PowerUpState activate() =>
      const PowerUpState(active: true, remainingSeconds: _fullDuration);

  PowerUpState tick() => remainingSeconds <= 1
      ? const PowerUpState()
      : PowerUpState(active: true, remainingSeconds: remainingSeconds - 1);

  double get progress => active ? remainingSeconds / _fullDuration : 0.0;
}

// Helper — generate oval points (screen-relative)
List<Offset> ovalPoints({
  required double rx,
  required double ry,
  int steps = 20,
}) {
  return List.generate(steps + 1, (i) {
    final angle = 2 * math.pi * i / steps;
    return Offset(rx * math.cos(angle), ry * math.sin(angle));
  });
}
