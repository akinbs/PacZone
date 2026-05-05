import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// OsmWay now embeds node geometry directly (Overpass `out geom` format).
// No separate OsmNode / nodes-map needed.
class OsmWay {
  final int id;
  final String highway;
  final List<LatLng> geometry; // ordered lat/lng from Overpass geometry array

  const OsmWay({
    required this.id,
    required this.highway,
    required this.geometry,
  });

  static const _pedestrianTypes = {
    'footway', 'pedestrian', 'path', 'steps', 'living_street', 'cycleway',
  };

  bool get isPedestrian => _pedestrianTypes.contains(highway);
}

class OsmData {
  final List<OsmWay> ways;
  const OsmData({required this.ways});
  const OsmData.empty() : ways = const [];
  bool get isEmpty => ways.isEmpty;
}

class OsmService {
  // Three independent Overpass mirrors — first success wins.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
  ];

  /// Fetches walkable ways within [radiusMeters] of [lat]/[lng].
  /// Uses `out geom` so node coordinates are embedded in each way — no
  /// second node-query step needed. Tries GET (firewall-friendly) then
  /// POST as fallback for each mirror.
  static Future<OsmData> fetchWays(
    double lat,
    double lng, {
    double radiusMeters = 250,
  }) async {
    final r = radiusMeters.round();
    // \$ escapes the regex end-anchor so Dart doesn't treat it as interpolation.
    final query =
        '[out:json][timeout:15];\n'
        '(\n'
        '  way[highway~"^(footway|pedestrian|path|steps|living_street|cycleway'
        '|residential|service|unclassified|tertiary)\$"](around:$r,$lat,$lng);\n'
        ');\nout geom;\n';

    debugPrint('[OSM] Fetching ways at ($lat,$lng) radius=${r}m');

    for (final endpoint in _endpoints) {
      // ── POST (shorter URL, works for long queries) ─────────────────────
      try {
        final res = await http
            .post(Uri.parse(endpoint),
                body: 'data=${Uri.encodeComponent(query)}',
                headers: {
                  'User-Agent': 'PacZone/1.0 Flutter',
                  'Content-Type': 'application/x-www-form-urlencoded',
                })
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final parsed = _parse(res.body);
          if (!parsed.isEmpty) {
            debugPrint('[OSM] POST $endpoint → ${parsed.ways.length} ways ✓');
            return parsed;
          }
          debugPrint('[OSM] POST $endpoint → 200 but 0 ways parsed');
        } else {
          debugPrint('[OSM] POST $endpoint → HTTP ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('[OSM] POST $endpoint failed: $e');
      }

      // ── GET fallback ───────────────────────────────────────────────────
      try {
        final uri = Uri.parse(endpoint)
            .replace(queryParameters: {'data': query});
        final res = await http.get(uri,
            headers: {'User-Agent': 'PacZone/1.0 Flutter'})
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final parsed = _parse(res.body);
          if (!parsed.isEmpty) {
            debugPrint('[OSM] GET $endpoint → ${parsed.ways.length} ways ✓');
            return parsed;
          }
          debugPrint('[OSM] GET $endpoint → 200 but 0 ways parsed');
        } else {
          debugPrint('[OSM] GET $endpoint → HTTP ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('[OSM] GET $endpoint failed: $e');
      }
    }

    debugPrint('[OSM] All endpoints exhausted — using mock fallback');
    return const OsmData.empty();
  }

  static OsmData _parse(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      debugPrint('[OSM] JSON parse error: $e');
      return const OsmData.empty();
    }
    if (decoded is! Map<String, dynamic>) return const OsmData.empty();

    final elements = decoded['elements'];
    if (elements is! List) return const OsmData.empty();

    final ways = <OsmWay>[];

    for (final el in elements) {
      if (el is! Map<String, dynamic>) continue;
      if (el['type'] != 'way') continue;

      final id = el['id'];
      if (id is! int) continue;

      final tags = el['tags'] as Map<String, dynamic>? ?? {};
      final highway = tags['highway'] as String? ?? '';
      if (highway.isEmpty) continue;

      // Parse embedded geometry from `out geom` response
      final rawGeom = el['geometry'];
      if (rawGeom is! List || rawGeom.length < 2) continue;

      final geometry = <LatLng>[];
      for (final g in rawGeom) {
        if (g is! Map<String, dynamic>) continue;
        final lat = (g['lat'] as num?)?.toDouble();
        final lon = (g['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          geometry.add(LatLng(lat, lon));
        }
      }
      if (geometry.length < 2) continue;

      ways.add(OsmWay(id: id, highway: highway, geometry: geometry));
    }

    debugPrint('[OSM] Parsed ${ways.length} ways from response');
    return OsmData(ways: ways);
  }

  // ── Coordinate helpers ──────────────────────────────────────────────────

  /// Converts a LatLng to a screen-relative Offset (pixels from center).
  /// [centerLat]/[centerLng] = player's position → Offset.zero.
  static Offset latLngToOffset(
    double nodeLat,
    double nodeLng,
    double centerLat,
    double centerLng,
    double pixelsPerMeter,
  ) {
    const metersPerDegLat = 111320.0;
    final lngScale = metersPerDegLat * math.cos(centerLat * math.pi / 180);
    final dx = (nodeLng - centerLng) * lngScale * pixelsPerMeter;
    final dy = -(nodeLat - centerLat) * metersPerDegLat * pixelsPerMeter;
    return Offset(dx, dy);
  }

  /// Inverse of [latLngToOffset]: pixel offset → LatLng.
  /// Used for mock paths that are defined in pixel space.
  static LatLng offsetToLatLng(
    Offset offset,
    double centerLat,
    double centerLng,
    double pixelsPerMeter,
  ) {
    const metersPerDegLat = 111320.0;
    final lngScale = metersPerDegLat * math.cos(centerLat * math.pi / 180);
    final dLat = -offset.dy / (metersPerDegLat * pixelsPerMeter);
    final dLng = offset.dx / (lngScale * pixelsPerMeter);
    return LatLng(centerLat + dLat, centerLng + dLng);
  }
}
