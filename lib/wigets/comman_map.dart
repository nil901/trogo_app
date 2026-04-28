import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1f1f1f"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1f1f1f"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#242424"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1c1c1c"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#2a2a2a"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#c9c9c9"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2b2b2b"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#101010"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#5f5f5f"}]}
]
''';

const String _lightPreviewMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f6f8fc"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#aab4c3"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f6f8fc"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#e9eef7"}]},
  {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#eef4ff"}]},
  {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

class CommonGoogleMap extends StatelessWidget {
  final LatLng initialLatLng;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final double height;
  final double initialZoom;
  final EdgeInsets mapPadding;
  final bool useDarkStyle;
  final MinMaxZoomPreference? minMaxZoomPreference;
  final void Function(GoogleMapController)? onMapCreated;
  final bool isFullScreen;
  final Map<String, dynamic>? driverInfo;
  final LatLng? driverLocation;
  final double driverBearing;
  final bool useLightPreviewStyle;
  final bool trafficEnabled;
  final bool buildingsEnabled;

  const CommonGoogleMap({
    super.key,
    required this.initialLatLng,
    this.markers = const {},
    this.polylines = const {},
    this.circles = const {},
    this.height = 250,
    this.initialZoom = 14,
    this.mapPadding = EdgeInsets.zero,
    this.useDarkStyle = false,
    this.minMaxZoomPreference,
    this.onMapCreated,
    this.isFullScreen = false,
    this.driverInfo,
    this.driverLocation,
    this.driverBearing = 0.0,
    this.useLightPreviewStyle = false,
    this.trafficEnabled = true,
    this.buildingsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Set<Marker> allMarkers = Set<Marker>.from(markers);
    final Set<Polyline> allPolylines = Set<Polyline>.from(polylines);
    final Set<Circle> allCircles = Set<Circle>.from(circles);

    final googleMap = GoogleMap(
      onMapCreated: (controller) async {
        if (useDarkStyle) {
          await controller.setMapStyle(_darkMapStyle);
        } else if (useLightPreviewStyle) {
          await controller.setMapStyle(_lightPreviewMapStyle);
        }
        onMapCreated?.call(controller);
      },
      initialCameraPosition: CameraPosition(
        target: initialLatLng,
        zoom: initialZoom,
      ),
      minMaxZoomPreference:
          minMaxZoomPreference ?? MinMaxZoomPreference.unbounded,
      padding: mapPadding,
      markers: allMarkers,
      polylines: allPolylines,
      circles: allCircles,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
      buildingsEnabled: buildingsEnabled,
      trafficEnabled: trafficEnabled,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
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
