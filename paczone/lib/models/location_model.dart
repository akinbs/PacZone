enum LocationState {
  initial,
  checkingPermission,
  permissionGranted,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  loadingLocation,
  locationReady,
  locationWeak,
  locationError,
}

enum LocationServiceResult {
  granted,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
}

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? heading;
  final double? speed; // m/s from device
  final DateTime timestamp;
  final bool isMocked;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.heading,
    this.speed,
    required this.timestamp,
    this.isMocked = false,
  });

  double get speedKmh => (speed ?? 0) * 3.6;

  // accuracy > 20 m = location too imprecise for safe PacZone
  bool get isWeak => accuracy > 20;
}
