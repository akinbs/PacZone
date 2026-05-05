import 'package:flutter/material.dart';

class LeaderboardItem {
  final int rank;
  final String username;
  final int score;
  final Color avatarColor;
  final int level;
  final bool isCurrentUser;

  const LeaderboardItem({
    required this.rank,
    required this.username,
    required this.score,
    required this.avatarColor,
    required this.level,
    this.isCurrentUser = false,
  });
}

class LeaderboardModel {
  static List<LeaderboardItem> mockWeekly() => const [
        LeaderboardItem(
          rank: 1, username: 'ZoneMaster', score: 28400,
          avatarColor: Color(0xFFFF3366), level: 24,
        ),
        LeaderboardItem(
          rank: 2, username: 'PathRunner99', score: 22100,
          avatarColor: Color(0xFFAA00FF), level: 18,
        ),
        LeaderboardItem(
          rank: 3, username: 'ChompKing', score: 19850,
          avatarColor: Color(0xFFFF9800), level: 15,
        ),
        LeaderboardItem(
          rank: 4, username: 'PixelGhost', score: 17200,
          avatarColor: Color(0xFF00E676), level: 12,
        ),
        LeaderboardItem(
          rank: 5, username: 'ArcadeWalker', score: 15640,
          avatarColor: Color(0xFFB13BFF), level: 11,
        ),
        LeaderboardItem(
          rank: 6, username: 'StreetChomp', score: 14100,
          avatarColor: Color(0xFFFFCC00), level: 9,
        ),
        LeaderboardItem(
          rank: 7, username: 'ChompRunner', score: 12450,
          avatarColor: Color(0xFFB13BFF), level: 7,
          isCurrentUser: true,
        ),
        LeaderboardItem(
          rank: 8, username: 'CityPacer', score: 11200,
          avatarColor: Color(0xFFE91E63), level: 6,
        ),
        LeaderboardItem(
          rank: 9, username: 'MapMuncher', score: 9800,
          avatarColor: Color(0xFF4CAF50), level: 5,
        ),
        LeaderboardItem(
          rank: 10, username: 'OrbSeeker', score: 8600,
          avatarColor: Color(0xFFFF3366), level: 4,
        ),
      ];

  static List<LeaderboardItem> mockAllTime() => const [
        LeaderboardItem(
          rank: 1, username: 'ZoneMaster', score: 142000,
          avatarColor: Color(0xFFFF3366), level: 24,
        ),
        LeaderboardItem(
          rank: 2, username: 'PathRunner99', score: 118500,
          avatarColor: Color(0xFFAA00FF), level: 18,
        ),
        LeaderboardItem(
          rank: 3, username: 'GeoChomp', score: 97200,
          avatarColor: Color(0xFFFF9800), level: 22,
        ),
        LeaderboardItem(
          rank: 4, username: 'ChompKing', score: 85400,
          avatarColor: Color(0xFFFF9800), level: 15,
        ),
        LeaderboardItem(
          rank: 5, username: 'ArcadeWalker', score: 72100,
          avatarColor: Color(0xFFB13BFF), level: 11,
        ),
        LeaderboardItem(
          rank: 14, username: 'ChompRunner', score: 18750,
          avatarColor: Color(0xFFB13BFF), level: 7,
          isCurrentUser: true,
        ),
      ];
}
