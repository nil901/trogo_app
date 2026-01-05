import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:riverpod/src/framework.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:http/http.dart' as http;
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/wigets/choose_ride.dart';
import 'package:trogo_app/wigets/driver_confirm_booking.dart';
import 'package:trogo_app/wigets/pick_up_loaction.dart';
import 'package:trogo_app/wigets/search_drop_loaction.dart';

enum RideState {
  searchDestination,
  pickupDrop,
  chooseRide,
  driverConnecting,
  editPickup,
  editDropoff,
}
class RideHomePage extends ConsumerStatefulWidget {
  final SelectedLocation? currentLocation;

  const RideHomePage({super.key, this.currentLocation});

  @override
  _RideHomePageState createState() => _RideHomePageState();
}

class _RideHomePageState extends ConsumerState<RideHomePage> {
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
  
  // Google Map variables
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _routeCoordinates = [];
  static const String GOOGLE_MAPS_API_KEY = "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";
  PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_MAPS_API_KEY);
  
  void goTo(RideState s) {
    setState(() {
      currentState = s;
    });
    
  
    if (s == RideState.pickupDrop || s == RideState.chooseRide || s == RideState.driverConnecting) {
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
        destinationAddress = "${result['latitude']?.toStringAsFixed(6)}, ${result['longitude']?.toStringAsFixed(6)}";
      });

      Future.delayed(Duration(milliseconds: 300), () {
        goTo(RideState.pickupDrop);
      });
    }
  }

  // --- Google Map Setup ---
  Future<void> _setupMapAndRoute() async {
    _markers.clear();
    _polylines.clear();

    // Default position
    LatLng defaultPosition = LatLng(19.0760, 72.8777); // Mumbai
    
    // Pickup Marker
    if (widget.currentLocation != null) {
      final pickupLatLng = LatLng(
        widget.currentLocation!.latitude!,
        widget.currentLocation!.longitude!,
      );
      _markers.add(
        Marker(
          markerId: MarkerId('pickup'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
      );
      defaultPosition = pickupLatLng;
    }

    // Drop Marker (if destination is selected)
    if (destLatitude != null && destLongitude != null) {
      final dropLatLng = LatLng(destLatitude!, destLongitude!);
      _markers.add(
        Marker(
          markerId: MarkerId('drop'),
          position: dropLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination'),
        ),
      );

      // Create route between pickup and drop if both available
      if (widget.currentLocation != null) {
        await _fetchRoutePolyline();
      }
    }

    setState(() {});
  }

  Future<void> _fetchRoutePolyline() async {
    if (widget.currentLocation == null || destLatitude == null || destLongitude == null) return;

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

  @override
  void initState() {
    super.initState();
    // Initialize map when widget loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMapAndRoute();
    });
  }

@override
Widget build(BuildContext context) {
  LatLng initialPosition = widget.currentLocation != null
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
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController.complete(controller);
              if (_markers.isNotEmpty) {
                _zoomToFitMarkers();
              }
            },
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
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  ),
                ],
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


  Future<void> _zoomToFitMarkers() async {
    if (_markers.isEmpty) return;

    try {
      final controller = await _mapController.future;
      
      LatLngBounds bounds = _calculateBounds(
        _markers.map((marker) => marker.position).toList()
      );
      
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100)
      );
    } catch (e) {
      print('⚠️ Error zooming to markers: $e');
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double? west, south, east, north;
    for (final point in points) {
      west = west == null || point.longitude < west ? point.longitude : west;
      east = east == null || point.longitude > east ? point.longitude : east;
      south = south == null || point.latitude < south ? point.latitude : south;
      north = north == null || point.latitude > north ? point.latitude : north;
    }
    
    // Add some padding
    final padding = 0.01;
    return LatLngBounds(
      southwest: LatLng((south ?? 0) - padding, (west ?? 0) - padding),
      northeast: LatLng((north ?? 0) + padding, (east ?? 0) + padding),
    );
  }

  Widget _topSafetyCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.green.shade100,
            child: Icon(Icons.shield, color: Colors.green, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Make your trip safety first",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Check how we make our customer is more safety",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
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
                destLatitude = selectedData['latitude'] is double
                    ? selectedData['latitude'] as double
                    : double.tryParse(selectedData['latitude'].toString()) ?? 0.0;
                destLongitude = selectedData['longitude'] is double
                    ? selectedData['longitude'] as double
                    : double.tryParse(selectedData['longitude'].toString()) ?? 0.0;
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
          destinationLocation: (destLatitude != null && destLongitude != null)
              ? SelectedLocation(
                  latitude: destLatitude!,
                  longitude: destLongitude!,
                  address: destinationName ?? destinationAddress ?? "Destination",
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
            final destinationLocation = (destLatitude != null && destLongitude != null)
                ? SelectedLocation(
                    latitude: destLatitude!,
                    longitude: destLongitude!,
                    address: destinationName ?? destinationAddress ?? "Destination",
                  )
                : null;

                      if (!isLoadingFare && 
          pickupLocation != null && 
          destinationLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // येथे fareEstimateApi ला डेटा पास करा
          final result = await fareEstimateApi(
            ref: ref,
            vehicleTypeId:"", // हे तुम्हाला कुठून तरी मिळायला हवे
            pickupAddress: pickupLocation.address ?? "Pickup Location",
            pickupCoordinates: [pickupLocation.latitude, pickupLocation.longitude],
            dropAddress: destinationLocation.address ?? "Destination",
            dropCoordinates: [destinationLocation.latitude, destinationLocation.longitude],
          );
          
          // result चा उपयोग करून state update करा
          if (result.isNotEmpty) {
            ref.read(fareEstimateProvider.notifier).state = result;
          }
        });
      }



              return ChooseRideUI(
        onBack: () => goTo(RideState.pickupDrop),
        onSelect: (selectedVehicleName, selectedVehicleId, selectedPrice) {
          // ✅ सर्व 3 parameters process करा
          print('🚗 Vehicle selected in RideHomePage:');
          print('   Name: $selectedVehicleName');
          print('   ID: $selectedVehicleId');
          print('   Price: ₹$selectedPrice');
          
          setState(() {
            this.selectedRide = selectedVehicleName;
            this.selectedVehicleId = selectedVehicleId;
            this.price = selectedPrice; // String मध्ये store करा
          });
          
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
          onRideBooked: () {},
          onBack: () => goTo(RideState.chooseRide),
          rideType: selectedRide,
          price: price?? 250,
          carId: selectedVehicleId,
          pickupLocation: widget.currentLocation,
          dropLocation: SelectedLocation(
            latitude: destLatitude ?? 0.0,
            longitude: destLongitude ?? 0.0,
            address: destinationAddress ?? "Destination not set",
          ),
        
          mapWidget: CommonGoogleMap(
            initialLatLng: widget.currentLocation != null
                ? LatLng(widget.currentLocation!.latitude!, widget.currentLocation!.longitude!)
                : LatLng(19.0760, 72.8777),
            markers: _markers,
            polylines: _polylines,
            height: 250,
            onMapCreated: (controller) {
              // DriverConnectingUI साठी map controller
            },
          ),
        );

      default:
        return SizedBox();
    }
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
            // Map preview
            Expanded(
              flex: 2,
              child: CommonGoogleMap(
                initialLatLng: widget.currentLocation != null
                    ? LatLng(widget.currentLocation!.latitude!, widget.currentLocation!.longitude!)
                    : LatLng(19.0760, 72.8777),
                height: 200,
                markers: {
                  Marker(
                    markerId: MarkerId('edit_pickup'),
                    position: widget.currentLocation != null
                        ? LatLng(widget.currentLocation!.latitude!, widget.currentLocation!.longitude!)
                        : LatLng(19.0760, 72.8777),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  ),
                },
              ),
            ),
            SizedBox(height: 16),
            // Search component
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
                  print('Pickup location selected from search: ${locationData['description']}');
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
            // Map preview
            Expanded(
              flex: 2,
              child: CommonGoogleMap(
                initialLatLng: destLatitude != null && destLongitude != null
                    ? LatLng(destLatitude!, destLongitude!)
                    : LatLng(19.0760, 72.8777),
                height: 200,
                markers: {
                  Marker(
                    markerId: MarkerId('edit_dropoff'),
                    position: destLatitude != null && destLongitude != null
                        ? LatLng(destLatitude!, destLongitude!)
                        : LatLng(19.0760, 72.8777),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                },
              ),
            ),
            SizedBox(height: 16),
            // Search component
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
                  print('Dropoff location selected from search: ${locationData['description']}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

