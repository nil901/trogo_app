import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/goods_details_page.dart';
import 'package:trogo_app/models/estimateurl_model.dart';
import 'package:trogo_app/models/vehicle_type_model.dart';
import 'package:trogo_app/transportergoods/tracking_screen.dart';
import 'package:trogo_app/wigets/comman_map.dart';
import 'package:trogo_app/wigets/search_location_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GoodsFlowManager
// ─────────────────────────────────────────────────────────────────────────────

class GoodsFlowManager extends StatefulWidget {
  const GoodsFlowManager({super.key});

  @override
  State<GoodsFlowManager> createState() => _GoodsFlowManagerState();
}

class _GoodsFlowManagerState extends State<GoodsFlowManager> {
  String? _bookingId;
  Map<String, dynamic>? _driverInfo;
  bool _isRideCompleted = false;
  Map<String, dynamic>? _bookingData;

  void _handleBookingCreated(
    String bookingId,
    Map<String, dynamic> bookingData,
  ) {
    setState(() {
      _bookingId = bookingId;
      _bookingData = bookingData;
    });
  }

  void _handleRideCompleted() {
    setState(() {
      _isRideCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScheduleDeliveryPage(onBookingCreated: _handleBookingCreated),
    );
  }

  Widget _buildCompletionScreen() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 100, color: Colors.green),
          SizedBox(height: 20),
          Text(
            "Delivery Completed!",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            "Thank you for choosing our service",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 20),
          Text(
            "Payment completed successfully",
            style: TextStyle(fontSize: 14, color: Colors.green),
          ),
          SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _bookingId = null;
                _isRideCompleted = false;
                _bookingData = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: Text("Book Another Delivery"),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ScheduleDeliveryPage
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleDeliveryPage extends ConsumerStatefulWidget {
  final Function(String, Map<String, dynamic>)? onBookingCreated;

  const ScheduleDeliveryPage({super.key, this.onBookingCreated});

  @override
  ConsumerState<ScheduleDeliveryPage> createState() =>
      _ScheduleDeliveryPageState();
}

class _ScheduleDeliveryPageState extends ConsumerState<ScheduleDeliveryPage> {
  // ── API Key ────────────────────────────────────────────────────────────────
  static const String GOOGLE_MAPS_API_KEY =
      "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";
  final PolylinePoints _polylinePoints = PolylinePoints(
    apiKey: GOOGLE_MAPS_API_KEY,
  );

  // ── State ──────────────────────────────────────────────────────────────────
  int? selectedVehicle;
  String pickupLocation = "Getting your location...";
  String deliveryLocation = "";
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  Position? currentPosition;
  Position? deliveryPosition;
  bool isLoadingLocation = true;

  Completer<GoogleMapController> mapController = Completer();
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Set<Circle> circles = {};
  CameraPosition? initialCameraPosition;

  bool _isFetchingFareEstimate = false;
  FareEstimate? _selectedFareEstimate;
  VehicleType? selectedVehicleData;

