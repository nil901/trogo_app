import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/wigets/choose_ride.dart';
import 'package:trogo_app/wigets/comman_map.dart';
import 'package:trogo_app/wigets/driver_confirm_booking.dart';
import 'package:trogo_app/wigets/pick_up_loaction.dart';
import 'package:trogo_app/wigets/search_drop_loaction.dart';

enum RideState {
  searchDestination,
  pickupDrop,
  chooseRide,
  driverConnecting,
  payment,
  editPickup,
  editDropoff,
}

enum TransportCameraMode {
  overview,
  approachingPickup,
  tripRunning,
  nearingDrop,
}

class TransportRideHomePage extends ConsumerStatefulWidget {
  final SelectedLocation? currentLocation;
  final Map<String, dynamic>? initialActiveRide;
  final bool restoreToDriverConnecting;

  const TransportRideHomePage({
    super.key,
    this.currentLocation,
    this.initialActiveRide,
    this.restoreToDriverConnecting = false,
  });

  @override
  _TransportRideHomePageState createState() => _TransportRideHomePageState();
}

class _TransportRideHomePageState extends ConsumerState<TransportRideHomePage> {
  RideState currentState = RideState.searchDestination;
  String selectedRide = "Normal";
  String selectedId = "";
  String? selectedDestination;
  String? destinationAddress;
  double? destLatitude;
  double? destLongitude;
  String? destinationName;
  String? selectedVehicleId;
  int? price;
  bool isLoadingFare = false;
  String? _driverOtp;
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _routeCoordinates = [];
  BitmapDescriptor? _driverCarIcon;
  Marker? _driverMarker;
  Timer? _driverMarkerAnimationTimer;
  LatLng? _displayedDriverLocation;
  double _displayedDriverBearing = 0.0;
  TransportCameraMode? _lastCameraMode;
  int? _lastCameraBucket;

  bool _driverMarkerAdded = false;
  Future<void> _loadDriverCarIcon() async {
    if (_driverCarIcon != null) return;

    try {
      _driverCarIcon = await _buildDriverPointerIcon();
    } catch (e) {
      debugPrint('Driver car icon load failed, using default marker: $e');
      _driverCarIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }

    print('ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â Driver car icon loaded');
  }

  Future<Uint8List> _getMarkerBytes(String assetPath, int width) async {
    final byteData = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<BitmapDescriptor> _buildDriverPointerIcon() async {
    const size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.18)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawCircle(center + const Offset(0, 8), 24, shadowPaint);

    final bluePaint =
        Paint()
          ..color = const Color(0xFF1A73E8)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 24, bluePaint);

