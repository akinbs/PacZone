import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import '../models/location_model.dart';

class RealLocationService implements LocationService {
  final _controller = StreamController<LocationData>.broadcast();
  StreamSubscription<Position>? _positionSub;

  @override
  Future<LocationServiceResult> checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationServiceResult.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationServiceResult.permissionDenied;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationServiceResult.permissionDeniedForever;
    }
    return LocationServiceResult.granted;
  }

  @override
  Future<LocationData?> getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _fromPosition(pos);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LocationData> get locationStream => _controller.stream;

  @override
  void startTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) => _controller.add(_fromPosition(pos)));
  }

  @override
  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    stopTracking();
    _controller.close();
  }

  LocationData _fromPosition(Position pos) => LocationData(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        heading: pos.heading,
        speed: pos.speed,
        timestamp: pos.timestamp,
        isMocked: pos.isMocked,
      );
}
