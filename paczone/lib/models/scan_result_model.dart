enum ScanStatus { success, partial, failed, gpsWeak, speedTooHigh, noData }

class ScanResultModel {
  final ScanStatus status;
  final int playabilityScore;
  final double playableDistanceMeters;
  final Duration estimatedDuration;
  final String modeType;
  final String? failReason;
  final String? suggestion;
  final bool isEventZone;
  final String? eventName;
  final String? eventBonus;

  const ScanResultModel({
    required this.status,
    required this.playabilityScore,
    required this.playableDistanceMeters,
    required this.estimatedDuration,
    required this.modeType,
    this.failReason,
    this.suggestion,
    this.isEventZone = false,
    this.eventName,
    this.eventBonus,
  });

  static ScanResultModel mockSuccess() => const ScanResultModel(
        status: ScanStatus.success,
        playabilityScore: 82,
        playableDistanceMeters: 420,
        estimatedDuration: Duration(minutes: 2, seconds: 30),
        modeType: 'Classic Run',
      );

  static ScanResultModel mockPartial() => const ScanResultModel(
        status: ScanStatus.partial,
        playabilityScore: 61,
        playableDistanceMeters: 180,
        estimatedDuration: Duration(minutes: 1, seconds: 15),
        modeType: 'Short Run',
        failReason: '150 m çevrende sınırlı yaya yolu bulundu.',
      );

  static ScanResultModel mockFailed() => const ScanResultModel(
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
      );

  static ScanResultModel mockGpsWeak() => const ScanResultModel(
        status: ScanStatus.gpsWeak,
        playabilityScore: 0,
        playableDistanceMeters: 0,
        estimatedDuration: Duration.zero,
        modeType: '',
        failReason: 'Konum doğruluğu düşük.',
        suggestion: 'Açık alanda birkaç saniye bekleyip tekrar deneyin.',
      );

  static ScanResultModel mockSpeedTooHigh() => const ScanResultModel(
        status: ScanStatus.speedTooHigh,
        playabilityScore: 0,
        playableDistanceMeters: 0,
        estimatedDuration: Duration.zero,
        modeType: '',
        failReason: 'Çok hızlı hareket ediyorsun.',
        suggestion: 'PacZone yürüyüş hızında oynanabilir. Dur ve tekrar tara.',
      );

  static ScanResultModel mockNoData() => const ScanResultModel(
        status: ScanStatus.noData,
        playabilityScore: 0,
        playableDistanceMeters: 0,
        estimatedDuration: Duration.zero,
        modeType: '',
        failReason: 'Konum verisi alınamadı.',
        suggestion: 'İnternet bağlantınızı ve GPS ayarlarını kontrol edin.',
      );

  static ScanResultModel mockEventZone() => const ScanResultModel(
        status: ScanStatus.success,
        playabilityScore: 94,
        playableDistanceMeters: 680,
        estimatedDuration: Duration(minutes: 3, seconds: 45),
        modeType: 'SpeedRun',
        isEventZone: true,
        eventName: 'Campus Rush',
        eventBonus: '2x XP Aktif',
      );
}