  final List<Map<String, dynamic>> _nearbyDrivers = [];
  BitmapDescriptor? _nearbyCarIcon;
  bool _isLoadingNearbyDrivers = false;
  DateTime? _lastNearbyDriversFetchAt;
  bool _isLoadingVehicleTypes = false;
  bool _hasLoadedVehicleTypes = false;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void initState() {
    super.initState();
    _setCurrentPickupLocation();
    // ✅ FIX: Only load once, not on every rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVehicleTypes();
    });
  }
   Future<void> _loadVehicleTypes() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingVehicleTypes || _hasLoadedVehicleTypes) {
      debugPrint("⚠️ Vehicle types already loaded or loading, skipping...");
      return;
    }
    
    debugPrint("🔄 Loading vehicle types for goods...");
    _isLoadingVehicleTypes = true;
    
    if (mounted) setState(() {});
    
    try {
      // Call the API
      final vehicles = await vehicletypesApi(ref, "goods");
      
      debugPrint("✅ Loaded ${vehicles.length} vehicles");
      _hasLoadedVehicleTypes = true;
      
      if (mounted && vehicles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No vehicles available for goods transport"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error loading vehicle types: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load vehicles: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isLoadingVehicleTypes = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshVehicleTypes() async {
    if (_isLoadingVehicleTypes) {
      debugPrint("⚠️ Already loading vehicles, skipping refresh...");
      return;
    }
    
    debugPrint("🔄 Manual refresh of vehicle types...");
    _hasLoadedVehicleTypes = false; // Reset flag to allow reload
    
    // Show loading snackbar
    final snackBar = SnackBar(
      content: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text("Refreshing vehicles..."),
        ],
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.black87,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    
    await _loadVehicleTypes();
    
    // Show success message
    final vehicles = ref.read(goodsVihicletypeProvider);
    if (mounted && vehicles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Loaded ${vehicles.length} vehicles"),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  //  ✅ FIX: Road-following polyline via Google Directions API (HTTP call)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _getRoutePolyline() async {
    if (currentPosition == null || deliveryPosition == null) return;

    try {
      List<LatLng> routePoints = await _fetchRoutePointsWithPolylinePoints();

      if (routePoints.isEmpty) {
        routePoints = await _fetchRoutePointsFromDirectionsApi();
      }

      if (routePoints.isEmpty) {
        debugPrint('Route fetch failed from both route sources. Using fallback line.');
        _fallbackStraightPolyline();
        return;
      }

      polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.black,
            width: 5,
            points: routePoints,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

      if (currentPosition != null && deliveryPosition != null) {
        final bounds = _getBounds(currentPosition!, deliveryPosition!);
        final controller = await mapController.future;
        await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Route polyline error: $e');
      _clearRoutePolyline();
    }
  }

  void _fallbackStraightPolyline() {
    if (currentPosition == null || deliveryPosition == null) {
      _clearRoutePolyline();
      return;
    }

    polylines
      ..removeWhere((polyline) => polyline.polylineId.value == 'route')
      ..add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.black87,
          width: 4,
          points: [
            LatLng(currentPosition!.latitude, currentPosition!.longitude),
            LatLng(deliveryPosition!.latitude, deliveryPosition!.longitude),
          ],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    if (mounted) setState(() {});
  }

  void _clearRoutePolyline() {
    polylines.removeWhere((polyline) => polyline.polylineId.value == 'route');
    if (mounted) setState(() {});
  }

  Future<List<LatLng>> _fetchRoutePointsWithPolylinePoints() async {
    final result = await _polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(
          currentPosition!.latitude,
          currentPosition!.longitude,
        ),
        destination: PointLatLng(
          deliveryPosition!.latitude,
          deliveryPosition!.longitude,
        ),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isEmpty) {
      debugPrint(
        'PolylinePoints route empty. '
        'status=${result.status} error=${result.errorMessage}',
      );
      return [];
    }

    return result.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  Future<List<LatLng>> _fetchRoutePointsFromDirectionsApi() async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${currentPosition!.latitude},${currentPosition!.longitude}'
        '&destination=${deliveryPosition!.latitude},${deliveryPosition!.longitude}'
        '&mode=driving'
        '&key=$GOOGLE_MAPS_API_KEY',
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        debugPrint('Directions API HTTP error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        debugPrint('Directions API status: ${data['status']}');
        return [];
      }

      final encoded =
          data['routes'][0]['overview_polyline']['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        return [];
      }

      final decodedPoints = PolylinePoints.decodePolyline(encoded);
      return decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    } catch (e) {
      debugPrint('Directions API fallback error: $e');
      return [];
    }
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _geocodeAddress(String address, {required bool isPickup}) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        _setStateIfMounted(() {
          final position = Position(
            latitude: locations.first.latitude,
            longitude: locations.first.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );

          if (isPickup) {
            currentPosition = position;
          } else {
            deliveryPosition = position;
          }
        });

        _updateMapMarkers();
        unawaited(_refreshNearbyDrivers(force: true));

        if (currentPosition != null && deliveryPosition != null) {
          await _getRoutePolyline();
        }
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
  }

  Future<void> _setCurrentPickupLocation() async {
    try {
      _setStateIfMounted(() => isLoadingLocation = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _setStateIfMounted(() {
          pickupLocation = "Turn on location services";
          isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setStateIfMounted(() {
          pickupLocation = "Location permission denied";
          isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      _setStateIfMounted(() {
        currentPosition = position;
        initialCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14.5,
        );
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String address = "";
        if (p.street != null && p.street!.isNotEmpty) address += p.street!;
        if (p.locality != null && p.locality!.isNotEmpty) {
          address += address.isNotEmpty ? ", ${p.locality!}" : p.locality!;
        }
        if (p.subLocality != null && p.subLocality!.isNotEmpty) {
          address +=
              address.isNotEmpty ? ", ${p.subLocality!}" : p.subLocality!;
        }
        _setStateIfMounted(() {
          pickupLocation = address.isNotEmpty ? address : "Current Location";
          isLoadingLocation = false;
        });
      }

      _updateMapMarkers();
      await _refreshNearbyDrivers(force: true);
    } catch (e) {
      debugPrint("Error getting location: $e");
      _setStateIfMounted(() {
        pickupLocation = "Tap to select location";
        isLoadingLocation = false;
      });
    }
  }

  // ── Fare Estimate ──────────────────────────────────────────────────────────

  Future<FareEstimate?> _fetchGoodsFareEstimate(VehicleType vehicle) async {
    debugPrint("STEP 3: Calling goods fare estimate API");
    debugPrint("API CALL STARTED");
    debugPrint("PICKUP: $currentPosition");
    debugPrint("DROP: $deliveryPosition");

    if (currentPosition == null || deliveryPosition == null) {
      debugPrint("API blocked: pickup or drop position is null");
      return null;
    }

    final vehicleId = vehicle.id?.toString();
    if (vehicleId == null || vehicleId.trim().isEmpty) {
      debugPrint("API blocked: vehicle id is null/empty");
      return null;
    }

    final fares = await fareEstimateApi(
      ref: ref,
      category: "goods",
      vehicleTypeId: vehicleId,
      pickupAddress: pickupLocation,
      pickupCoordinates: [
        currentPosition!.longitude,
        currentPosition!.latitude,
      ],
      dropAddress: deliveryLocation,
      dropCoordinates: [
        deliveryPosition!.longitude,
        deliveryPosition!.latitude,
      ],
    );

    debugPrint("Goods fare estimate count: ${fares.length}");
    if (fares.isEmpty) {
      debugPrint("Goods fare estimate response empty");
      return null;
    }

    for (final fare in fares) {
      if (fare.vehicleTypeId == vehicleId) {
        debugPrint("Matched fare for vehicleId: $vehicleId");
        return fare;
      }
    }
    debugPrint(
      "No exact vehicleTypeId match found for $vehicleId, using first fare",
    );
    return fares.first;
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  bool _validateBeforeNext() {
    if (pickupLocation.isEmpty ||
        pickupLocation.contains("Getting") ||
        pickupLocation.contains("Tap to")) {
      _showValidationMessage("Please select pickup location");
      return false;
    }
    if (deliveryLocation.isEmpty || deliveryPosition == null) {
      _showValidationMessage("Please select delivery location");
      return false;
    }
    if (selectedTime == null) {
      _showValidationMessage("Please select time");
      return false;
    }
    if (selectedVehicleData == null) {
      _showValidationMessage("Please select a vehicle");
      return false;
    }
    return true;
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  // ── Map Markers ────────────────────────────────────────────────────────────

  void _updateMapMarkers() {
    markers.removeWhere(
      (m) => m.markerId.value == 'pickup' || m.markerId.value == 'delivery',
    );
    circles.removeWhere((c) => c.circleId.value.startsWith('nearby_user_'));

    if (currentPosition != null) {
      final pickupLatLng = LatLng(
        currentPosition!.latitude,
        currentPosition!.longitude,
      );
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
          zIndex: 4,
        ),
      );
      circles.addAll({
        Circle(
          circleId: const CircleId('nearby_user_outer'),
          center: pickupLatLng,
          radius: 55,
          fillColor: const Color(0x332563EB),
          strokeColor: Colors.transparent,
        ),
        Circle(
          circleId: const CircleId('nearby_user_inner'),
          center: pickupLatLng,
          radius: 18,
          fillColor: const Color(0x662563EB),
          strokeColor: const Color(0xFF2563EB),
          strokeWidth: 2,
        ),
      });
    }

    if (deliveryPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: LatLng(
            deliveryPosition!.latitude,
            deliveryPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Delivery'),
          zIndex: 2,
        ),
      );
    }

    if (currentPosition != null && deliveryPosition != null) {
      final bounds = _getBounds(currentPosition!, deliveryPosition!);
      mapController.future.then(
        (c) => c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100)),
      );
    }

    if (mounted) setState(() {});
  }

  // ── Nearby Drivers ─────────────────────────────────────────────────────────

  Future<void> _loadNearbyCarIcon() async {
    if (_nearbyCarIcon != null) return;
    try {
      const size = 40.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = const Offset(size / 2, size / 2);

      final shadowPaint =
          Paint()
            ..color = Colors.black.withOpacity(0.10)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(center + const Offset(0, 4), 7, shadowPaint);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.55);
      canvas.translate(-center.dx, -center.dy);

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

      final cabin = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 7, height: 9),
        const Radius.circular(2),
      );
      canvas.drawRRect(cabin, Paint()..color = const Color(0xFF111827));

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
      if (bytes == null) throw Exception('Unable to create nearby car icon');
      _nearbyCarIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Nearby car icon load failed: $e');
      _nearbyCarIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
    }
  }

  LatLng? _extractNearbyDriverLatLng(Map<String, dynamic> driver) {
    final location = driver['location'];
    if (location is Map) {
      final coordinates = location['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        final lng = double.tryParse(coordinates[0].toString());
        final lat = double.tryParse(coordinates[1].toString());
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
      final lat = double.tryParse(
        (location['latitude'] ?? location['lat']).toString(),
      );
      final lng = double.tryParse(
        (location['longitude'] ?? location['lng']).toString(),
      );
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    final directLat = double.tryParse(
      (driver['latitude'] ?? driver['lat']).toString(),
    );
    final directLng = double.tryParse(
      (driver['longitude'] ?? driver['lng']).toString(),
    );
    if (directLat != null && directLng != null) {
      return LatLng(directLat, directLng);
    }
    return null;
  }

  void _syncNearbyDriverMarkers() {
    markers.removeWhere((m) => m.markerId.value.startsWith('nearby_driver_'));
    for (final driver in _nearbyDrivers.take(6)) {
      final id = driver['_id']?.toString();
      final latLng = _extractNearbyDriverLatLng(driver);
      if (id == null || latLng == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('nearby_driver_$id'),
          position: latLng,
          icon:
              _nearbyCarIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: ((id.hashCode % 180) - 90).toDouble(),
          zIndex: 2,
          infoWindow: const InfoWindow(title: ''),
        ),
      );
    }
  }

  Future<void> _refreshNearbyDrivers({bool force = false}) async {
    if (currentPosition == null || _isLoadingNearbyDrivers) return;
    final lastFetch = _lastNearbyDriversFetchAt;
    if (!force &&
        lastFetch != null &&
        DateTime.now().difference(lastFetch) < const Duration(seconds: 20)) {
      _syncNearbyDriverMarkers();
      if (mounted) setState(() {});
      return;
    }
    _isLoadingNearbyDrivers = true;
    await _loadNearbyCarIcon();
    try {
      final response = await ApiService().getRequest(nearbyDriversUrl);
      final responseData = response?.data;
      final rawDrivers = responseData is Map ? responseData['drivers'] : null;
      if (rawDrivers is List) {
        _nearbyDrivers
          ..clear()
          ..addAll(
            rawDrivers
                .whereType<Map>()
                .map((d) => Map<String, dynamic>.from(d)),
          );
        _lastNearbyDriversFetchAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('Nearby drivers fetch failed: $e');
    } finally {
      _syncNearbyDriverMarkers();
      if (mounted) setState(() {});
      _isLoadingNearbyDrivers = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  LatLngBounds _getBounds(Position pos1, Position pos2) {
    return LatLngBounds(
      southwest: LatLng(
        pos1.latitude < pos2.latitude ? pos1.latitude : pos2.latitude,
        pos1.longitude < pos2.longitude ? pos1.longitude : pos2.longitude,
      ),
      northeast: LatLng(
        pos1.latitude > pos2.latitude ? pos1.latitude : pos2.latitude,
        pos1.longitude > pos2.longitude ? pos1.longitude : pos2.longitude,
      ),
    );
  }

  void _processLocationResult(dynamic result, {required bool isPickup}) {
    try {
      if (!mounted) return;
      if (result is Map<String, dynamic>) {
        final address = result['address']?.toString() ?? "Unknown Address";
        final lat = double.tryParse(result['lat'].toString()) ?? 0.0;
        final lng = double.tryParse(result['lng'].toString()) ?? 0.0;
        _setStateIfMounted(() {
          if (isPickup) {
            pickupLocation = address;
            currentPosition = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          } else {
            deliveryLocation = address;
            deliveryPosition = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
        });
      } else if (result is String) {
        _setStateIfMounted(() {
          if (isPickup) {
            pickupLocation = result;
            if (result.isNotEmpty && !result.contains("Getting")) {
              unawaited(_geocodeAddress(result, isPickup: true));
            }
          } else {
            deliveryLocation = result;
            if (result.isNotEmpty) {
              unawaited(_geocodeAddress(result, isPickup: false));
            }
          }
        });
      }

      _updateMapMarkers();
      _refreshNearbyDrivers(force: true);

      if (!isPickup && deliveryPosition != null && currentPosition != null) {
        _getRoutePolyline();
      }
      if (isPickup && deliveryPosition != null && currentPosition != null) {
        _getRoutePolyline();
      }
    } catch (e) {
      debugPrint("Error processing location result: $e");
      _setStateIfMounted(() {
        if (isPickup) {
          pickupLocation = result.toString();
        } else {
          deliveryLocation = result.toString();
        }
      });
    }
  }

  // ── Date / Time Pickers ────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && picked != selectedTime) {
      setState(() => selectedTime = picked);
    }
  }

  

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final transport = ref.watch(goodsVihicletypeProvider);
    final isLoadingVehicleTypes = ref.watch(goodsVehicleTypesLoadingProvider);
    
    final initialTarget =
        currentPosition != null
            ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
            : const LatLng(19.0760, 72.8777);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.52,
            child: CommonGoogleMap(
              key: ValueKey(
                'goods-schedule-map-'
                '${currentPosition?.latitude}-${currentPosition?.longitude}-'
                '${deliveryPosition?.latitude}-${deliveryPosition?.longitude}',
              ),
              initialLatLng: initialTarget,
              markers: markers,
              polylines: polylines,
              circles: circles,
              onMapCreated: (controller) {
                if (!mapController.isCompleted) {
                  mapController.complete(controller);
                }
              },
              isFullScreen: true,
              useLightPreviewStyle: true,
              trafficEnabled: true,
              buildingsEnabled: true,
            ),
          ),

          // ── TOP GRADIENT ─────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── BACK BUTTON ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // ── LOCATION CARD ON MAP ─────────────────────────────────────────
          if (currentPosition != null || deliveryPosition != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.65,
                          child: Text(
                            pickupLocation,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 20,
                      width: 1,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.only(left: 4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.65,
                          child: Text(
                            deliveryLocation.isNotEmpty
                                ? deliveryLocation
                                : "Select delivery location",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color:
                                  deliveryLocation.isNotEmpty
                                      ? Colors.black
                                      : Colors.grey,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── NEARBY DRIVERS BADGE ─────────────────────────────────────────
          if (_nearbyDrivers.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 160,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  '${_nearbyDrivers.length} drivers nearby',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),

          // ── BOTTOM SHEET ─────────────────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.48,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.48, 0.92],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),

                              // Title with refresh button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Schedule Delivery",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  // ✅ FIX: Added refresh button for vehicle types
                                  IconButton(
                                    onPressed: _refreshVehicleTypes,
                                    icon: const Icon(Icons.refresh),
                                    color: Colors.grey.shade600,
                                    tooltip: "Refresh vehicles",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Enter pickup and delivery details",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Pickup
                              _buildLocationCard(
                                context,
                                isPickup: true,
                                location: pickupLocation,
                                isLoading: isLoadingLocation,
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => LocationSearchPage(
                                            initialQuery:
                                                pickupLocation.contains(
                                                      "Getting",
                                                    )
                                                    ? ""
                                                    : pickupLocation,
                                            title: "Set Pickup Location",
                                            currentPosition: currentPosition,
                                          ),
                                    ),
                                  );
                                  if (result != null) {
                                    _processLocationResult(
                                      result,
                                      isPickup: true,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // Delivery
                              _buildLocationCard(
                                context,
                                isPickup: false,
                                location: deliveryLocation,
                                isLoading: false,
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => LocationSearchPage(
                                            initialQuery: deliveryLocation,
                                            title: "Set Delivery Location",
                                            currentPosition: currentPosition,
                                          ),
                                    ),
                                  );
                                  if (result != null) {
                                    _processLocationResult(
                                      result,
                                      isPickup: false,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 20),

                              // Date & Time
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDateTimeButton(
                                      icon: Icons.calendar_today,
                                      title: "Date",
                                      value:
                                          selectedDate != null
                                              ? DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(selectedDate!)
                                              : "Today",
                                      onTap: _pickDate,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDateTimeButton(
                                      icon: Icons.access_time,
                                      title: "Time",
                                      value:
                                          selectedTime != null
                                              ? selectedTime!.format(context)
                                              : "Now",
                                      onTap: _pickTime,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Vehicle Type
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Vehicle Type",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (isLoadingVehicleTypes)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // ✅ FIX: Show loading or empty state
                              isLoadingVehicleTypes
                                  ? Container(
                                      height: 154,
                                      alignment: Alignment.center,
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 12),
                                          Text(
                                            "Loading vehicles...",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : transport.isEmpty
                                      ? Container(
                                          height: 154,
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.dangerous,
                                                size: 48,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                "No vehicles available",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextButton(
                                                onPressed: _refreshVehicleTypes,
                                                child: const Text("Try Again"),
                                              ),
                                            ],
                                          ),
                                        )
                                      : SizedBox(
                                          height: 154,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            itemCount: transport.length,
                                            itemBuilder: (context, index) {
                                              final vehicle = transport[index];
                                              final isSelected = selectedVehicle == index;
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    selectedVehicle = index;
                                                    selectedVehicleData = vehicle;
                                                    _selectedFareEstimate = null;
                                                  });
                                                },
                                                child: Container(
                                                  width: 132,
                                                  margin: const EdgeInsets.only(right: 12),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isSelected
                                                            ? Colors.blue.shade50
                                                            : Colors.grey.shade50,
                                                    borderRadius: BorderRadius.circular(
                                                      16,
                                                    ),
                                                    border: Border.all(
                                                      color:
                                                          isSelected
                                                              ? Colors.blue.shade700
                                                              : Colors.grey.shade300,
                                                      width: isSelected ? 2 : 1,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        width: 50,
                                                        height: 50,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isSelected
                                                                  ? Colors.blue.shade100
                                                                  : Colors.grey.shade200,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Center(
                                                          child: Image.network(
                                                            vehicle.image,
                                                            width: 30,
                                                            height: 30,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Icon(
                                                                Icons.directions_car,
                                                                size: 30,
                                                                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Expanded(
                                                        child: Center(
                                                          child: Text(
                                                            vehicle.name,
                                                            textAlign: TextAlign.center,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              height: 1.25,
                                                              fontWeight: FontWeight.w600,
                                                              color:
                                                                  isSelected
                                                                      ? Colors.blue.shade700
                                                                      : Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        "₹${vehicle.rate} / ${vehicle.pricingType == "PER_HOUR" ? "Hour" : "KM"}",
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                              const SizedBox(height: 30),

                              // Next Button
                              _buildNextButton(context),

                              SizedBox(
                                height:
                                    MediaQuery.of(context).padding.bottom + 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────

  Widget _buildLocationCard(
    BuildContext context, {
    required bool isPickup,
    required String location,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPickup ? Colors.red.shade50 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isPickup ? Icons.circle : Icons.flag_circle,
                  color: isPickup ? Colors.red : Colors.green,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPickup ? "Pickup location" : "Delivery location",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isLoading)
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isPickup ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Getting location...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      location.isNotEmpty ? location : "Select location",
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            location.isNotEmpty
                                ? Colors.black
                                : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeButton({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton(BuildContext context) {
    final isReady =
        pickupLocation.isNotEmpty &&
        deliveryLocation.isNotEmpty &&
        !pickupLocation.contains("Getting") &&
        !pickupLocation.contains("Tap to") &&
        selectedTime != null &&
        selectedVehicleData != null;

    return GestureDetector(
      onTap: () async {
        debugPrint("STEP 1: Next button clicked");
        if (!_validateBeforeNext()) return;
        debugPrint("STEP 2: Validation passed");
        final vehicle = selectedVehicleData;
        if (vehicle == null) {
          _showValidationMessage("Please select a vehicle");
          return;
        }
        setState(() => _isFetchingFareEstimate = true);
        final fareEstimate = await _fetchGoodsFareEstimate(vehicle);
        if (!mounted) return;
        setState(() {
          _selectedFareEstimate = fareEstimate;
          _isFetchingFareEstimate = false;
        });
        if (fareEstimate == null) {
          _showValidationMessage(
            "Fare estimate unavailable. Please check pickup, drop and vehicle.",
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => GoodsDetailsPage(
                  pickupLocation: pickupLocation,
                  deliveryLocation: deliveryLocation,
                  selectedDate: selectedDate,
                  selectedTime: selectedTime,
                  selectedVehicle: vehicle,
                  pickupPosition: currentPosition,
                  deliveryPosition: deliveryPosition,
                  fareEstimate: fareEstimate,
                  onBookingCreated: widget.onBookingCreated,
                ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _isFetchingFareEstimate
              ? Colors.grey.shade400
              : isReady
                  ? Colors.black
                  : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isReady && !_isFetchingFareEstimate
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                  : [],
        ),
        child: Center(
          child: _isFetchingFareEstimate
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  "Next →",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color:
                        isReady ? Colors.white : Colors.grey.shade500,
                  ),
                ),
        ),
      ),
    );
  }
}
