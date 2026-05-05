import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../models/result_model.dart';
import '../models/scan_result_model.dart';

class AppState {
  static UserModel user = UserModel.initial();
  static ScanResultModel? lastScanResult;
  static ResultModel? lastResult;
  static bool isFirstLaunch = true;

  static void updateAvatar(AvatarModel avatar) {
    user = user.copyWith(avatar: avatar);
  }

  static void saveResult(ResultModel result) {
    lastResult = result;
    if (result.finalScore > user.bestScore) {
      user = UserModel(
        id: user.id,
        username: user.username,
        level: user.level,
        xp: user.xp + result.xpEarned,
        xpToNextLevel: user.xpToNextLevel,
        totalRuns: user.totalRuns + 1,
        totalCoins: user.totalCoins + result.coinsCollected,
        totalDistanceMeters: user.totalDistanceMeters + result.distanceWalkedMeters,
        bestScore: result.finalScore,
        avatar: user.avatar,
        badges: user.badges,
      );
    } else {
      user = UserModel(
        id: user.id,
        username: user.username,
        level: user.level,
        xp: user.xp + result.xpEarned,
        xpToNextLevel: user.xpToNextLevel,
        totalRuns: user.totalRuns + 1,
        totalCoins: user.totalCoins + result.coinsCollected,
        totalDistanceMeters: user.totalDistanceMeters + result.distanceWalkedMeters,
        bestScore: user.bestScore,
        avatar: user.avatar,
        badges: user.badges,
      );
    }
  }
}
