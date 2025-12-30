import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AroundYouCarsMap extends StatefulWidget {
  const AroundYouCarsMap({super.key});

  @override
  State<AroundYouCarsMap> createState() => _AroundYouCarsMapState();
}

class _AroundYouCarsMapState extends State<AroundYouCarsMap> {
  GoogleMapController? _mapController;
  Position? _currentPosition;

  final Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadCarIcon();
    await _getLocation();
    if (_currentPosition != null) {
      _addNearbyCars();
    }
  }

  // ---------- CAR ICON ----------
  Future<void> _loadCarIcon() async {
    _carIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(10, 10)),
      "assets/images/car.png",
    );
  }

  // ---------- LOCATION ----------
  Future<void> _getLocation() async {
    final permission = await Permission.location.request();
    if (!permission.isGranted) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });
  }

  // ---------- ADD RANDOM CARS ----------
  void _addNearbyCars() {
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
          icon: _carIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: random.nextInt(360).toDouble(),
        ),
      );
    }

    // current location dot
    _markers.add(
      Marker(
        markerId: const MarkerId("me"),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: _currentPosition == null
            ? const Center(child: CircularProgressIndicator())
            : GoogleMap(
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
      ),
    );
  }
}
