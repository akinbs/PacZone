import 'package:flutter/material.dart';

enum CoinType { normal, power }

class CoinModel {
  final String id;
  final Offset position;
  final CoinType type;
  final int points;
  bool collected;

  CoinModel({
    required this.id,
    required this.position,
    required this.type,
    required this.points,
    this.collected = false,
  });
}

class EnemyModel {
  final String id;
  final Color color;
  Offset position;
  Offset velocity;

  EnemyModel({
    required this.id,
    required this.color,
    required this.position,
    required this.velocity,
  });
}

// Combo multiplier state
class ComboState {
  final int count;
  final DateTime? lastCollectedAt;

  const ComboState({this.count = 0, this.lastCollectedAt});

  static const empty = ComboState();

  ComboState increment() =>
      ComboState(count: count + 1, lastCollectedAt: DateTime.now());

  ComboState reset() => const ComboState();

  bool get isExpired {
    if (lastCollectedAt == null) return true;
    return DateTime.now().difference(lastCollectedAt!).inSeconds > 4;
  }

  int get multiplier => count >= 8 ? 3 : count >= 4 ? 2 : 1;

  String get label => count >= 8 ? '×3' : count >= 4 ? '×2' : '';
}

class GameSessionModel {
  final String sessionId;
  final String zoneId;
  final DateTime startTime;
  final Duration maxDuration;
  final int scorePerCoin;
  final int scorePerPowerCoin;

  const GameSessionModel({
    required this.sessionId,
    required this.zoneId,
    required this.startTime,
    required this.maxDuration,
    required this.scorePerCoin,
    required this.scorePerPowerCoin,
  });

  factory GameSessionModel.mock() => GameSessionModel(
        sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
        zoneId: 'zone_001',
        startTime: DateTime.now(),
        maxDuration: const Duration(minutes: 2, seconds: 30),
        scorePerCoin: 100,
        scorePerPowerCoin: 500,
      );
}
