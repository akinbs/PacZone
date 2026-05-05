import 'dart:convert';
import 'package:http/http.dart' as http;
import 'scan_service.dart';
import 'zone_analyzer.dart';
import '../models/scan_result_model.dart';
import '../models/zone_models.dart';

/// Backend scan service.
///
/// POST /dynamic-zones/analyze
///   Input  — user's GPS position; backend treats it as the center of a
///            150 m × 150 m square scan area, fetches OSM data within that
///            boundary, and classifies objects:
///              buildings / impassable  →  walls
///              footways / pedestrian   →  playable corridors
///              vehicle roads           →  blocked / risk
///   Output — { status, playabilityScore, zone: { boundary, playablePaths,
///              buildings, blockedRoads, coins, enemies, playerStartPoint,
///              estimatedDistanceMeters, estimatedDurationSeconds, modeType },
///              reason?, suggestion? }
///
/// The backend drives the scan decision (success/partial/failed).
/// ZoneAnalyzer generates the visual game data on the client side until
/// the backend returns full path geometry.
class ApiScanService implements ScanService {
  final String baseUrl;
  final http.Client _client;

  ApiScanService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<ZoneAnalysisResult> analyze(LocationInput input) async {
    try {
      final body = jsonEncode({
        'latitude': input.lat,
        'longitude': input.lng,
        'accuracy': input.accuracyMeters,
        'heading': input.headingDegrees,
        'speed': input.speedKmh / 3.6, // km/h → m/s (backend expects m/s)
        'timestamp': input.timestamp.toUtc().toIso8601String(),
        'scanSizeMeters': 150, // side length of the square scan area in metres
      });

      final response = await _client
          .post(
            Uri.parse('$baseUrl/dynamic-zones/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return _parseSuccess(input, jsonDecode(response.body) as Map<String, dynamic>);
      }
      return _networkError();
    } on Exception {
      return _networkError();
    }
  }

  ZoneAnalysisResult _parseSuccess(LocationInput input, Map<String, dynamic> json) {
    final status = _toScanStatus(json['status'] as String? ?? 'noData');
    final score = (json['playabilityScore'] as num?)?.toInt() ?? 0;
    final zoneJson = json['zone'] as Map<String, dynamic>?;

    final scanResult = ScanResultModel(
      status: status,
      playabilityScore: score,
      playableDistanceMeters:
          (zoneJson?['estimatedDistanceMeters'] as num?)?.toDouble() ?? 0,
      estimatedDuration: Duration(
        seconds: (zoneJson?['estimatedDurationSeconds'] as num?)?.toInt() ?? 0,
      ),
      modeType: zoneJson?['modeType'] as String? ?? '',
      failReason: json['reason'] as String?,
      suggestion: json['suggestion'] as String?,
    );

    // For playable states, generate visual game data from the local analyzer.
    // The backend drives the scan decision; ZoneAnalyzer drives the game visuals.
    DynamicZoneData? zoneData;
    if (status == ScanStatus.success || status == ScanStatus.partial) {
      final scenarioIndex = status == ScanStatus.partial ? 2 : 0;
      zoneData = ZoneAnalyzer.resultForScenario(scenarioIndex).zoneData;
    }

    return ZoneAnalysisResult(scanResult: scanResult, zoneData: zoneData);
  }

  ZoneAnalysisResult _networkError() {
    return const ZoneAnalysisResult(
      scanResult: ScanResultModel(
        status: ScanStatus.noData,
        playabilityScore: 0,
        playableDistanceMeters: 0,
        estimatedDuration: Duration.zero,
        modeType: '',
        failReason: 'Alan analiz edilemedi.',
        suggestion: 'Biraz sonra tekrar deneyin.',
      ),
    );
  }

  static ScanStatus _toScanStatus(String raw) => switch (raw) {
        'success'      => ScanStatus.success,
        'partial'      => ScanStatus.partial,
        'failed'       => ScanStatus.failed,
        'gpsWeak'      => ScanStatus.gpsWeak,
        'speedTooHigh' => ScanStatus.speedTooHigh,
        _              => ScanStatus.noData,
      };
}
