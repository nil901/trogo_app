import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';

class AroundYouCarsMap extends StatefulWidget {
  const AroundYouCarsMap({super.key});

  @override
  State<AroundYouCarsMap> createState() => _AroundYouCarsMapState();
}

class _AroundYouCarsMapState extends State<AroundYouCarsMap> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  bool _isLoading = true;

  final Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadCarIcon();
    if (!mounted) return;
    await _getLocation();
    if (!mounted) return;
    if (_currentPosition != null) {
      await _fetchNearbyDrivers();  // Fetch REAL drivers from API
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------- CAR ICON (Custom painted) ----------
  Future<void> _loadCarIcon() async {
    try {
      const size = 40.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = const Offset(size / 2, size / 2);

      // Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(center + const Offset(0, 4), 7, shadowPaint);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.55);
      canvas.translate(-center.dx, -center.dy);

      // Car body (white)
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 12, height: 22),
        const Radius.circular(4),
      );
      canvas.drawRRect(body, Paint()..color = Colors.white);
      canvas.drawRRect(
        body,
        Paint()
          ..color = const Color(0xFF1F2937)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      // Car cabin
      final cabin = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 7, height: 9),
        const Radius.circular(2),
      );
      canvas.drawRRect(cabin, Paint()..color = const Color(0xFF111827));

      // Lights
      canvas.drawCircle(
        center + const Offset(0, -9),
        1.6,
        Paint()..color = const Color(0xFFEF4444),
      );
      canvas.drawCircle(
        center + const Offset(0, 9),
        1.6,
        Paint()..color = const Color(0xFFEF4444),
      );

      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        _carIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('Car icon failed: $e');
      _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  // ---------- LOCATION ----------
  Future<void> _getLocation() async {
    final permission = await Permission.location.request();
    if (!permission.isGranted) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Failed to get location: $e');
    }
  }

  // ---------- FETCH REAL NEARBY DRIVERS FROM API ----------
  Future<void> _fetchNearbyDrivers() async {
    try {
      final response = await ApiService().getRequest(nearbyDriversUrl);
      final responseData = response?.data;

      if (responseData is Map) {
        final rawDrivers = responseData['drivers'];
        if (rawDrivers is List) {
          _nearbyDrivers = rawDrivers
              .whereType<Map>()
              .map((driver) => Map<String, dynamic>.from(driver))
              .toList();
          
          if (mounted) {
            setState(() {});
          }
          _addNearbyDriverMarkers();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch nearby drivers: $e');
      // Fallback to random cars if API fails
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _addRandomCars();
    }
  }

  // ---------- ADD REAL DRIVERS AS MARKERS ----------
  void _addNearbyDriverMarkers() {
    if (_currentPosition == null || _carIcon == null) return;

    _markers.clear();

    // Add your location marker
    _markers.add(
      Marker(
        markerId: const MarkerId("me"),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Add nearby drivers (max 6)
    for (final driver in _nearbyDrivers.take(6)) {
      final driverId = driver['_id']?.toString() ?? 'driver_${_nearbyDrivers.indexOf(driver)}';
      final latLng = _extractDriverLatLng(driver);
      
      if (latLng != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('nearby_driver_$driverId'),
            position: latLng,
            icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            anchor: const Offset(0.5, 0.5),
            flat: true,
            rotation: (driverId.hashCode % 180).toDouble(),
            infoWindow: InfoWindow(
              title: driver['name']?.toString() ?? 'Driver',
              snippet: driver['vehicle']?.toString() ?? 'Vehicle',
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  // ---------- EXTRACT COORDINATES FROM API RESPONSE ----------
  LatLng? _extractDriverLatLng(Map<String, dynamic> driver) {
    try {
      final location = driver['location'];
      if (location is! Map) return null;

      final coordinates = location['coordinates'];
      if (coordinates is! List || coordinates.length < 2) return null;

      final lng = (coordinates[0] as num?)?.toDouble();
      final lat = (coordinates[1] as num?)?.toDouble();
      
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (e) {
      debugPrint('Failed to extract driver location: $e');
      return null;
    }
  }

  // ---------- FALLBACK: ADD RANDOM CARS IF API FAILS ----------
  void _addRandomCars() {
    if (_currentPosition == null || _carIcon == null) return;

    final random = Random();

    for (int i = 0; i < 6; i++) {
      final latOffset = (random.nextDouble() - 0.5) / 500;
      final lngOffset = (random.nextDouble() - 0.5) / 500;

      _markers.add(
        Marker(
          markerId: MarkerId("car_$i"),
          position: LatLng(
            _currentPosition!.latitude + latOffset,
            _currentPosition!.longitude + lngOffset,
          ),
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 0.5),
          rotation: random.nextInt(360).toDouble(),
        ),
      );
    }

    // Current location dot
    _markers.add(
      Marker(
        markerId: const MarkerId("me"),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: _currentPosition == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    markers: _markers,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  // Show loading indicator while fetching drivers
                  if (_isLoading)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  // Show driver count badge
                  if (!_isLoading && _nearbyDrivers.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_nearbyDrivers.length} drivers nearby',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}