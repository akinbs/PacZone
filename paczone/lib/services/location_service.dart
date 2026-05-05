import '../models/location_model.dart';

abstract class LocationService {
  Future<LocationServiceResult> checkAndRequestPermission();
  Future<LocationData?> getCurrentLocation();
  Stream<LocationData> get locationStream;
  void startTracking();
  void stopTracking();
  void dispose();
}
