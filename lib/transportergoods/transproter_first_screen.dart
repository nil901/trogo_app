import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

class TransportRideHomePage extends ConsumerStatefulWidget {
  final SelectedLocation? currentLocation;

  const TransportRideHomePage({super.key, this.currentLocation});

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

  bool _driverMarkerAdded = false;
  Future<void> _loadDriverCarIcon() async {
    if (_driverCarIcon != null) return;

    _driverCarIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(devicePixelRatio: 2.5, size: Size(48, 48)),
      'assets/images/car.png',
    );

    print('🚗 Driver car icon loaded');
  }

  static const String GOOGLE_MAPS_API_KEY =
      "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";
  PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_MAPS_API_KEY);

  // Driver State Variables
  Map<String, dynamic>? _driverInfo;
  LatLng? _driverLocation;
  double _driverBearing = 0.0;
  bool _showDriverOnMap = false;

  void goTo(RideState s) {
    setState(() {
      currentState = s;
    });

    if (s == RideState.pickupDrop ||
        s == RideState.chooseRide ||
        s == RideState.driverConnecting) {
      _setupMapAndRoute();
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
    print('🗺️ Setting up map and route in TransportRideHomePage...');

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

      // 🔵 Pickup → Drop route
      if (widget.currentLocation != null) {
        await _fetchRoutePolyline();
      }
    }

    // ===================== DRIVER MARKER =====================
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

        final polyline = Polyline(
          polylineId: const PolylineId('route'),
          color: const Color(0xFF1a73e8),
          width: 4,
          geodesic: true,
          points: _routeCoordinates,
        );

        setState(() {
          _polylines.clear();
          _polylines.add(polyline);
        });
      }
    } catch (e) {
      print('🔥 Error fetching route: $e');
    }
  }

  Set<Polyline> _driverPolylines = {};

  double _bottomSheetHeight = 320;

  // --- Driver Update Handler ---
  void _onDriverUpdate(
    Map<String, dynamic> driverInfo,
    LatLng location,
    double bearing,
    String? otp,
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
      _updateDriverMarker(location, bearing);
    }

    _drawDriverToPickupPolylineOnce();
    _zoomUberCentered();
  }

  void _addDriverMarker(LatLng location, double bearing) {
    _driverMarker = Marker(
      markerId: const MarkerId('driver_car'),
      position: location,
      icon: _driverCarIcon!, // 🔥 CAR ICON
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
    _driverMarker = _driverMarker!.copyWith(
      positionParam: newLocation,
      rotationParam: bearing,
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver_car');
      _markers.add(_driverMarker!);
    });
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

    // Single point → zoom in
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

    // 🔥 Uber-style padding
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        100 + _bottomSheetHeight, // 👈 MAGIC LINE
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

    // 🔹 Only one point → normal zoom
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

    // 🔹 First fit bounds
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));

    // 🔹 Calculate center
    final centerLat = (south + north) / 2;
    final centerLng = (west + east) / 2;

    // 🔥 SHIFT CENTER UP (MAGIC)
    final shiftedCenter = LatLng(
      centerLat - 0.008, // 👈 adjust this if needed
      centerLng,
    );

    // 🔹 Move camera slightly up
    await controller.animateCamera(CameraUpdate.newLatLng(shiftedCenter));
  }

  Future<void> _drawDriverToPickupPolylineOnce() async {
    if (_driverPolylineDrawn) return;
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
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_pickup'),
          color: Colors.green,
          width: 4,
          points: points,
        ),
      );
      _driverPolylineDrawn = true;
    });
  }

  @override
  void initState() {
    super.initState();
    print('🚗 TransportRideHomePage initialized');

    // Initialize map
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMapAndRoute();
    });
  }

  @override
  void dispose() {
    super.dispose();
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

    // फक्त 1 point → zoom in
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

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    LatLng initialPosition =
        widget.currentLocation != null
            ? LatLng(
              widget.currentLocation!.latitude!,
              widget.currentLocation!.longitude!,
            )
            : const LatLng(19.0760, 72.8777);

    return Scaffold(
      body: Stack(
        children: [
          /// 🔹 BACKGROUND MAP (Always full screen)
          Positioned.fill(
            child: CommonGoogleMap(
              initialLatLng: initialPosition,
              markers: _markers,
              polylines: {
                ..._polylines, // 🔵 pickup → drop
                ..._driverPolylines, // 🟢 driver → pickup
              },
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }

                if (_markers.isNotEmpty) {}
              },
              isFullScreen: true,
              driverInfo: _driverInfo,
              driverLocation: _driverLocation,
              driverBearing: _driverBearing,
            ),
          ),

          /// 🔹 BOTTOM DRAGGABLE SHEET
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
            print('➡️ Continuing to choose ride');
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
                print('🚗 Vehicle selected in TransportRideHomePage:');
                print('   Name: $selectedVehicleName');
                print('   ID: $selectedVehicleId');
                print('   Price: ₹$selectedPrice');

                setState(() {
                  this.selectedRide = selectedVehicleName;
                  this.selectedVehicleId = selectedVehicleId;
                  this.price = selectedPrice;
                });
                fareEstimateApi(
                  category: "passenger",
                  ref: ref,
                  vehicleTypeId: selectedVehicleId,
                  pickupAddress: pickupLocation?.address ?? "Pickup Location",
                  pickupCoordinates: [
                    pickupLocation!.latitude,
                    pickupLocation.longitude,
                  ],
                  dropAddress: destinationLocation!.address ?? "Destination",
                  dropCoordinates: [
                    destinationLocation.latitude,
                    destinationLocation.longitude,
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
            );
          },
        );

      case RideState.driverConnecting:
        return DriverConnectingUI(
          onRideBooked: () {
            print('🎉 Ride booked successfully!');
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
