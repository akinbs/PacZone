import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationController extends ChangeNotifier {
  final LocationService _service;

  LocationState state = LocationState.initial;
  LocationData? location;
  StreamSubscription<LocationData>? _sub;

  LocationController({required LocationService service}) : _service = service;

  bool get isReady =>
      state == LocationState.locationReady || state == LocationState.locationWeak;

  bool get isLoading =>
      state == LocationState.initial ||
      state == LocationState.checkingPermission ||
      state == LocationState.permissionGranted ||
      state == LocationState.loadingLocation;

  Future<void> initialize() async {
    if (state != LocationState.initial && state != LocationState.permissionDenied) return;

    state = LocationState.checkingPermission;
    notifyListeners();

    final result = await _service.checkAndRequestPermission();

    switch (result) {
      case LocationServiceResult.serviceDisabled:
        state = LocationState.serviceDisabled;
        notifyListeners();
        return;
      case LocationServiceResult.permissionDenied:
        state = LocationState.permissionDenied;
        notifyListeners();
        return;
      case LocationServiceResult.permissionDeniedForever:
        state = LocationState.permissionDeniedForever;
        notifyListeners();
        return;
      case LocationServiceResult.granted:
        break;
    }

    state = LocationState.permissionGranted;
    notifyListeners();

    state = LocationState.loadingLocation;
    notifyListeners();

    final loc = await _service.getCurrentLocation();
    if (loc == null) {
      state = LocationState.locationError;
      notifyListeners();
      return;
    }

    location = loc;
    state = loc.isWeak ? LocationState.locationWeak : LocationState.locationReady;
    notifyListeners();

    _service.startTracking();
    _sub = _service.locationStream.listen((data) {
      location = data;
      if (isReady || state == LocationState.locationWeak) {
        state = data.isWeak ? LocationState.locationWeak : LocationState.locationReady;
        notifyListeners();
      }
    });
  }

  Future<void> retry() async {
    state = LocationState.initial;
    notifyListeners();
    await initialize();
  }

  Future<void> openAppSettings() => ph.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
