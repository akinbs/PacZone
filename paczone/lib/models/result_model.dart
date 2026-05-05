class ResultModel {
  final int finalScore;
  final int coinsCollected;
  final double distanceWalkedMeters;
  final Duration duration;
  final int maxCombo;
  final int previousBestScore;
  final int rank;
  final int xpEarned;
  final bool isNewRecord;

  const ResultModel({
    required this.finalScore,
    required this.coinsCollected,
    required this.distanceWalkedMeters,
    required this.duration,
    required this.maxCombo,
    required this.previousBestScore,
    required this.rank,
    required this.xpEarned,
    required this.isNewRecord,
  });

  static ResultModel mock({int score = 12450}) => ResultModel(
        finalScore: score,
        coinsCollected: 47,
        distanceWalkedMeters: 380,
        duration: const Duration(minutes: 2, seconds: 12),
        maxCombo: 8,
        previousBestScore: 10200,
        rank: 7,
        xpEarned: 340,
        isNewRecord: score > 10200,
      );
}
