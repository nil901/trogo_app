import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CommonGoogleMap extends StatelessWidget {
  final LatLng initialLatLng;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final double height;
  final void Function(GoogleMapController)? onMapCreated;
  final bool isFullScreen;
  final Map<String, dynamic>? driverInfo;
  final LatLng? driverLocation;
  final double driverBearing;

  const CommonGoogleMap({
    super.key,
    required this.initialLatLng,
    this.markers = const {},
    this.polylines = const {},
    this.height = 250,
    this.onMapCreated,
    this.isFullScreen = false,
    this.driverInfo,
    this.driverLocation,
    this.driverBearing = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final Set<Marker> allMarkers = Set<Marker>.from(markers);

    /// 🚗 Driver marker
    if (driverLocation != null && driverInfo != null) {
      debugPrint('🚗 Adding driver marker');
      debugPrint(
        'Location: ${driverLocation!.latitude}, ${driverLocation!.longitude}',
      );

      allMarkers.add(
        Marker(
          markerId: const MarkerId('driver_car'),
          position: driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
          rotation: driverBearing,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'Driver: ${driverInfo!['name'] ?? 'Driver'}',
            snippet: 'ETA: ${driverInfo!['eta'] ?? 'Calculating...'}',
          ),
          zIndex: 2,
        ),
      );
    }

    final googleMap = GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialLatLng,
        zoom: 14,
      ),
      markers: allMarkers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
    );

    /// 🔥 Full Screen Map
    if (isFullScreen) {
      return googleMap;
    }

    /// 📦 Normal Map with rounded container
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: googleMap,
      ),
    );
  }
}