    final innerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 14, innerPaint);

    final pointerPath =
        Path()
          ..moveTo(center.dx, 10)
          ..lineTo(center.dx - 14, 34)
          ..lineTo(center.dx + 14, 34)
          ..close();
    canvas.drawPath(pointerPath, bluePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static const String GOOGLE_MAPS_API_KEY =
      "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";
  PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_MAPS_API_KEY);

  // Driver State Variables
  Map<String, dynamic>? _driverInfo;
  LatLng? _driverLocation;
  double _driverBearing = 0.0;
  bool _showDriverOnMap = false;
  bool get _useDarkMapPreview =>
      currentState == RideState.pickupDrop ||
      currentState == RideState.chooseRide ||
      currentState == RideState.driverConnecting;
  EdgeInsets get _mapViewportPadding =>
      currentState == RideState.driverConnecting
          ? const EdgeInsets.fromLTRB(40, 110, 40, 360)
          : const EdgeInsets.fromLTRB(24, 90, 24, 220);

  Set<Circle> _mapFocusCircles() {
    final circles = <Circle>{};
    final pickup =
        widget.currentLocation == null
            ? null
            : LatLng(
              widget.currentLocation!.latitude!,
              widget.currentLocation!.longitude!,
            );
    final drop =
        destLatitude == null || destLongitude == null
            ? null
            : LatLng(destLatitude!, destLongitude!);

    LatLng? focusCenter;
    if (currentState == RideState.driverConnecting && _driverLocation != null) {
      focusCenter = _driverLocation;
    } else if (currentState == RideState.chooseRide ||
        currentState == RideState.pickupDrop) {
      focusCenter = pickup;
    } else {
      focusCenter = drop ?? pickup;
    }

    if (focusCenter == null) return circles;

    circles.add(
      Circle(
        circleId: const CircleId('focus_outer'),
        center: focusCenter,
        radius: 85,
        fillColor: const Color(0x332E86FF),
        strokeColor: const Color(0x552E86FF),
        strokeWidth: 1,
      ),
    );
    circles.add(
      Circle(
        circleId: const CircleId('focus_mid'),
        center: focusCenter,
        radius: 42,
        fillColor: const Color(0x553FA0FF),
        strokeColor: const Color(0x663FA0FF),
        strokeWidth: 1,
      ),
    );
    circles.add(
      Circle(
        circleId: const CircleId('focus_core'),
        center: focusCenter,
        radius: 10,
        fillColor: const Color(0xFF2D8CFF),
        strokeColor: Colors.white,
        strokeWidth: 3,
      ),
    );

    return circles;
  }

  void goTo(RideState s) {
    setState(() {
      currentState = s;
    });

    if (s == RideState.pickupDrop ||
        s == RideState.chooseRide ||
        s == RideState.driverConnecting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setupMapAndRoute();
      });
    }
  }

  Future<void> _openDestinationPicker(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationPermissionScreen()),
    );
    if (result != null) {
      setState(() {
        destLatitude = result['latitude'];
        destLongitude = result['longitude'];
        selectedDestination = "Selected Destination";
        destinationAddress =
            "${result['latitude']?.toStringAsFixed(6)}, ${result['longitude']?.toStringAsFixed(6)}";
      });

      Future.delayed(Duration(milliseconds: 300), () {
        goTo(RideState.pickupDrop);
      });
    }
  }

  Future<void> _setupMapAndRoute() async {
    print('ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂºÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Setting up map and route in TransportRideHomePage...');

    // Clear old data
    _markers.clear();
    _polylines.clear();
    _driverPolylines.clear();

    // Default position (Mumbai fallback)
    LatLng defaultPosition = const LatLng(19.0760, 72.8777);

    // ===================== PICKUP MARKER =====================
    if (widget.currentLocation != null) {
      final pickupLatLng = LatLng(
        widget.currentLocation!.latitude!,
        widget.currentLocation!.longitude!,
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );

      defaultPosition = pickupLatLng;
    }

    // ===================== DROP MARKER =====================
    if (destLatitude != null && destLongitude != null) {
      final dropLatLng = LatLng(destLatitude!, destLongitude!);

      _markers.add(
        Marker(
          markerId: const MarkerId('drop'),
          position: dropLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );

      // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âµ Pickup ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ Drop route
      if (widget.currentLocation != null) {
        await _fetchRoutePolyline();
      }
    }

    // ===================== DRIVER MARKER =====================
    await _fitInitialTripView(defaultPosition);
  }

  Future<void> _fetchRoutePolyline() async {
    if (widget.currentLocation == null ||
        destLatitude == null ||
        destLongitude == null)
      return;

    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(
            widget.currentLocation!.latitude!,
            widget.currentLocation!.longitude!,
          ),
          destination: PointLatLng(destLatitude!, destLongitude!),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        _routeCoordinates.clear();

        for (var point in result.points) {
          _routeCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        setState(() {
          _polylines.clear();
          _polylines.addAll(
            _buildNavigationPolylines('route', _routeCoordinates),
          );
        });
      }
    } catch (e) {
      print('ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¥ Error fetching route: $e');
    }
  }

  Set<Polyline> _driverPolylines = {};

  double _bottomSheetHeight = 320;

  double _distanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180.0;
    final dLng = (b.longitude - a.longitude) * pi / 180.0;
    final lat1 = a.latitude * pi / 180.0;
    final lat2 = b.latitude * pi / 180.0;
    final hav =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
    return 2 * earthRadiusKm * asin(sqrt(hav));
  }

  LatLng _initialMapTarget() {
    final pickup =
        widget.currentLocation == null
            ? null
            : LatLng(
              widget.currentLocation!.latitude!,
              widget.currentLocation!.longitude!,
            );
    final drop =
        destLatitude == null || destLongitude == null
            ? null
            : LatLng(destLatitude!, destLongitude!);

    if (pickup != null && drop != null) {
      return LatLng(
        (pickup.latitude + drop.latitude) / 2,
        (pickup.longitude + drop.longitude) / 2,
      );
    }

    return pickup ?? const LatLng(19.0760, 72.8777);
  }

  double _initialMapZoom() {
    final pickup =
        widget.currentLocation == null
            ? null
            : LatLng(
              widget.currentLocation!.latitude!,
              widget.currentLocation!.longitude!,
            );
    final drop =
        destLatitude == null || destLongitude == null
            ? null
            : LatLng(destLatitude!, destLongitude!);

    if (pickup == null || drop == null) return 16.0;

    final distanceKm = _distanceKm(pickup, drop);
    if (distanceKm <= 0.15) return 19.0;
    if (distanceKm <= 0.3) return 18.6;
    if (distanceKm <= 0.6) return 18.1;
    if (distanceKm <= 1.0) return 17.4;
    return 16.2;
  }

  MinMaxZoomPreference? _mapZoomLock(double initialZoom) {
    if (currentState == RideState.pickupDrop ||
        currentState == RideState.chooseRide) {
      return MinMaxZoomPreference(initialZoom, 20.0);
    }
    return null;
  }

  LatLng _routeFocusTarget(LatLng pickup, LatLng drop) {
    final points = <LatLng>[
      pickup,
      drop,
      ..._routeCoordinates,
    ];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _routeFocusZoom(LatLng pickup, LatLng drop) {
    final points = <LatLng>[
      pickup,
      drop,
      ..._routeCoordinates,
    ];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final maxSpan = max(maxLat - minLat, maxLng - minLng);
    if (maxSpan <= 0.0012) return 19.0;
    if (maxSpan <= 0.0025) return 18.6;
    if (maxSpan <= 0.0040) return 18.1;
    if (maxSpan <= 0.0065) return 17.6;
    if (maxSpan <= 0.0100) return 17.1;
    return 16.4;
  }

  Future<void> _fitInitialTripView(LatLng defaultPosition) async {
    if (!_mapController.isCompleted) return;

    final points = <LatLng>[];
    if (widget.currentLocation != null) {
      points.add(
        LatLng(
          widget.currentLocation!.latitude!,
          widget.currentLocation!.longitude!,
        ),
      );
    }
    if (destLatitude != null && destLongitude != null) {
      points.add(LatLng(destLatitude!, destLongitude!));
    }

    final controller = await _mapController.future;

    if (points.isEmpty) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: defaultPosition, zoom: 14.5),
        ),
      );
      return;
    }

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 16.0),
        ),
      );
      return;
    }

    final pickup = points.first;
    final drop = points.last;
    final distanceKm = _distanceKm(pickup, drop);
    final center = _routeCoordinates.isNotEmpty
        ? _routeFocusTarget(pickup, drop)
        : LatLng(
            (pickup.latitude + drop.latitude) / 2,
            (pickup.longitude + drop.longitude) / 2,
          );

    if (currentState == RideState.pickupDrop ||
        currentState == RideState.chooseRide) {
      final lockedZoom = _routeCoordinates.isNotEmpty
          ? _routeFocusZoom(pickup, drop)
          : distanceKm <= 0.15
              ? 19.0
              : distanceKm <= 0.3
                  ? 18.6
                  : distanceKm <= 0.6
                      ? 18.1
                      : distanceKm <= 1.0
                          ? 17.4
                          : 16.2;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: lockedZoom),
        ),
      );
      Future.delayed(const Duration(milliseconds: 220), () async {
        if (!mounted || !_mapController.isCompleted) return;
        final secondController = await _mapController.future;
        await secondController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: center, zoom: lockedZoom),
          ),
        );
      });
      return;
    }

    if (distanceKm <= 0.2) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: 18.4),
        ),
      );
      return;
    }

    if (distanceKm <= 0.5) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: 17.9),
        ),
      );
      return;
    }

    if (distanceKm <= 0.8) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: 17.4),
        ),
      );
      return;
    }

    if (distanceKm <= 1.2) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: 16.9),
        ),
      );
      return;
    }

    await _zoomToFitAllPoints(pickup: pickup, drop: drop);
  }

  // --- Driver Update Handler ---
  void _onDriverUpdate(
    Map<String, dynamic> driverInfo,
    LatLng location,
    double bearing,
    String? otp,
    List<LatLng>? routePath,
  ) async {
    await _loadDriverCarIcon();

    _driverInfo = driverInfo;
    _driverLocation = location;
    _driverBearing = bearing;
    _driverOtp = otp;
    _showDriverOnMap = true;

    if (!_driverMarkerAdded) {
      _addDriverMarker(location, bearing);
      _driverMarkerAdded = true;
    } else {
      _animateDriverMarker(location, bearing);
    }

    if (routePath != null && routePath.isNotEmpty) {
      _setDriverRoutePolyline(routePath);
    } else {
      _drawDriverToPickupPolylineOnce();
    }

    _fitMapToRide(routePath: routePath);
  }

  void _addDriverMarker(LatLng location, double bearing) {
    _displayedDriverLocation = location;
    _displayedDriverBearing = bearing;
    _driverMarker = Marker(
      markerId: const MarkerId('driver_car'),
      position: location,
      icon: _driverCarIcon!, // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¥ CAR ICON
      rotation: bearing,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      zIndex: 10,
      infoWindow: InfoWindow(
        title: 'Driver: ${_driverInfo?['name'] ?? ''}',
        snippet: _driverOtp != null ? 'startOtp: $_driverOtp' : '',
      ),
    );

    setState(() {
      _markers.add(_driverMarker!);
    });

    _openDriverInfoWindow();
  }

  void _updateDriverMarker(LatLng newLocation, double bearing) {
    _displayedDriverLocation = newLocation;
    _displayedDriverBearing = bearing;
    _driverMarker = _driverMarker!.copyWith(
      positionParam: newLocation,
      rotationParam: bearing,
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver_car');
      _markers.add(_driverMarker!);
    });
  }

  void _animateDriverMarker(LatLng targetLocation, double targetBearing) {
    _driverMarkerAnimationTimer?.cancel();

    final startLocation = _displayedDriverLocation ?? targetLocation;
    final startBearing = _displayedDriverBearing;
    const totalSteps = 14;
    int step = 0;

    _driverMarkerAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 90),
      (timer) {
        step++;
        final t = step / totalSteps;
        final lat = startLocation.latitude +
            (targetLocation.latitude - startLocation.latitude) * t;
        final lng = startLocation.longitude +
            (targetLocation.longitude - startLocation.longitude) * t;
        final bearing = startBearing + (targetBearing - startBearing) * t;

        _updateDriverMarker(LatLng(lat, lng), bearing);

        if (step >= totalSteps) {
          timer.cancel();
          _displayedDriverLocation = targetLocation;
          _displayedDriverBearing = targetBearing;
        }
      },
    );
  }

  Future<void> _openDriverInfoWindow() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;

    controller.showMarkerInfoWindow(const MarkerId('driver_car'));
  }

  bool _driverPolylineDrawn = false;
  Future<void> _zoomUberStyle() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;

    final List<LatLng> points = [];

    // Pickup
    if (widget.currentLocation != null) {
      points.add(
        LatLng(
          widget.currentLocation!.latitude!,
          widget.currentLocation!.longitude!,
        ),
      );
    }

    // Destination
    if (destLatitude != null && destLongitude != null) {
      points.add(LatLng(destLatitude!, destLongitude!));
    }

    // Driver
    if (_driverLocation != null) {
      points.add(_driverLocation!);
    }

    if (points.isEmpty) return;

    // Single point ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ zoom in
    if (points.length == 1) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 16),
        ),
      );
      return;
    }

    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final p in points) {
      south = south < p.latitude ? south : p.latitude;
      north = north > p.latitude ? north : p.latitude;
      west = west < p.longitude ? west : p.longitude;
      east = east > p.longitude ? east : p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¥ Uber-style padding
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        100 + _bottomSheetHeight, // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¹Ãƒâ€¦Ã¢â‚¬Å“ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â  MAGIC LINE
      ),
    );
  }

  Future<void> _zoomUberCentered() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;

    final List<LatLng> points = [];

    if (widget.currentLocation != null) {
      points.add(
        LatLng(
          widget.currentLocation!.latitude!,
          widget.currentLocation!.longitude!,
        ),
      );
    }

    if (destLatitude != null && destLongitude != null) {
      points.add(LatLng(destLatitude!, destLongitude!));
    }

    if (_driverLocation != null) {
      points.add(_driverLocation!);
    }

    if (points.isEmpty) return;

    // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ Only one point ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ normal zoom
    if (points.length == 1) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 16),
        ),
      );
      return;
    }

    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final p in points) {
      south = south < p.latitude ? south : p.latitude;
      north = north > p.latitude ? north : p.latitude;
      west = west < p.longitude ? west : p.longitude;
      east = east > p.longitude ? east : p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ First fit bounds
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));

    // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ Calculate center
    final centerLat = (south + north) / 2;
    final centerLng = (west + east) / 2;

    // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¥ SHIFT CENTER UP (MAGIC)
    final shiftedCenter = LatLng(
      centerLat - 0.008, // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¹Ãƒâ€¦Ã¢â‚¬Å“ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â  adjust this if needed
      centerLng,
    );

    // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ Move camera slightly up
    await controller.animateCamera(CameraUpdate.newLatLng(shiftedCenter));
  }

  Future<void> _drawDriverToPickupPolylineOnce() async {
    if (_driverLocation == null || widget.currentLocation == null) return;

    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
        ),
        destination: PointLatLng(
          widget.currentLocation!.latitude!,
          widget.currentLocation!.longitude!,
        ),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isEmpty) return;

    final points =
        result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {
      _driverPolylines
        ..clear()
        ..addAll(_buildNavigationPolylines('driver_pickup', points));
      _driverPolylineDrawn = true;
    });
  }

  void _setDriverRoutePolyline(List<LatLng> routePath) {
    final points =
        routePath.length == 1 ? <LatLng>[routePath.first, routePath.first] : routePath;

    setState(() {
      _driverPolylines
        ..clear()
        ..addAll(_buildNavigationPolylines('driver_pickup', points));
      _driverPolylineDrawn = true;
    });
  }

  Set<Polyline> _buildNavigationPolylines(String id, List<LatLng> points) {
    if (points.length < 2) return {};

    return {
      Polyline(
        polylineId: PolylineId('${id}_casing'),
        color: const Color(0xFF0B3D91),
        width: 10,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        points: points,
      ),
      Polyline(
        polylineId: PolylineId('${id}_main'),
        color: const Color(0xFF22D3EE),
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        points: points,
      ),
    };
  }

  int _cameraDistanceBucket(double km) {
    if (km <= 0.15) return 0;
    if (km <= 0.5) return 1;
    if (km <= 1.5) return 2;
    return 3;
  }

  TransportCameraMode _currentCameraMode(List<LatLng>? routePath) {
    final pickup =
        widget.currentLocation == null
            ? null
            : LatLng(
              widget.currentLocation!.latitude!,
              widget.currentLocation!.longitude!,
            );
    final drop =
        destLatitude == null || destLongitude == null
            ? null
            : LatLng(destLatitude!, destLongitude!);

    if (_driverLocation == null || pickup == null) {
      return TransportCameraMode.overview;
    }

    final routeEnd = routePath?.isNotEmpty == true ? routePath!.last : null;
    final distanceToPickup = _distanceKm(_driverLocation!, pickup);
    final distanceToDrop =
        drop == null ? double.infinity : _distanceKm(_driverLocation!, drop);

    final headingToDrop =
        routeEnd != null &&
        drop != null &&
        _distanceKm(routeEnd, drop) < 0.12 &&
        (pickup == null || _distanceKm(routeEnd, pickup) > 0.12);

    if (headingToDrop) {
      return distanceToDrop <= 0.4
          ? TransportCameraMode.nearingDrop
          : TransportCameraMode.tripRunning;
    }

    return distanceToPickup <= 0.35
        ? TransportCameraMode.approachingPickup
        : TransportCameraMode.overview;
  }

  List<LatLng> _focusedPoints(TransportCameraMode mode) {
    final points = <LatLng>[];
    final pickup =
        widget.currentLocation == null
            ? null
            : LatLng(
              widget.currentLocation!.latitude!,
              widget.currentLocation!.longitude!,
            );
    final drop =
        destLatitude == null || destLongitude == null
            ? null
            : LatLng(destLatitude!, destLongitude!);

    switch (mode) {
      case TransportCameraMode.overview:
        if (pickup != null) points.add(pickup);
        if (drop != null) points.add(drop);
        if (_driverLocation != null) points.add(_driverLocation!);
        break;
      case TransportCameraMode.approachingPickup:
        if (_driverLocation != null) points.add(_driverLocation!);
        if (pickup != null) points.add(pickup);
        break;
      case TransportCameraMode.tripRunning:
        if (_driverLocation != null) points.add(_driverLocation!);
        if (drop != null) points.add(drop);
        break;
      case TransportCameraMode.nearingDrop:
        if (_driverLocation != null) points.add(_driverLocation!);
        if (drop != null) points.add(drop);
        break;
    }

    return points;
  }

  double? _preferredZoom(TransportCameraMode mode) {
    final pickup =
        widget.currentLocation == null
            ? null
            : LatLng(
              widget.currentLocation!.latitude!,
              widget.currentLocation!.longitude!,
            );
    final drop =
        destLatitude == null || destLongitude == null
            ? null
            : LatLng(destLatitude!, destLongitude!);

    switch (mode) {
      case TransportCameraMode.approachingPickup:
        if (_driverLocation == null || pickup == null) return null;
        final km = _distanceKm(_driverLocation!, pickup);
        if (km <= 0.12) return 16.8;
        if (km <= 0.3) return 16.1;
        if (km <= 0.8) return 15.3;
        return null;
      case TransportCameraMode.tripRunning:
        if (_driverLocation == null || drop == null) return null;
        final km = _distanceKm(_driverLocation!, drop);
        if (km <= 0.3) return 15.8;
        if (km <= 0.8) return 15.1;
        return null;
      case TransportCameraMode.nearingDrop:
        return 16.5;
      case TransportCameraMode.overview:
        return null;
    }
  }

  Future<void> _fitMapToRide({List<LatLng>? routePath, bool force = false}) async {
    if (!_mapController.isCompleted) return;

    final mode = _currentCameraMode(routePath);
    final points = _focusedPoints(mode);
    if (points.isEmpty) return;

    double distanceKm = 0.0;
    if (points.length >= 2) {
      distanceKm = _distanceKm(points.first, points.last);
    }
    final bucket = _cameraDistanceBucket(distanceKm);

    if (!force && _lastCameraMode == mode && _lastCameraBucket == bucket) {
      return;
    }

    _lastCameraMode = mode;
    _lastCameraBucket = bucket;

    final controller = await _mapController.future;
    final preferredZoom = _preferredZoom(mode);

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: preferredZoom ?? 16.0),
        ),
      );
      return;
    }

    final center = LatLng(
      (points.first.latitude + points.last.latitude) / 2,
      (points.first.longitude + points.last.longitude) / 2,
    );

    if (preferredZoom != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: center,
            zoom: distanceKm <= 1.0 ? preferredZoom + 0.6 : preferredZoom,
            tilt: distanceKm <= 1.0 ? 42 : 0,
          ),
        ),
      );
      return;
    }

    await _zoomToFitAllPoints(
      pickup: points.length > 0 ? points[0] : null,
      drop: points.length > 1 ? points[1] : null,
      driver: points.length > 2 ? points[2] : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _hydrateActiveRide();
    print('ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â TransportRideHomePage initialized');

    // Initialize map
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMapAndRoute();
    });
  }

  @override
  void dispose() {
    _driverMarkerAnimationTimer?.cancel();
    super.dispose();
  }

  void _hydrateActiveRide() {
    final booking = widget.initialActiveRide;
    if (booking == null) return;

    final drop = booking['drop'] as Map<String, dynamic>?;
    final dropCoordinates =
        (drop?['coordinates'] as List?) ??
        (drop?['location']?['coordinates'] as List?);

    if (dropCoordinates != null && dropCoordinates.length >= 2) {
      destLongitude = (dropCoordinates[0] as num).toDouble();
      destLatitude = (dropCoordinates[1] as num).toDouble();
    }

    destinationAddress = drop?['address']?.toString();
    destinationName = destinationAddress;

    if (widget.restoreToDriverConnecting) {
      currentState = RideState.driverConnecting;
    }
  }

  Future<void> _zoomToFitAllPoints({
    LatLng? pickup,
    LatLng? drop,
    LatLng? driver,
  }) async {
    final controller = await _mapController.future;

    final List<LatLng> points = [];

    if (pickup != null) points.add(pickup);
    if (drop != null) points.add(drop);
    if (driver != null) points.add(driver);

    if (points.isEmpty) return;

    // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â«ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¥ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ 1 point ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ zoom in
    if (points.length == 1) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 16),
        ),
      );
      return;
    }

    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final p in points) {
      south = south < p.latitude ? south : p.latitude;
      north = north > p.latitude ? north : p.latitude;
      west = west < p.longitude ? west : p.longitude;
      east = east > p.longitude ? east : p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 110));
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition = _initialMapTarget();
    final initialZoom = _initialMapZoom();
    final mapZoomLock = _mapZoomLock(initialZoom);

    return Scaffold(
      body: Stack(
        children: [
          /// ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ BACKGROUND MAP (Always full screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.52,
            child: CommonGoogleMap(
              key: ValueKey(
                'transport-map-${currentState.name}-${destLatitude?.toStringAsFixed(5)}-${destLongitude?.toStringAsFixed(5)}',
              ),
              initialLatLng: initialPosition,
              initialZoom: initialZoom,
              useDarkStyle: _useDarkMapPreview,
              minMaxZoomPreference: mapZoomLock,
              markers: _markers,
              circles: _mapFocusCircles(),
              polylines: {
                ..._polylines, // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âµ pickup ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ drop
                ..._driverPolylines, // ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ driver ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ pickup
              },
              mapPadding: _mapViewportPadding,
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }

                if (_markers.isNotEmpty) {
                  final defaultPosition =
                      widget.currentLocation != null
                          ? LatLng(
                            widget.currentLocation!.latitude!,
                            widget.currentLocation!.longitude!,
                          )
                          : const LatLng(19.0760, 72.8777);
                  _fitInitialTripView(defaultPosition);
                }
              },
              isFullScreen: true,
              driverInfo: _driverInfo,
              driverLocation: _driverLocation,
              driverBearing: _driverBearing,
            ),
          ),

          /// ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ BOTTOM DRAGGABLE SHEET
          DraggableScrollableSheet(
            initialChildSize:
                currentState == RideState.searchDestination ? 0.95 : 0.45,
            minChildSize: 0.45,
            maxChildSize: 1.0,
            expand: true,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildBottomUI(context),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomUI(BuildContext context) {
    switch (currentState) {
      case RideState.searchDestination:
        return SearchDestinationUI(
          currentLocation: widget.currentLocation,
          onSearchTap: () => _openDestinationPicker(context),
          onNext: (selectedData) {
            if (selectedData != null && selectedData.isNotEmpty) {
              setState(() {
                destinationName = selectedData['description']?.toString();
                destinationAddress = selectedData['address']?.toString();
                destLatitude =
                    selectedData['latitude'] is double
                        ? selectedData['latitude'] as double
                        : double.tryParse(
                              selectedData['latitude'].toString(),
                            ) ??
                            0.0;
                destLongitude =
                    selectedData['longitude'] is double
                        ? selectedData['longitude'] as double
                        : double.tryParse(
                              selectedData['longitude'].toString(),
                            ) ??
                            0.0;
              });

              print('Destination Selected:');
              print('Name: $destinationName');
              print('Address: $destinationAddress');
              print('Lat: $destLatitude, Lng: $destLongitude');
            }
            goTo(RideState.pickupDrop);
          },
        );

      case RideState.pickupDrop:
        return PickupDropUI(
          currentLocation: widget.currentLocation,
          destinationLocation:
              (destLatitude != null && destLongitude != null)
                  ? SelectedLocation(
                    latitude: destLatitude!,
                    longitude: destLongitude!,
                    address:
                        destinationName ?? destinationAddress ?? "Destination",
                  )
                  : null,
          onBack: () => goTo(RideState.searchDestination),
          onNext: () {
            print('ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Continuing to choose ride');
            goTo(RideState.chooseRide);
          },
          onEditPickup: () => goTo(RideState.editPickup),
          onEditDropoff: () => goTo(RideState.editDropoff),
        );

      case RideState.editPickup:
        return _buildEditPickupScreen(context);

      case RideState.editDropoff:
        return _buildEditDropoffScreen(context);

      case RideState.chooseRide:
        return Consumer(
          builder: (context, ref, child) {
            final pickupLocation = widget.currentLocation;
            final destinationLocation =
                (destLatitude != null && destLongitude != null)
                    ? SelectedLocation(
                      latitude: destLatitude!,
                      longitude: destLongitude!,
                      address:
                          destinationName ??
                          destinationAddress ??
                          "Destination",
                    )
                    : null;

            return ChooseRideUI(
              onBack: () => goTo(RideState.pickupDrop),
              onSelect: (
                selectedVehicleName,
                selectedVehicleId,
                selectedPrice,
              ) async {
                if (pickupLocation == null || destinationLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please select pickup and destination location",
                      ),
                    ),
                  );
                  return;
                }

                print('Vehicle selected in TransportRideHomePage:');
                print('   Name: $selectedVehicleName');
                print('   ID: $selectedVehicleId');
                print('   Price: $selectedPrice');

                setState(() {
                  this.selectedRide = selectedVehicleName;
                  this.selectedVehicleId = selectedVehicleId;
                  this.price = selectedPrice;
                });
                fareEstimateApi(
                  category: "goods",
                  ref: ref,
                  vehicleTypeId: selectedVehicleId,
                  pickupAddress: pickupLocation.address ?? "Pickup Location",
                  pickupCoordinates: [
                    pickupLocation.longitude,
                    pickupLocation.latitude,
                  ],
                  dropAddress: destinationLocation.address ?? "Destination",
                  dropCoordinates: [
                    destinationLocation.longitude,
                    destinationLocation.latitude,
                  ],
                );
                //  if (result.isNotEmpty) {
                //   ref.read(fareEstimateProvider.notifier).state = result;
                // }
                goTo(RideState.driverConnecting);
              },
              pickupLocation: pickupLocation,
              destinationLocation: destinationLocation,
              isLoading: isLoadingFare,
              isGoodsTransport: true,
            );
          },
        );

      case RideState.driverConnecting:
        return DriverConnectingUI(
          onRideBooked: () {
            print('Ride booked successfully!');
            //  goTo(RideState.payment);
          },
          onBack: () => goTo(RideState.chooseRide),
          rideType: selectedRide,
          price: price ?? 250,
          carId: selectedVehicleId,
          // Pass current location from widget
          currentLocation: widget.currentLocation, // Add this
          // Pass destination data
          destLatitude: destLatitude, // Add this
          destLongitude: destLongitude, // Add this
          destinationAddress: destinationAddress, // Add this
          pickupLocation: widget.currentLocation,
          dropLocation: SelectedLocation(
            latitude: destLatitude ?? 0.0,
            longitude: destLongitude ?? 0.0,
            address: destinationAddress ?? "Destination not set",
          ),
          onDriverUpdate: _onDriverUpdate,
          initialBookingData: widget.initialActiveRide,
        );

      case RideState.payment:
        return Column(
          children: [
            Text(
              "Payment",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _payCashStatic,
              child: const Text("Pay Cash"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _payOnlineStatic,
              child: const Text("Pay Online"),
            ),
          ],
        );

      default:
        return SizedBox();
    }
  }

  void _payCashStatic() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Cash payment successful")));

    _resetRide();
  }

  void _payOnlineStatic() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Online payment successful")));

    _resetRide();
  }

  void _resetRide() {
    setState(() {
      currentState = RideState.searchDestination;
      _markers.clear();
      _polylines.clear();
      _driverPolylines.clear();
      _driverMarker = null;
      _driverMarkerAdded = false;
      _driverLocation = null;
      _driverInfo = null;
      _driverOtp = null;
    });
  }

  Widget _buildEditPickupScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => goTo(RideState.pickupDrop),
        ),
        title: Text(
          "Edit Pickup Location",
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: CommonGoogleMap(
                initialLatLng:
                    widget.currentLocation != null
                        ? LatLng(
                          widget.currentLocation!.latitude!,
                          widget.currentLocation!.longitude!,
                        )
                        : const LatLng(19.0760, 72.8777),
                height: 200,
                markers: {
                  Marker(
                    markerId: const MarkerId('edit_pickup'),
                    position:
                        widget.currentLocation != null
                            ? LatLng(
                              widget.currentLocation!.latitude!,
                              widget.currentLocation!.longitude!,
                            )
                            : const LatLng(19.0760, 72.8777),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                },
              ),
            ),

            SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: SearchDestinationUI(
                currentLocation: widget.currentLocation,
                onSearchTap: () {
                  print('Opening map for pickup location');
                },
                onNext: (selectedData) {
                  if (selectedData != null && selectedData.isNotEmpty) {
                    print('Pickup updated via Next button');
                    print('New Location: ${selectedData['description']}');
                  }
                  goTo(RideState.pickupDrop);
                },
                mode: 'pickup',
                initialValue: widget.currentLocation?.address,
                onDestinationSelected: (locationData) {
                  print(
                    'Pickup location selected from search: ${locationData['description']}',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditDropoffScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => goTo(RideState.pickupDrop),
        ),
        title: Text(
          "Edit Dropoff Location",
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: CommonGoogleMap(
                initialLatLng:
                    destLatitude != null && destLongitude != null
                        ? LatLng(destLatitude!, destLongitude!)
                        : LatLng(19.0760, 72.8777),
                height: 200,
                markers: {
                  Marker(
                    markerId: MarkerId('edit_dropoff'),
                    position:
                        destLatitude != null && destLongitude != null
                            ? LatLng(destLatitude!, destLongitude!)
                            : LatLng(19.0760, 72.8777),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                },
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: SearchDestinationUI(
                currentLocation: widget.currentLocation,
                onSearchTap: () {
                  print('Opening map for dropoff location');
                },
                onNext: (selectedData) {
                  if (selectedData != null && selectedData.isNotEmpty) {
                    setState(() {
                      destinationName = selectedData['description']?.toString();
                      destinationAddress = selectedData['address']?.toString();
                      destLatitude = selectedData['latitude'];
                      destLongitude = selectedData['longitude'];
                    });
                    print('Dropoff updated via Next button');
                  }
                  goTo(RideState.pickupDrop);
                },
                mode: 'dropoff',
                initialValue: destinationAddress,
                onDestinationSelected: (locationData) {
                  print(
                    'Dropoff location selected from search: ${locationData['description']}',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
