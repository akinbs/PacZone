import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';

class RealMapView extends StatefulWidget {
  final LocationData? location;
  final bool scanMode;
  final VoidCallback? onMapReady;

  const RealMapView({
    super.key,
    this.location,
    this.scanMode = false,
    this.onMapReady,
  });

  @override
  State<RealMapView> createState() => _RealMapViewState();
}

class _RealMapViewState extends State<RealMapView> {
  final MapController _mapController = MapController();

  LatLng get _center {
    final loc = widget.location;
    return loc != null
        ? LatLng(loc.latitude, loc.longitude)
        : const LatLng(41.0082, 28.9784); // Istanbul fallback
  }

  @override
  void didUpdateWidget(RealMapView old) {
    super.didUpdateWidget(old);
    final loc = widget.location;
    if (loc != null && loc != old.location) {
      _mapController.move(LatLng(loc.latitude, loc.longitude), 17.0);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 17.0,
        onMapReady: () => widget.onMapReady?.call(),
      ),
      children: [
        TileLayer(
          // Carto Dark Matter — OSM tabanlı, ücretsiz, key gerektirmez
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.paczone',
          retinaMode: RetinaMode.isHighDensity(context),
        ),
      ],
    );
  }
}
