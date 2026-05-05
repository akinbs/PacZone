import 'dart:async';
import 'dart:math';
import 'location_service.dart';
import '../models/location_model.dart';

class MockLocationService implements LocationService {
  final _controller = StreamController<LocationData>.broadcast();
  Timer? _timer;

  @override
  Future<LocationServiceResult> checkAndRequestPermission() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return LocationServiceResult.granted;
  }

  @override
  Future<LocationData?> getCurrentLocation() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _mockLocation();
  }

  @override
  Stream<LocationData> get locationStream => _controller.stream;

  @override
  void startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _controller.add(_mockLocation());
    });
  }

  @override
  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopTracking();
    _controller.close();
  }

  LocationData _mockLocation() {
    final rng = Random();
    return LocationData(
      latitude: 41.0082 + rng.nextDouble() * 0.0001 - 0.00005,
      longitude: 28.9784 + rng.nextDouble() * 0.0001 - 0.00005,
      accuracy: 4.5 + rng.nextDouble() * 2,
      heading: 45.0,
      speed: 0.9, // ~3.2 km/h
      timestamp: DateTime.now(),
    );
  }
}
