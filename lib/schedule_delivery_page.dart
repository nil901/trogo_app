import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/goods_details_page.dart';
import 'package:trogo_app/transportergoods/tracking_screen.dart';
// import 'package:trogo_app/goods_details_page.dart' show GoodsDetailsPage;
import 'package:trogo_app/wigets/search_location_screen.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';


// goods_flow_manager.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';


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

  void _handleBookingCreated(String bookingId, Map<String, dynamic> bookingData) {
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
      body: _isRideCompleted
          ? _buildCompletionScreen()
          : _bookingId == null
              ? ScheduleDeliveryPage(
                  onBookingCreated: _handleBookingCreated,
                )
              : GoodsTrackingPage(
                  bookingId: _bookingId!,
                  bookingData: _bookingData!,
                  onRideCompleted: _handleRideCompleted,
                ),
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



// 1. First, update the ScheduleDeliveryPage to accept the callback
class ScheduleDeliveryPage extends ConsumerStatefulWidget {
  final Function(String, Map<String, dynamic>)? onBookingCreated;

  const ScheduleDeliveryPage({
    super.key,
    this.onBookingCreated,
  });

  @override
  ConsumerState<ScheduleDeliveryPage> createState() =>
      _ScheduleDeliveryPageState();
}

class _ScheduleDeliveryPageState extends ConsumerState<ScheduleDeliveryPage> {
  int selectedVehicle = 0;
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
  CameraPosition? initialCameraPosition;

  @override
  void initState() {
    super.initState();

    _setCurrentPickupLocation();
    vehicletypesApi(ref, "goods");
  }

  Future<void> _geocodeAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          deliveryPosition = Position(
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
        });
      }
    } catch (e) {
      print("Geocoding error: $e");
    }
  }

  Future<void> _setCurrentPickupLocation() async {
    try {
      setState(() => isLoadingLocation = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          pickupLocation = "Turn on location services";
          isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          pickupLocation = "Location permission denied";
          isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
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

        setState(() {
          pickupLocation = address.isNotEmpty ? address : "Current Location";
          isLoadingLocation = false;
        });
      }

      // Update map with pickup marker
      _updateMapMarkers();
    } catch (e) {
      print("❌ Error: $e");
      setState(() {
        pickupLocation = "Tap to select location";
        isLoadingLocation = false;
      });
    }
  }

  void _updateMapMarkers() {
    markers.clear();

    // Add pickup marker
    if (currentPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('pickup'),
          position: LatLng(
            currentPosition!.latitude,
            currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Pickup'),
          zIndex: 2,
        ),
      );
    }

    // Add delivery marker if available
    if (deliveryPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('delivery'),
          position: LatLng(
            deliveryPosition!.latitude,
            deliveryPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Delivery'),
          zIndex: 2,
        ),
      );
    }

    // Update camera position if both locations are set
    if (currentPosition != null && deliveryPosition != null) {
      final bounds = _getBounds(currentPosition!, deliveryPosition!);
      final controllerFuture = mapController.future;
      controllerFuture.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      });
    }

    if (mounted) setState(() {});
  }

  LatLngBounds _getBounds(Position pos1, Position pos2) {
    final southwest = LatLng(
      pos1.latitude < pos2.latitude ? pos1.latitude : pos2.latitude,
      pos1.longitude < pos2.longitude ? pos1.longitude : pos2.longitude,
    );
    final northeast = LatLng(
      pos1.latitude > pos2.latitude ? pos1.latitude : pos2.latitude,
      pos1.longitude > pos2.longitude ? pos1.longitude : pos2.longitude,
    );
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  @override
  Widget build(BuildContext context) {
    final transport = ref.watch(vihicletypeProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// BACKGROUND MAP
          if (initialCameraPosition != null)
            GoogleMap(
              initialCameraPosition: initialCameraPosition!,
              onMapCreated: (controller) {
                mapController.complete(controller);
              },
              markers: markers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              compassEnabled: true,
              buildingsEnabled: true,
              trafficEnabled: true,
            )
          else
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.blueGrey.shade50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Loading map...",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

          /// TOP BAR GRADIENT
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

          /// BACK BUTTON
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
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          /// LOCATION INDICATORS ON MAP
          if (currentPosition != null || deliveryPosition != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              child: Container(
                padding: EdgeInsets.all(12),
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
                        SizedBox(width: 8),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.65,
                          child: Text(
                            pickupLocation,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 20,
                      width: 1,
                      color: Colors.grey.shade300,
                      margin: EdgeInsets.only(left: 4),
                    ),
                    SizedBox(height: 12),
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
                        SizedBox(width: 8),
                        Container(
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

          /// BOTTOM SHEET - UBER STYLE
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: [0.45, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    /// HANDLE
                    Container(
                      margin: EdgeInsets.only(top: 12),
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
                        physics: BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),

                              /// TITLE
                              Text(
                                "Schedule Delivery",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Enter pickup and delivery details",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),

                              SizedBox(height: 20),

                              /// LOCATION CARDS
                              _buildLocationCard(
                                context,
                                isPickup: true,
                                location: pickupLocation,
                                isLoading: isLoadingLocation,
                                onTap: () async {
                                  print("📍 Opening pickup location search...");
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

                                  print(
                                    "📍 Pickup result type: ${result.runtimeType}",
                                  );
                                  print("📍 Pickup result value: $result");

                                  if (result != null) {
                                    _processLocationResult(
                                      result,
                                      isPickup: true,
                                    );
                                  }
                                },
                              ),

                              SizedBox(height: 16),

                              _buildLocationCard(
                                context,
                                isPickup: false,
                                location: deliveryLocation,
                                isLoading: false,
                                onTap: () async {
                                  print(
                                    "📍 Opening delivery location search...",
                                  );
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

                                  print(
                                    "📍 Delivery result type: ${result.runtimeType}",
                                  );
                                  print("📍 Delivery result value: $result");

                                  if (result != null) {
                                    _processLocationResult(
                                      result,
                                      isPickup: false,
                                    );
                                  }
                                },
                              ),

                              SizedBox(height: 20),

                              /// DATE & TIME ROW
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
                                  SizedBox(width: 12),
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

                              SizedBox(height: 20),

                              /// VEHICLE TYPE SECTION
                              Text(
                                "Vehicle Type",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),

                              SizedBox(
                                height: 110,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: BouncingScrollPhysics(),
                                  itemCount: transport.length,
                                  itemBuilder: (context, index) {
                                    final vehicle = transport[index];
                                    bool isSelected = selectedVehicle == index;

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => selectedVehicle = index);
                                      },
                                      child: Container(
                                        width: 120,
                                        margin: EdgeInsets.only(right: 12),
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
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              vehicle.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isSelected
                                                        ? Colors.blue.shade700
                                                        : Colors.black87,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "₹${(index + 1) * 50} approx",
                                              style: TextStyle(
                                                fontSize: 11,
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

                              SizedBox(height: 30),

                              /// NEXT BUTTON - Updated to pass callback
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

  // ✅ NEW HELPER FUNCTION: Process location result
  void _processLocationResult(dynamic result, {required bool isPickup}) {
    try {
      // If result is Map (new version with coordinates)
      if (result is Map<String, dynamic>) {
        final address = result['address']?.toString() ?? "Unknown Address";
        final lat = double.tryParse(result['lat'].toString()) ?? 0.0;
        final lng = double.tryParse(result['lng'].toString()) ?? 0.0;

        setState(() {
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
      }
      // If result is String (old version)
      else if (result is String) {
        setState(() {
          if (isPickup) {
            pickupLocation = result;
            // Try to geocode the address for coordinates
            if (result.isNotEmpty && !result.contains("Getting")) {
              _geocodeAddress(result);
            }
          } else {
            deliveryLocation = result;
            // Try to geocode the address for coordinates
            if (result.isNotEmpty) {
              _geocodeAddress(result);
            }
          }
        });
      }

      _updateMapMarkers();
      if (!isPickup && deliveryPosition != null) {
        _getRoutePolyline();
      }
    } catch (e) {
      print("Error processing location result: $e");
      // Fallback: just set the address
      setState(() {
        if (isPickup) {
          pickupLocation = result.toString();
        } else {
          deliveryLocation = result.toString();
        }
      });
    }
  }

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
        padding: EdgeInsets.all(16),
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
            SizedBox(width: 12),
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
                  SizedBox(height: 4),
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
                        SizedBox(width: 8),
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
        padding: EdgeInsets.all(16),
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
                SizedBox(width: 8),
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
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
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

  // ✅ UPDATED NEXT BUTTON WITH CALLBACK PASSING
  Widget _buildNextButton(BuildContext context) {
    bool isReady =
        pickupLocation.isNotEmpty &&
        deliveryLocation.isNotEmpty &&
        !pickupLocation.contains("Getting") &&
        !pickupLocation.contains("Tap to");

    return GestureDetector(
      onTap: isReady
          ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => GoodsDetailsPage(
                          pickupLocation: pickupLocation,
                          deliveryLocation: deliveryLocation,
                          selectedDate: selectedDate,
                          selectedTime: selectedTime,
                          selectedVehicle: selectedVehicle,
                          pickupPosition: currentPosition,
                          deliveryPosition: deliveryPosition,
                          onBookingCreated: widget.onBookingCreated, // Pass callback
                        ),
                  ),
                );
              }
          : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isReady ? Colors.black : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isReady
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
          child: Text(
            "Next →",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isReady ? Colors.white : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _getRoutePolyline() async {
    if (currentPosition == null || deliveryPosition == null) return;

    // Here you would call Google Directions API
    // For now, we'll create a simple straight line
    polylines.clear();
    polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        color: Colors.blue.shade600,
        width: 4,
        points: [
          LatLng(currentPosition!.latitude, currentPosition!.longitude),
          LatLng(deliveryPosition!.latitude, deliveryPosition!.longitude),
        ],
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
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
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedTime) {
      setState(() => selectedTime = picked);
    }
  }
}