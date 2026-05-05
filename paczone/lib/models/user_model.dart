import 'avatar_model.dart';

class UserModel {
  final String id;
  final String username;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int totalRuns;
  final int totalCoins;
  final double totalDistanceMeters;
  final int bestScore;
  final AvatarModel avatar;
  final List<String> badges;

  const UserModel({
    required this.id,
    required this.username,
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.totalRuns,
    required this.totalCoins,
    required this.totalDistanceMeters,
    required this.bestScore,
    required this.avatar,
    required this.badges,
  });

  factory UserModel.initial() => UserModel(
        id: 'user_001',
        username: 'ChompRunner',
        level: 7,
        xp: 3400,
        xpToNextLevel: 5000,
        totalRuns: 23,
        totalCoins: 1840,
        totalDistanceMeters: 14200,
        bestScore: 18750,
        avatar: AvatarModel.initial(),
        badges: ['first_run', 'coin_collector', 'explorer'],
      );

  UserModel copyWith({AvatarModel? avatar, String? username}) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      level: level,
      xp: xp,
      xpToNextLevel: xpToNextLevel,
      totalRuns: totalRuns,
      totalCoins: totalCoins,
      totalDistanceMeters: totalDistanceMeters,
      bestScore: bestScore,
      avatar: avatar ?? this.avatar,
      badges: badges,
    );
  }
}
