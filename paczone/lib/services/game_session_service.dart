import '../models/zone_models.dart';

// Tracks an active game session and validates it for anti-cheat (spec §18, §19)
class GameSessionService {
  final String sessionId;
  final String zoneId;
  final DateTime startTime;
  final Duration maxDuration;

  final List<_CoinEvent> _coinEvents = [];
  final List<_SpeedSample> _speedSamples = [];

  bool _suspicious = false;
  String? _suspicionReason;
  int _rawScore = 0;
  int _coinsCollected = 0;

  GameSessionService({
    required this.sessionId,
    required this.zoneId,
    required this.maxDuration,
  }) : startTime = DateTime.now();

  factory GameSessionService.fromZone(DynamicZoneData zone) =>
      GameSessionService(
        sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
        zoneId: zone.zoneId,
        maxDuration: zone.estimatedDuration,
      );

  // ─── Events ───────────────────────────────────────────────────────────────

  void recordCoinCollected(String coinId, int points) {
    _coinEvents.add(_CoinEvent(
      coinId: coinId,
      timestamp: DateTime.now(),
      points: points,
    ));
    _rawScore += points;
    _coinsCollected++;
    _checkCollectionRate();
  }

  void recordSpeedSample(double kmh) {
    _speedSamples.add(_SpeedSample(kmh: kmh, timestamp: DateTime.now()));
    // Spec §19.3 — flag if speed exceeds 18 km/s during session
    if (kmh > 18 && !_suspicious) {
      _suspicious = true;
      _suspicionReason = 'Araç hızı tespit edildi (${kmh.toStringAsFixed(1)} km/s).';
    }
  }

  // ─── Anti-cheat checks (spec §19) ────────────────────────────────────────

  // Flag if 5 coins collected in under 1.5 seconds (spec §19.2)
  void _checkCollectionRate() {
    if (_coinEvents.length < 5) return;
    final recent = _coinEvents.reversed.take(5).toList();
    final span = recent.first.timestamp
        .difference(recent.last.timestamp)
        .abs()
        .inMilliseconds;
    if (span < 1500 && !_suspicious) {
      _suspicious = true;
      _suspicionReason = 'Anormal coin toplama hızı tespit edildi.';
    }
  }

  // ─── Validation & Final Score ─────────────────────────────────────────────

  SessionValidation validate() {
    final elapsed = DateTime.now().difference(startTime);

    // Must have played at least 10 seconds with any score
    if (elapsed.inSeconds < 10 && _rawScore > 0) {
      return SessionValidation(
        valid: false,
        suspicionReason: 'Çok kısa süre oynanmış.',
        finalScore: 0,
        coinsCollected: _coinsCollected,
        distanceMeters: _estimateDistance(elapsed),
        duration: elapsed,
      );
    }

    if (_suspicious) {
      return SessionValidation(
        valid: false,
        suspicionReason: _suspicionReason,
        finalScore: (_rawScore * 0.5).round(),
        coinsCollected: _coinsCollected,
        distanceMeters: _estimateDistance(elapsed),
        duration: elapsed,
      );
    }

    return SessionValidation(
      valid: true,
      finalScore: _rawScore,
      coinsCollected: _coinsCollected,
      distanceMeters: _estimateDistance(elapsed),
      duration: elapsed,
    );
  }

  // Rough walking distance estimate: ~4 km/h average
  double _estimateDistance(Duration elapsed) =>
      (elapsed.inSeconds * 4000.0 / 3600.0).clamp(0, 5000);

  // ─── Getters ──────────────────────────────────────────────────────────────

  int get rawScore => _rawScore;
  int get coinsCollected => _coinsCollected;
  bool get isSuspicious => _suspicious;

  double get averageSpeed => _speedSamples.isEmpty
      ? 0
      : _speedSamples.map((s) => s.kmh).reduce((a, b) => a + b) /
          _speedSamples.length;
}

class SessionValidation {
  final bool valid;
  final String? suspicionReason;
  final int finalScore;
  final int coinsCollected;
  final double distanceMeters;
  final Duration duration;

  const SessionValidation({
    required this.valid,
    this.suspicionReason,
    required this.finalScore,
    required this.coinsCollected,
    required this.distanceMeters,
    required this.duration,
  });
}

class _CoinEvent {
  final String coinId;
  final DateTime timestamp;
  final int points;
  const _CoinEvent({required this.coinId, required this.timestamp, required this.points});
}

class _SpeedSample {
  final double kmh;
  final DateTime timestamp;
  const _SpeedSample({required this.kmh, required this.timestamp});
}
