// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:http/http.dart' as http;
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:trogo_app/location_permission_screen.dart';
// import 'package:trogo_app/prefs/PreferencesKey.dart';
// import 'package:trogo_app/prefs/app_preference.dart';

// class DriverConnectingUI extends StatefulWidget {
//   final VoidCallback onBack;
//   final String rideType;
//   final String? carId;
//   final SelectedLocation? pickupLocation;
//   final SelectedLocation? dropLocation;
//   final VoidCallback onRideBooked;

//   const DriverConnectingUI({
//     super.key,
//     required this.onBack,
//     required this.rideType,
//     this.pickupLocation,
//     this.dropLocation,
//     this.carId,
//     required this.onRideBooked,
//   });

//   @override
//   _DriverConnectingUIState createState() => _DriverConnectingUIState();
// }

// class _DriverConnectingUIState extends State<DriverConnectingUI> {
//   // --- Timer & State Variables ---
//   int _connectionTime = 0;
//   bool _isConnecting = false;
//   bool _driverFound = false;
//   bool _isRideBooked = false;
//   bool _isSearchStarted = false;
//   Timer? _timer;
//   String? _bookingId;
//   Timer? _driverLocationTimer;

//   // --- Real Driver Info ---
//   final Map<String, dynamic> _driverInfo = {
//     'name': '',
//     'rating': 0.0,
//     'carModel': '',
//     'carNumber': '',
//     'phone': '',
//     'distance': 'Calculating...',
//     'eta': 'Calculating...',
//     'profileImage': '',
//     'transporterId': '',
//     'location': {
//       'coordinates': [0.0, 0.0],
//     },
//   };

//   // --- Google Maps & Polylines Variables ---
//   final Completer<GoogleMapController> _mapController = Completer();
//   Set<Marker> _markers = {};
//   Set<Polyline> _polylines = {};
//   static const String GOOGLE_MAPS_API_KEY =
//       "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";
//   PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_MAPS_API_KEY);
//   List<LatLng> _routeCoordinates = [];

//   // --- Socket.IO Variable ---
//   IO.Socket? _socket;

//   @override
//   void initState() {
//     super.initState();
//     print('📍 Initial Location Data...');
//     print(
//       'Pickup: ${widget.pickupLocation?.latitude}, ${widget.pickupLocation?.longitude}',
//     );
//     print(
//       'Drop: ${widget.dropLocation?.latitude}, ${widget.dropLocation?.longitude}',
//     );

//     _initSocket();
//     Future.delayed(Duration(milliseconds: 300), () {
//       _setupMapAndRoute();
//     });
//   }

//   // --- Socket.IO Initialization ---
//   void _initSocket() {
//     try {
//       _socket = IO.io(
//         'https://trogo-app-backend.onrender.com',
//         IO.OptionBuilder()
//             .setTransports(['websocket', 'polling'])
//             .enableAutoConnect()
//             .setTimeout(30000)
//             .build(),
//       );

//       _socket?.onConnect((_) {
//         print('✅ Socket connected successfully');
//         _socket?.emit('auth', {
//           'token': AppPreference().getString(PreferencesKey.authToken),
//         });

//         if (_bookingId != null) {
//           _socket?.emit('joinBooking', {'bookingId': _bookingId});
//           _socket?.emit('requestDriverLocation', {'bookingId': _bookingId});
//         }
//       });

//       _socket?.onDisconnect((_) {
//         print('⚠️ Socket disconnected');
//         setState(() {
//           _isConnecting = true;
//         });
//       });

//       _socket?.onConnectError((error) {
//         print('❌ Socket connection error: $error');
//       });

//       _socket?.onError((error) {
//         print('🔥 Socket error: $error');
//       });

//       // SOCKET EVENTS
//       _socket?.on('driverAssigned', (data) {
//         print('🚗 Driver assigned via socket: $data');
//         if (data is Map) {
//           _handleDriverUpdate(data);
//           _startDriverLocationUpdates();
//         }
//       });

//       _socket?.on('driverLocationUpdate', (data) {
//         print('📍 Driver location via socket: $data');
//         if (data is Map) {
//           _handleDriverLocationUpdate(data);
//         }
//       });

//       _socket?.on('driverLocationResponse', (data) {
//         print('📡 Driver location response: $data');
//         if (data is Map) {
//           _handleDriverLocationUpdate(data);
//         }
//       });

//       _socket?.on('rideStatus', (data) {
//         print('🔄 Ride status update: $data');
//         _handleRideStatusUpdate(data);
//       });

//       _socket?.on('driverUpdate', (data) {
//         print('👤 Driver update via socket: $data');
//         if (data is Map && data['driver'] != null) {
//           _handleDriverUpdate(data);
//         }
//       });

//       _socket?.connect();
//     } catch (e) {
//       print('🔥 Socket initialization error: $e');
//     }
//   }

//   // --- Google Map Setup ---
//   Future<void> _setupMapAndRoute() async {
//     LatLng? initialPoint;
//     _markers.clear();
//     _polylines.clear();

//     // Pickup Marker
//     if (widget.pickupLocation != null) {
//       final pickupLatLng = LatLng(
//         widget.pickupLocation!.latitude!,
//         widget.pickupLocation!.longitude!,
//       );
//       _markers.add(
//         Marker(
//           markerId: MarkerId('pickup'),
//           position: pickupLatLng,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueGreen,
//           ),
//           infoWindow: InfoWindow(title: 'Pickup'),
//         ),
//       );
//       initialPoint = pickupLatLng;
//     }

//     // Drop Marker
//     if (widget.dropLocation != null) {
//       final dropLatLng = LatLng(
//         widget.dropLocation!.latitude!,
//         widget.dropLocation!.longitude!,
//       );
//       _markers.add(
//         Marker(
//           markerId: MarkerId('drop'),
//           position: dropLatLng,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//           infoWindow: InfoWindow(title: 'Destination'),
//         ),
//       );

//       if (widget.pickupLocation != null) {
//         await _fetchRoutePolyline();
//       }
//       if (initialPoint == null) initialPoint = dropLatLng;
//     }

//     setState(() {});

//     if (initialPoint != null) {
//       final controller = await _mapController.future;
//       controller.animateCamera(CameraUpdate.newLatLngZoom(initialPoint, 14));
//     }
//   }

//   Future<void> _fetchRoutePolyline() async {
//     if (widget.pickupLocation == null || widget.dropLocation == null) return;

//     try {
//       PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
//         request: PolylineRequest(
//           origin: PointLatLng(
//             widget.pickupLocation!.latitude!,
//             widget.pickupLocation!.longitude!,
//           ),
//           destination: PointLatLng(
//             widget.dropLocation!.latitude!,
//             widget.dropLocation!.longitude!,
//           ),
//           mode: TravelMode.driving,
//         ),
//       );

//       if (result.points.isNotEmpty) {
//         _routeCoordinates.clear();

//         for (var point in result.points) {
//           _routeCoordinates.add(LatLng(point.latitude, point.longitude));
//         }

//         final polyline = Polyline(
//           polylineId: const PolylineId('route'),
//           color: const Color(0xFF1a73e8),
//           width: 5,
//           geodesic: true,
//           points: _routeCoordinates,
//         );

//         setState(() {
//           _polylines.clear();
//           _polylines.add(polyline);
//         });

//         _zoomToRoute();
//       } else {
//         print('❌ No route points found: ${result.errorMessage}');
//       }
//     } catch (e) {
//       print('🔥 Error fetching route: $e');
//     }
//   }

//   Future<void> _zoomToRoute() async {
//     if (_routeCoordinates.isEmpty) return;
//     final controller = await _mapController.future;
//     final bounds = _calculateBounds(_routeCoordinates);
//     await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
//   }

//   LatLngBounds _calculateBounds(List<LatLng> points) {
//     double? west, south, east, north;
//     for (final point in points) {
//       west = west == null || point.longitude < west ? point.longitude : west;
//       east = east == null || point.longitude > east ? point.longitude : east;
//       south = south == null || point.latitude < south ? point.latitude : south;
//       north = north == null || point.latitude > north ? point.latitude : north;
//     }
//     return LatLngBounds(
//       southwest: LatLng(south ?? 0, west ?? 0),
//       northeast: LatLng(north ?? 0, east ?? 0),
//     );
//   }

//   // --- Driver Location Handlers ---
//   void _handleDriverUpdate(dynamic data) {
//     print('🔄 Processing driver update: $data');

//     if (data is Map) {
//       Map<String, dynamic> driverData = {};

//       // Check for different response formats
//       if (data['driver'] != null) {
//         driverData = data['driver'];
//       } else if (data['name'] != null) {
//         // Direct API response format
//         driverData = data as Map<String, dynamic>;
//       }

//       if (driverData.isNotEmpty) {
//         setState(() {
//           _driverInfo['name'] = driverData['name'] ?? 'Driver';
//           _driverInfo['rating'] = (driverData['rating'] ?? 4.5).toDouble();
//           _driverInfo['phone'] =
//               driverData['mobile'] ?? driverData['phone'] ?? '';
//           _driverInfo['profileImage'] = driverData['profileImage'] ?? '';
//           _driverInfo['transporterId'] = driverData['transporterId'] ?? '';
//           _driverInfo['carModel'] = driverData['carModel'] ?? 'Car';
//           _driverInfo['carNumber'] = driverData['carNumber'] ?? '';

//           // Handle location data
//           if (driverData['location'] != null) {
//             _driverInfo['location'] = driverData['location'];

//             // Update ETA based on location
//             if (driverData['location']['coordinates'] is List &&
//                 widget.pickupLocation != null) {
//               List<dynamic> coords = driverData['location']['coordinates'];
//               if (coords.length >= 2) {
//                 final lat = coords[1]?.toDouble() ?? 0.0;
//                 final lng = coords[0]?.toDouble() ?? 0.0;

//                 final distance = _calculateDistance(
//                   lat,
//                   lng,
//                   widget.pickupLocation!.latitude!,
//                   widget.pickupLocation!.longitude!,
//                 );
//                 _driverInfo['distance'] =
//                     '${distance.toStringAsFixed(1)} km away';
//                 _driverInfo['eta'] = '${_calculateETA(distance)} min';

//                 // Update driver marker on map
//                 _updateDriverMarkerOnMap(lat, lng);
//               }
//             }
//           }

//           _driverFound = true;
//           _isConnecting = false;
//         });

//         print('✅ Driver info updated from API');
//         print('   Name: ${_driverInfo['name']}');
//         print('   Phone: ${_driverInfo['phone']}');
//         print('   Location: ${_driverInfo['location']['coordinates']}');

//         // Start real-time updates
//         _startDriverLocationUpdates();
//       }
//     }
//   }

//   void _updateDriverMarkerOnMap(double lat, double lng) {
//     final driverLatLng = LatLng(lat, lng);

//     setState(() {
//       _markers.removeWhere((m) => m.markerId.value == 'driver');
//       _markers.add(
//         Marker(
//           markerId: MarkerId('driver'),
//           position: driverLatLng,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueAzure,
//           ),
//           rotation: 0.0,
//           flat: true,
//           infoWindow: InfoWindow(
//             title: 'Driver: ${_driverInfo['name']}',
//             snippet: 'ETA: ${_driverInfo['eta']}',
//           ),
//           anchor: Offset(0.5, 0.5),
//         ),
//       );
//     });

//     // Move camera to show driver
//     _moveCameraToDriver(driverLatLng);
//   }

//   void _handleDriverLocationUpdate(dynamic data) {
//     if (data is Map) {
//       print('📍 Processing driver location: $data');

//       dynamic? lat, lng;

//       if (data['location'] != null && data['location']['coordinates'] is List) {
//         List<dynamic> coords = data['location']['coordinates'];
//         if (coords.length >= 2) {
//           lat = coords[1]?.toDouble();
//           lng = coords[0]?.toDouble();
//         }
//       } else if (data['latitude'] != null && data['longitude'] != null) {
//         lat = data['latitude']?.toDouble();
//         lng = data['longitude']?.toDouble();
//       } else if (data['location']?['lat'] != null &&
//           data['location']?['lng'] != null) {
//         lat = data['location']['lat']?.toDouble();
//         lng = data['location']['lng']?.toDouble();
//       }

//       if (lat != null && lng != null) {
//         final driverLatLng = LatLng(lat, lng);
//         final bearing =
//             data['bearing']?.toDouble() ?? data['heading']?.toDouble() ?? 0.0;

//         setState(() {
//           _markers.removeWhere((m) => m.markerId.value == 'driver');
//           _markers.add(
//             Marker(
//               markerId: MarkerId('driver'),
//               position: driverLatLng,
//               icon: BitmapDescriptor.defaultMarkerWithHue(
//                 BitmapDescriptor.hueAzure,
//               ),
//               rotation: bearing,
//               flat: true,
//               infoWindow: InfoWindow(
//                 title: 'Driver: ${_driverInfo['name']}',
//                 snippet: 'ETA: ${_driverInfo['eta']}',
//               ),
//               anchor: Offset(0.5, 0.5),
//             ),
//           );

//           if (widget.pickupLocation != null) {
//             final distance = _calculateDistance(
//               lat,
//               lng,
//               widget.pickupLocation!.latitude!,
//               widget.pickupLocation!.longitude!,
//             );
//             _driverInfo['distance'] = '${distance.toStringAsFixed(1)} km away';
//             _driverInfo['eta'] = '${_calculateETA(distance)} min';
//           }

//           if (_driverFound && !_isRideBooked) {
//             _moveCameraToDriver(driverLatLng);
//           }
//         });

//         print('✅ Driver location updated: $lat, $lng');
//       }
//     }
//   }

//   void _handleRideStatusUpdate(dynamic data) {
//     if (data is Map) {
//       print('🔄 Ride status: ${data['status']}');
//       if (data['status'] == 'completed' || data['status'] == 'cancelled') {
//         _timer?.cancel();
//         _driverLocationTimer?.cancel();
//         widget.onRideBooked();
//       }
//     }
//   }

//   // --- Distance & ETA Calculations ---
//   double _calculateDistance(
//     double lat1,
//     double lon1,
//     double lat2,
//     double lon2,
//   ) {
//     const R = 6371e3;
//     final phi1 = lat1 * pi / 180;
//     final phi2 = lat2 * pi / 180;
//     final deltaPhi = (lat2 - lat1) * pi / 180;
//     final deltaLambda = (lon2 - lon1) * pi / 180;

//     final a =
//         sin(deltaPhi / 2) * sin(deltaPhi / 2) +
//         cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
//     final c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return R * c / 1000;
//   }

//   int _calculateETA(double distanceKm) => max((distanceKm * 2.5).ceil(), 2);

//   // --- Driver Location Updates via Socket ---
//   void _startDriverLocationUpdates() {
//     _driverLocationTimer?.cancel();

//     print('🚀 Starting real-time location updates via socket');

//     if (_socket?.connected == true && _bookingId != null) {
//       _socket?.emit('getDriverLocation', {
//         'bookingId': _bookingId,
//         'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
//       });
//     }

//     // Start polling API every 5 seconds for updates
//     _driverLocationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
//       if (_bookingId != null && _driverFound) {
//         _fetchDriverInfoFromAPI();
//       }
//     });
//   }

//   // --- NEW: Fetch Driver Info from API ---
//   Future<void> _fetchDriverInfoFromAPI() async {
//     if (_bookingId == null) return;

//     try {
//       print('🚗 Fetching driver info for booking: $_bookingId');

//       final response = await http.get(
//         Uri.parse(
//           'https://trogo-app-backend.onrender.com/api/bookings/$_bookingId/transporter-location',
//         ),
//         headers: {
//           'Authorization':
//               'Bearer ${AppPreference().getString(PreferencesKey.authToken)}',
//         },
//       );

//       print('📡 Driver API Response: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final driverData = json.decode(response.body);
//         print('✅ Driver info received from API');

//         // Process the API response data
//         _handleDriverUpdate(driverData);
//       } else {
//         print('❌ Failed to fetch driver info: ${response.statusCode}');
//       }
//     } catch (error) {
//       print('🔥 Error fetching driver info: $error');
//     }
//   }

//   // --- Connection Timer ---
//   void _startConnectionTimer() {
//     _connectionTime = 0;
//     _isSearchStarted = true;

//     _timer = Timer.periodic(Duration(seconds: 1), (timer) {
//       setState(() {
//         _connectionTime++;
//       });

//       if (_socket?.connected == true && _bookingId != null) {
//         _socket?.emit('requestLocation', {
//           'bookingId': _bookingId,
//           'timestamp': DateTime.now().millisecondsSinceEpoch,
//         });
//       }

//       // Check for driver after 3 seconds
//       if (_connectionTime >= 3 && !_driverFound && _bookingId != null) {
//         _fetchDriverInfoFromAPI();
//       }

//       // Auto-simulate after 10 seconds if still no driver (for testing only - comment out in production)
//       if (_connectionTime >= 10 && !_driverFound && kDebugMode) {
//         print(
//           '🕐 Test mode: Would simulate driver assignment after 10 seconds',
//         );
//         // _simulateDriverAssignment(); // Comment this out in production
//       }
//     });
//   }

//   // --- Simulate Driver Assignment (for testing only - comment out in production) ---
//   void _simulateDriverAssignment() {
//     if (!_driverFound) {
//       print('🎯 Test mode: Simulating driver assignment');

//       // This is only for testing - in production, remove this function
//       final testData = {
//         'name': 'Test Driver',
//         'mobile': '+91 9876543210',
//         'profileImage': '',
//         'transporterId': 'test_123',
//         'location': {
//           'type': 'Point',
//           'coordinates': [73.7898, 19.9974],
//         },
//       };

//       _handleDriverUpdate(testData);
//     }
//   }

//   Future<void> _moveCameraToDriver(LatLng driverLatLng) async {
//     try {
//       final controller = await _mapController.future;
//       await controller.animateCamera(CameraUpdate.newLatLng(driverLatLng));
//     } catch (e) {
//       print('⚠️ Error moving camera: $e');
//     }
//   }

//   void _simulateDriverSearch() {
//     Future.delayed(Duration(milliseconds: 500), () {
//       setState(() {
//         _isConnecting = true;
//       });
//     });
//   }

//   // --- Ride Booking ---
//   void _bookRide() async {
//     if (!_isSearchStarted) {
//       setState(() {
//         _isConnecting = true;
//         _isSearchStarted = true;
//       });

//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Searching for driver...')));

//       String? tokens = AppPreference().getString(PreferencesKey.authToken);

//       try {
//         List<double> pickupCoords = [
//           widget.pickupLocation?.longitude ?? 0.0,
//           widget.pickupLocation?.latitude ?? 0.0,
//         ];

//         List<double> dropCoords = [
//           widget.dropLocation?.longitude ?? 0.0,
//           widget.dropLocation?.latitude ?? 0.0,
//         ];

//         final response = await http.post(
//           Uri.parse(
//             'https://trogo-app-backend.onrender.com/api/bookings/bookings',
//           ),
//           headers: {
//             'Content-Type': 'application/json',
//             'Authorization': 'Bearer $tokens',
//           },
//           body: json.encode({
//             "bookingType": "passenger",
//             "vehicleTypeId": widget.carId ?? "",
//             "pickup": {
//               "address": widget.pickupLocation?.address ?? "Pickup location",
//               "coordinates": pickupCoords,
//             },
//             "drop": {
//               "address": widget.dropLocation?.address ?? "Drop location",
//               "coordinates": dropCoords,
//             },
//           }),
//         );

//         print('📡 Booking API Response Status: ${response.statusCode}');
//         print('📡 Booking API Response Body: ${response.body}');

//         if (response.statusCode == 200 || response.statusCode == 201) {
//           final responseData = json.decode(response.body);
//           print('✅ Booking successful!');

//           // Extract booking ID (adjust based on your API response structure)
//           if (responseData['booking'] != null &&
//               responseData['booking']['_id'] != null) {
//             _bookingId = responseData['booking']['_id'];
//           } else if (responseData['_id'] != null) {
//             _bookingId = responseData['_id'];
//           } else if (responseData['data'] != null &&
//               responseData['data']['_id'] != null) {
//             _bookingId = responseData['data']['_id'];
//           }

//           if (_bookingId != null) {
//             print('📋 Booking ID: $_bookingId');

//             // Join socket room
//             if (_socket?.connected == true) {
//               _socket?.emit('joinBooking', {'bookingId': _bookingId});
//               _socket?.emit('requestDriver', {'bookingId': _bookingId});
//             } else {
//               _socket?.connect();
//             }

//             // Start connection timer
//             _startConnectionTimer();
//             _simulateDriverSearch();

//             // Fetch driver info immediately
//             Future.delayed(Duration(seconds: 2), () {
//               _fetchDriverInfoFromAPI();
//             });

//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Booking confirmed! Searching for driver...'),
//               ),
//             );
//           } else {
//             print('❌ Could not extract booking ID from response');
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   'Booking successful but could not get booking ID',
//                 ),
//                 backgroundColor: Colors.orange,
//               ),
//             );
//           }
//         } else {
//           setState(() {
//             _isConnecting = false;
//             _isSearchStarted = false;
//           });

//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Booking failed. Status: ${response.statusCode}'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       } catch (error) {
//         print('🔥 Network/API Error: $error');

//         setState(() {
//           _isConnecting = false;
//           _isSearchStarted = false;
//         });

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Network error: $error'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   // --- Fetch Driver Location (Manual/Socket version) ---
//   Future<void> _fetchDriverLocation() async {
//     print('🔄 Manual driver location fetch requested');

//     if (_socket?.connected == true && _bookingId != null) {
//       _socket?.emit('requestDriverLocation', {
//         'bookingId': _bookingId,
//         'requestTime': DateTime.now().toIso8601String(),
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Requesting driver location via socket...')),
//       );
//     } else if (_bookingId != null) {
//       print('⚠️ Socket not connected, using HTTP API');
//       try {
//         final response = await http.get(
//           Uri.parse(
//             'https://trogo-app-backend.onrender.com/api/bookings/$_bookingId/transporter-location',
//           ),
//           headers: {
//             'Authorization':
//                 'Bearer ${AppPreference().getString(PreferencesKey.authToken)}',
//           },
//         );

//         if (response.statusCode == 200) {
//           final data = json.decode(response.body);
//           _handleDriverUpdate(data);

//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Driver location updated from API')),
//           );
//         } else {
//           print('❌ HTTP API failed: ${response.statusCode}');
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'Failed to get driver location: ${response.statusCode}',
//               ),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//       } catch (error) {
//         print('❌ HTTP API error: $error');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
//         );
//       }
//     } else {
//       print('❌ No booking ID available');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Please book a ride first')));
//     }
//   }

//   void _completeRideBooking() {
//     if (!_isRideBooked) {
//       setState(() {
//         _isRideBooked = true;
//       });
//       _timer?.cancel();
//       _driverLocationTimer?.cancel();
//       print('🎉 Ride booking completed!');
//       Future.delayed(Duration(seconds: 1), widget.onRideBooked);
//     }
//   }

//   void _cancelRide() {
//     print('❌ Ride cancelled by user');

//     _timer?.cancel();
//     _driverLocationTimer?.cancel();

//     if (_socket?.connected == true && _bookingId != null) {
//       _socket?.emit('cancelRide', {'bookingId': _bookingId});
//     }

//     setState(() {
//       _isSearchStarted = false;
//       _isConnecting = false;
//       _driverFound = false;
//       _isRideBooked = false;
//       _bookingId = null;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Ride cancelled'), backgroundColor: Colors.red),
//     );
//     widget.onBack();
//   }

//   void _callDriver() {
//     if (!_driverFound) {
//       print('📞 Cannot call driver: Driver not found yet');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Driver not found yet'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     print('📞 Calling driver: ${_driverInfo['name']}');
//     print('   Phone: ${_driverInfo['phone']}');

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Calling ${_driverInfo['name']}...')),
//     );
//   }

//   void _messageDriver() {
//     if (!_driverFound) {
//       print('💬 Cannot message driver: Driver not found yet');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Driver not found yet'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     print('💬 Opening chat with driver: ${_driverInfo['name']}');

//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text('Opening chat with driver...')));
//   }

//   void _confirmDriver() {
//     if (_driverFound && !_isRideBooked) {
//       print('✅ User confirmed driver: ${_driverInfo['name']}');

//       if (_socket?.connected == true && _bookingId != null) {
//         _socket?.emit('confirmDriver', {
//           'bookingId': _bookingId,
//           'confirmed': true,
//         });
//       }

//       _completeRideBooking();
//     } else {
//       print('⚠️ Cannot confirm driver: Driver not found or already booked');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Cannot confirm driver'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _driverLocationTimer?.cancel();
//     _socket?.disconnect();
//     _socket?.clearListeners();
//     super.dispose();
//   }

//   // --- UI Build Method ---
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // -------- HEADER --------
//         Row(
//           children: [
//             GestureDetector(
//               onTap: widget.onBack,
//               child: CircleAvatar(
//                 backgroundColor: Colors.grey.shade200,
//                 child: Icon(Icons.arrow_back, color: Colors.black),
//               ),
//             ),
//             SizedBox(width: 12),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _isSearchStarted
//                       ? (_driverFound ? "Driver Found!" : "Finding your driver")
//                       : "Confirm your ride",
//                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
//                 ),
//                 SizedBox(height: 3),
//                 Text(
//                   _isSearchStarted
//                       ? (_driverFound
//                           ? "${_driverInfo['name'].isNotEmpty ? _driverInfo['name'] : 'Driver'} is on the way"
//                           : "Searching for nearby drivers...")
//                       : "Review details and book your ride",
//                   style: TextStyle(fontSize: 10, color: Colors.grey),
//                 ),
//               ],
//             ),
//           ],
//         ),

//         SizedBox(height: 20),

//         // -------- DEBUG INFO --------
//         if (kDebugMode)
//           Container(
//             padding: EdgeInsets.all(10),
//             margin: EdgeInsets.only(bottom: 10),
//             decoration: BoxDecoration(
//               color: Colors.blue.shade50,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.blue.shade200),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.bug_report, size: 12, color: Colors.blue),
//                     SizedBox(width: 4),
//                     Text(
//                       'Debug Info',
//                       style: TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.blue,
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 6),
//                 Text(
//                   'Socket: ${_socket?.connected == true ? "Connected" : "Disconnected"}',
//                   style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
//                 ),
//                 SizedBox(height: 2),
//                 Text(
//                   'Booking ID: ${_bookingId ?? "Not created"}',
//                   style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
//                 ),
//                 SizedBox(height: 2),
//                 Text(
//                   'Driver Found: $_driverFound',
//                   style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
//                 ),
//                 SizedBox(height: 2),
//                 Text(
//                   'Time: $_connectionTime s',
//                   style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
//                 ),
//                 if (_driverFound) SizedBox(height: 2),
//                 Text(
//                   'Driver: ${_driverInfo['name']}',
//                   style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
//                 ),
//               ],
//             ),
//           ),

//         // -------- GOOGLE MAP --------
//         Container(
//           height: 250,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black12,
//                 blurRadius: 6,
//                 offset: Offset(0, 3),
//               ),
//             ],
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(16),
//             child: GoogleMap(
//               onMapCreated: (controller) {
//                 _mapController.complete(controller);
//               },
//               initialCameraPosition: CameraPosition(
//                 target:
//                     widget.pickupLocation != null
//                         ? LatLng(
//                           widget.pickupLocation!.latitude!,
//                           widget.pickupLocation!.longitude!,
//                         )
//                         : LatLng(19.9974, 73.7898),
//                 zoom: 14,
//               ),
//               markers: _markers,
//               polylines: _polylines,
//               myLocationEnabled: true,
//               myLocationButtonEnabled: true,
//               compassEnabled: true,
//               zoomControlsEnabled: false,
//               mapType: MapType.normal,
//             ),
//           ),
//         ),
  
//         SizedBox(height: 20),

//         // -------- CONNECTION STATUS --------
//         if (_isConnecting && !_driverFound)
//           Column(
//             children: [
//               SizedBox(
//                 height: 100,
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(
//                         Colors.green.shade700,
//                       ),
//                       strokeWidth: 3,
//                     ),
//                     Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.local_taxi,
//                           size: 34,
//                           color: Colors.green.shade700,
//                         ),
//                         SizedBox(height: 8),
//                         Text(
//                           '$_connectionTime s',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.green.shade700,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               SizedBox(height: 10),
//               // FIXED: InkWell replaced with GestureDetector
//               GestureDetector(
//                 onTap: () {
//                   print("DEBUG: Manual driver location fetch");
//                   _fetchDriverLocation();
//                 },
//                 child: Container(
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.blue.shade200, width: 1),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.refresh, size: 14, color: Colors.blue),
//                       SizedBox(width: 6),
//                       Text(
//                         _socket?.connected == true
//                             ? "Searching for driver... (Tap to refresh)"
//                             : "Connecting to server... (Tap to retry)",
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.blue.shade800,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           )
//         else if (_driverFound && !_isRideBooked)
//           _buildDriverInfoCard(),

//         SizedBox(height: 20),

//         // -------- PICKUP/DROP TIMELINE --------
//         Container(
//           padding: EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.grey.shade50,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey.shade300),
//           ),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Column(
//                 children: [
//                   Icon(Icons.circle, size: 14, color: Colors.green.shade700),
//                   Container(width: 2, height: 40, color: Colors.green.shade200),
//                   Icon(
//                     Icons.circle_outlined,
//                     size: 14,
//                     color: Colors.red.shade400,
//                   ),
//                 ],
//               ),
//               SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       widget.pickupLocation?.address ?? "Pickup location",
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         fontSize: 11,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       widget.dropLocation?.address ?? "Drop location",
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         fontSize: 11,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),

//         SizedBox(height: 20),

//         // -------- RIDE DETAILS --------
//         Container(
//           padding: EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey.shade300),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black12,
//                 blurRadius: 4,
//                 offset: Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     "Ride Type",
//                     style: TextStyle(fontSize: 11, color: Colors.grey),
//                   ),
//                   Text(
//                     widget.rideType,
//                     style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     "Estimated Fare",
//                     style: TextStyle(fontSize: 11, color: Colors.grey),
//                   ),
//                   Text(
//                     "₹295",
//                     style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     "Payment",
//                     style: TextStyle(fontSize: 11, color: Colors.grey),
//                   ),
//                   Row(
//                     children: [
//                       Icon(Icons.credit_card, size: 14, color: Colors.green),
//                       SizedBox(width: 4),
//                       Text(
//                         "Cash",
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),

//         SizedBox(height: 20),

//         // -------- ACTION BUTTONS --------
//         if (_driverFound && !_isRideBooked)
//           Column(
//             children: [
//               Row(
//                 children: [
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: _callDriver,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         padding: EdgeInsets.symmetric(vertical: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                       icon: Icon(Icons.call, size: 16),
//                       label: Text(
//                         "Call Driver",
//                         style: TextStyle(fontSize: 12),
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: _messageDriver,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue,
//                         padding: EdgeInsets.symmetric(vertical: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                       icon: Icon(Icons.message, size: 16),
//                       label: Text("Message", style: TextStyle(fontSize: 12)),
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 10),
//               ElevatedButton(
//                 onPressed: _confirmDriver,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green.shade700,
//                   minimumSize: Size(double.infinity, 55),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.check_circle, color: Colors.white, size: 20),
//                     SizedBox(width: 8),
//                     Text(
//                       "Confirm Driver",
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           )
//         else if (_isRideBooked)
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.green.shade50,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.green.shade300),
//             ),
//             child: Row(
//               children: [
//                 Icon(Icons.check_circle, color: Colors.green, size: 24),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Ride Booked Successfully!",
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w700,
//                           color: Colors.green.shade800,
//                         ),
//                       ),
//                       Text(
//                         "Your driver will arrive in ${_driverInfo['eta']}",
//                         style: TextStyle(
//                           fontSize: 10,
//                           color: Colors.green.shade600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//         SizedBox(height: 10),

//         // -------- MAIN BOOK BUTTON --------
//         if (!_isSearchStarted && !_isRideBooked)
//           ElevatedButton(
//             onPressed: _bookRide,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.black,
//               minimumSize: Size(double.infinity, 55),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.local_taxi_outlined, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Text(
//                   "Confirm & Book Ride",
//                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                 ),
//               ],
//             ),
//           ),

//         // -------- CANCEL BUTTON --------
//         if (!_isRideBooked)
//           TextButton(
//             onPressed: _cancelRide,
//             child: Text(
//               _isSearchStarted ? "Cancel Search" : "Cancel",
//               style: TextStyle(color: Colors.red, fontSize: 12),
//             ),
//           ),

//         // -------- SAFETY TIP --------
//         SizedBox(height: 15),
//         Container(
//           padding: EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.orange.shade50,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.security, color: Colors.orange, size: 16),
//               SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   "Verify driver name and vehicle before boarding",
//                   style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
//                 ),
//               ),
//             ],
//           ),
//         ),

//         // -------- DEBUG BUTTON --------
//         if (kDebugMode)
//           Padding(
//             padding: EdgeInsets.only(top: 10),
//             child: GestureDetector(
//               onTap: () {
//                 print('🔍 SOCKET DEBUG INFO');
//                 print('   Connected: ${_socket?.connected}');
//                 print('   Booking ID: $_bookingId');
//                 print('   Driver Found: $_driverFound');
//                 print('   Connection Time: $_connectionTime');
//                 print('   Driver Name: ${_driverInfo['name']}');
//                 print('   Driver Phone: ${_driverInfo['phone']}');

//                 if (_socket?.connected == true) {
//                   _socket?.emit('testPing', {'message': 'Hello from client'});
//                   print('   Test ping sent');
//                 }
//               },
//               child: Container(
//                 padding: EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.shade100,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.orange),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.bug_report, size: 14, color: Colors.orange),
//                     SizedBox(width: 6),
//                     Text(
//                       'Socket Debug',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.orange.shade800,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   // --- Driver Info Card Widget ---
//   Widget _buildDriverInfoCard() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.green.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.green.shade300),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 28,
//             backgroundColor: Colors.green.shade100,
//             backgroundImage:
//                 _driverInfo['profileImage']?.isNotEmpty == true
//                     ? NetworkImage(_driverInfo['profileImage'])
//                     : null,
//             child:
//                 _driverInfo['profileImage']?.isNotEmpty == true
//                     ? null
//                     : Icon(
//                       Icons.person,
//                       size: 30,
//                       color: Colors.green.shade700,
//                     ),
//           ),
//           SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Text(
//                       _driverInfo['name'].isNotEmpty
//                           ? _driverInfo['name']
//                           : 'Driver',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     SizedBox(width: 8),
//                     Row(
//                       children: [
//                         Icon(Icons.star, size: 14, color: Colors.orange),
//                         SizedBox(width: 2),
//                         Text(
//                           _driverInfo['rating'].toStringAsFixed(1),
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 4),
//                 if (_driverInfo['carModel']?.isNotEmpty == true)
//                   Text(
//                     _driverInfo['carModel'],
//                     style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
//                   ),
//                 if (_driverInfo['carNumber']?.isNotEmpty == true)
//                   Text(
//                     _driverInfo['carNumber'],
//                     style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
//                   ),
//                 SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(Icons.location_on, size: 12, color: Colors.green),
//                     SizedBox(width: 4),
//                     Text(
//                       _driverInfo['distance'],
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.green.shade700,
//                       ),
//                     ),
//                     SizedBox(width: 12),
//                     Icon(Icons.timer, size: 12, color: Colors.blue),
//                     SizedBox(width: 4),
//                     Text(
//                       "ETA: ${_driverInfo['eta']}",
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.blue.shade700,
//                       ),
//                     ),
//                   ],
//                 ),
//                 if (_driverInfo['phone']?.isNotEmpty == true)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 4),
//                     child: Text(
//                       "📱 ${_driverInfo['phone']}",
//                       style: TextStyle(fontSize: 10, color: Colors.grey),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




// class CommonGoogleMap extends StatelessWidget {
//   final LatLng initialLatLng;
//   final Set<Marker> markers;
//   final Set<Polyline> polylines;
//   final double height;
//   final void Function(GoogleMapController)? onMapCreated;

//   const CommonGoogleMap({
//     super.key,
//     required this.initialLatLng,
//     this.markers = const {},
//     this.polylines = const {},
//     this.height = 250,
//     this.onMapCreated,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: height,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: const [
//           BoxShadow(
//             color: Colors.black12,
//             blurRadius: 6,
//             offset: Offset(0, 3),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(16),
//         child: GoogleMap(
//           onMapCreated: onMapCreated,
//           initialCameraPosition: CameraPosition(
//             target: initialLatLng,
//             zoom: 14,
//           ),
//           markers: markers,
//           polylines: polylines,
//           myLocationEnabled: true,
//           myLocationButtonEnabled: true,
//           compassEnabled: true,
//           zoomControlsEnabled: false,
//           mapType: MapType.normal,
//         ),
//       ),
//     );
//   }
// }


import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class DriverConnectingUI extends StatefulWidget {
  final VoidCallback onBack;
  final String rideType;
  final String? carId;
  final int? price;
  final SelectedLocation? pickupLocation;
  final SelectedLocation? dropLocation;
  final VoidCallback onRideBooked;
  final Widget? mapWidget; 
  const DriverConnectingUI({
    super.key,
    required this.onBack,
    required this.rideType,
    required this.price,
    this.pickupLocation,
    this.dropLocation,
    this.carId,
    required this.onRideBooked,
    this.mapWidget, // नवीन parameter
  });

  @override
  _DriverConnectingUIState createState() => _DriverConnectingUIState();
}

class _DriverConnectingUIState extends State<DriverConnectingUI> {
  // --- Timer & State Variables ---
  int _connectionTime = 0;
  bool _isConnecting = false;
  bool _driverFound = false;
  bool _isRideBooked = false;
  bool _isSearchStarted = false;
  Timer? _timer;
  String? _bookingId;
  Timer? _driverLocationTimer;

  // --- Real Driver Info ---
  final Map<String, dynamic> _driverInfo = {
    'name': '',
    'rating': 0.0,
    'carModel': '',
    'carNumber': '',
    'phone': '',
    'distance': 'Calculating...',
    'eta': 'Calculating...',
    'profileImage': '',
    'transporterId': '',
    'location': {
      'coordinates': [0.0, 0.0],
    },
  };

  // --- Google Maps & Polylines Variables ---
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  static const String GOOGLE_MAPS_API_KEY = "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";
  PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_MAPS_API_KEY);
  List<LatLng> _routeCoordinates = [];

  // --- Socket.IO Variable ---
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    print('📍 Initial Location Data...');
    print('Pickup: ${widget.pickupLocation?.latitude}, ${widget.pickupLocation?.longitude}');
    print('Drop: ${widget.dropLocation?.latitude}, ${widget.dropLocation?.longitude}');

    _initSocket();
    Future.delayed(Duration(milliseconds: 300), () {
      _setupMapAndRoute();
    });
  }

  // --- Socket.IO Initialization ---
  void _initSocket() {
    try {
      _socket = IO.io(
        'https://trogo-app-backend.onrender.com',
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .setTimeout(30000)
            .build(),
      );

      _socket?.onConnect((_) {
        print('✅ Socket connected successfully');
        _socket?.emit('auth', {
          'token': AppPreference().getString(PreferencesKey.authToken),
        });

        if (_bookingId != null) {
          _socket?.emit('joinBooking', {'bookingId': _bookingId});
          _socket?.emit('requestDriverLocation', {'bookingId': _bookingId});
        }
      });

      _socket?.onDisconnect((_) {
        print('⚠️ Socket disconnected');
        setState(() {
          _isConnecting = true;
        });
      });

      _socket?.onConnectError((error) {
        print('❌ Socket connection error: $error');
      });

      _socket?.onError((error) {
        print('🔥 Socket error: $error');
      });

      // SOCKET EVENTS
      _socket?.on('driverAssigned', (data) {
        print('🚗 Driver assigned via socket: $data');
        if (data is Map) {
          _handleDriverUpdate(data);
          _startDriverLocationUpdates();
        }
      });

      _socket?.on('driverLocationUpdate', (data) {
        print('📍 Driver location via socket: $data');
        if (data is Map) {
          _handleDriverLocationUpdate(data);
        }
      });

      _socket?.on('driverLocationResponse', (data) {
        print('📡 Driver location response: $data');
        if (data is Map) {
          _handleDriverLocationUpdate(data);
        }
      });

      _socket?.on('rideStatus', (data) {
        print('🔄 Ride status update: $data');
        _handleRideStatusUpdate(data);
      });

      _socket?.on('driverUpdate', (data) {
        print('👤 Driver update via socket: $data');
        if (data is Map && data['driver'] != null) {
          _handleDriverUpdate(data);
        }
      });

      _socket?.connect();
    } catch (e) {
      print('🔥 Socket initialization error: $e');
    }
  }

  // --- Google Map Setup ---
  Future<void> _setupMapAndRoute() async {
    _markers.clear();
    _polylines.clear();

    // Pickup Marker
    if (widget.pickupLocation != null) {
      final pickupLatLng = LatLng(
        widget.pickupLocation!.latitude!,
        widget.pickupLocation!.longitude!,
      );
      _markers.add(
        Marker(
          markerId: MarkerId('pickup'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Pickup'),
        ),
      );
    }

    // Drop Marker
    if (widget.dropLocation != null) {
      final dropLatLng = LatLng(
        widget.dropLocation!.latitude!,
        widget.dropLocation!.longitude!,
      );
      _markers.add(
        Marker(
          markerId: MarkerId('drop'),
          position: dropLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination'),
        ),
      );

      if (widget.pickupLocation != null) {
        await _fetchRoutePolyline();
      }
    }

    setState(() {});
  }

  Future<void> _fetchRoutePolyline() async {
    if (widget.pickupLocation == null || widget.dropLocation == null) return;

    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(
            widget.pickupLocation!.latitude!,
            widget.pickupLocation!.longitude!,
          ),
          destination: PointLatLng(
            widget.dropLocation!.latitude!,
            widget.dropLocation!.longitude!,
          ),
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
      } else {
        print('❌ No route points found: ${result.errorMessage}');
      }
    } catch (e) {
      print('🔥 Error fetching route: $e');
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
    return LatLngBounds(
      southwest: LatLng(south ?? 0, west ?? 0),
      northeast: LatLng(north ?? 0, east ?? 0),
    );
  }

  // --- Driver Location Handlers ---
  void _handleDriverUpdate(dynamic data) {
    print('🔄 Processing driver update: $data');

    if (data is Map) {
      Map<String, dynamic> driverData = {};

      // Check for different response formats
      if (data['driver'] != null) {
        driverData = data['driver'];
      } else if (data['name'] != null) {
        // Direct API response format
        driverData = data as Map<String, dynamic>;
      }

      if (driverData.isNotEmpty) {
        setState(() {
          _driverInfo['name'] = driverData['name'] ?? 'Driver';
          _driverInfo['rating'] = (driverData['rating'] ?? 4.5).toDouble();
          _driverInfo['phone'] = driverData['mobile'] ?? driverData['phone'] ?? '';
          _driverInfo['profileImage'] = driverData['profileImage'] ?? '';
          _driverInfo['transporterId'] = driverData['transporterId'] ?? '';
          _driverInfo['carModel'] = driverData['carModel'] ?? 'Car';
          _driverInfo['carNumber'] = driverData['carNumber'] ?? '';

          // Handle location data
          if (driverData['location'] != null) {
            _driverInfo['location'] = driverData['location'];

            // Update ETA based on location
            if (driverData['location']['coordinates'] is List && widget.pickupLocation != null) {
              List<dynamic> coords = driverData['location']['coordinates'];
              if (coords.length >= 2) {
                final lat = coords[1]?.toDouble() ?? 0.0;
                final lng = coords[0]?.toDouble() ?? 0.0;

                final distance = _calculateDistance(
                  lat,
                  lng,
                  widget.pickupLocation!.latitude!,
                  widget.pickupLocation!.longitude!,
                );
                _driverInfo['distance'] = '${distance.toStringAsFixed(1)} km away';
                _driverInfo['eta'] = '${_calculateETA(distance)} min';

                // Update driver marker on map
                _updateDriverMarkerOnMap(lat, lng);
              }
            }
          }

          _driverFound = true;
          _isConnecting = false;
        });

        print('✅ Driver info updated from API');
        print('   Name: ${_driverInfo['name']}');
        print('   Phone: ${_driverInfo['phone']}');
        print('   Location: ${_driverInfo['location']['coordinates']}');

        // Start real-time updates
        _startDriverLocationUpdates();
      }
    }
  }

  void _updateDriverMarkerOnMap(double lat, double lng) {
    final driverLatLng = LatLng(lat, lng);

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(
        Marker(
          markerId: MarkerId('driver'),
          position: driverLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          rotation: 0.0,
          flat: true,
          infoWindow: InfoWindow(
            title: 'Driver: ${_driverInfo['name']}',
            snippet: 'ETA: ${_driverInfo['eta']}',
          ),
          anchor: Offset(0.5, 0.5),
        ),
      );
    });

    // Move camera to show driver
    _moveCameraToDriver(driverLatLng);
  }

  void _handleDriverLocationUpdate(dynamic data) {
    if (data is Map) {
      print('📍 Processing driver location: $data');

      dynamic? lat, lng;

      if (data['location'] != null && data['location']['coordinates'] is List) {
        List<dynamic> coords = data['location']['coordinates'];
        if (coords.length >= 2) {
          lat = coords[1]?.toDouble();
          lng = coords[0]?.toDouble();
        }
      } else if (data['latitude'] != null && data['longitude'] != null) {
        lat = data['latitude']?.toDouble();
        lng = data['longitude']?.toDouble();
      } else if (data['location']?['lat'] != null && data['location']?['lng'] != null) {
        lat = data['location']['lat']?.toDouble();
        lng = data['location']['lng']?.toDouble();
      }

      if (lat != null && lng != null) {
        final driverLatLng = LatLng(lat, lng);
        final bearing = data['bearing']?.toDouble() ?? data['heading']?.toDouble() ?? 0.0;

        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'driver');
          _markers.add(
            Marker(
              markerId: MarkerId('driver'),
              position: driverLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              rotation: bearing,
              flat: true,
              infoWindow: InfoWindow(
                title: 'Driver: ${_driverInfo['name']}',
                snippet: 'ETA: ${_driverInfo['eta']}',
              ),
              anchor: Offset(0.5, 0.5),
            ),
          );

          if (widget.pickupLocation != null) {
            final distance = _calculateDistance(
              lat,
              lng,
              widget.pickupLocation!.latitude!,
              widget.pickupLocation!.longitude!,
            );
            _driverInfo['distance'] = '${distance.toStringAsFixed(1)} km away';
            _driverInfo['eta'] = '${_calculateETA(distance)} min';
          }

          if (_driverFound && !_isRideBooked) {
            _moveCameraToDriver(driverLatLng);
          }
        });

        print('✅ Driver location updated: $lat, $lng');
      }
    }
  }

  void _handleRideStatusUpdate(dynamic data) {
    if (data is Map) {
      print('🔄 Ride status: ${data['status']}');
      if (data['status'] == 'completed' || data['status'] == 'cancelled') {
        _timer?.cancel();
        _driverLocationTimer?.cancel();
        widget.onRideBooked();
      }
    }
  }

  // --- Distance & ETA Calculations ---
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c / 1000;
  }

  int _calculateETA(double distanceKm) => max((distanceKm * 2.5).ceil(), 2);

  // --- Driver Location Updates via Socket ---
  void _startDriverLocationUpdates() {
    _driverLocationTimer?.cancel();

    print('🚀 Starting real-time location updates via socket');

    if (_socket?.connected == true && _bookingId != null) {
      _socket?.emit('getDriverLocation', {
        'bookingId': _bookingId,
        'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    }

    // Start polling API every 5 seconds for updates
    _driverLocationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_bookingId != null && _driverFound) {
        _fetchDriverInfoFromAPI();
      }
    });
  }

  // --- NEW: Fetch Driver Info from API ---
  Future<void> _fetchDriverInfoFromAPI() async {
    if (_bookingId == null) return;

    try {
      print('🚗 Fetching driver info for booking: $_bookingId');

      final response = await http.get(
        Uri.parse('https://trogo-app-backend.onrender.com/api/bookings/$_bookingId/transporter-location'),
        headers: {
          'Authorization': 'Bearer ${AppPreference().getString(PreferencesKey.authToken)}',
        },
      );

      print('📡 Driver API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final driverData = json.decode(response.body);
        print('✅ Driver info received from API');

        // Process the API response data
        _handleDriverUpdate(driverData);
      } else {
        print('❌ Failed to fetch driver info: ${response.statusCode}');
      }
    } catch (error) {
      print('🔥 Error fetching driver info: $error');
    }
  }

  // --- Connection Timer ---
  void _startConnectionTimer() {
    _connectionTime = 0;
    _isSearchStarted = true;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _connectionTime++;
      });

      if (_socket?.connected == true && _bookingId != null) {
        _socket?.emit('requestLocation', {
          'bookingId': _bookingId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Check for driver after 3 seconds
      if (_connectionTime >= 3 && !_driverFound && _bookingId != null) {
        _fetchDriverInfoFromAPI();
      }

      // Auto-simulate after 10 seconds if still no driver (for testing only - comment out in production)
      if (_connectionTime >= 10 && !_driverFound && kDebugMode) {
        print('🕐 Test mode: Would simulate driver assignment after 10 seconds');
        // _simulateDriverAssignment(); // Comment this out in production
      }
    });
  }

  // --- Simulate Driver Assignment (for testing only - comment out in production) ---
  void _simulateDriverAssignment() {
    if (!_driverFound) {
      print('🎯 Test mode: Simulating driver assignment');

      // This is only for testing - in production, remove this function
      final testData = {
        'name': 'Test Driver',
        'mobile': '+91 9876543210',
        'profileImage': '',
        'transporterId': 'test_123',
        'location': {
          'type': 'Point',
          'coordinates': [73.7898, 19.9974],
        },
      };

      _handleDriverUpdate(testData);
    }
  }

  Future<void> _moveCameraToDriver(LatLng driverLatLng) async {
    try {
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLng(driverLatLng));
    } catch (e) {
      print('⚠️ Error moving camera: $e');
    }
  }

  void _simulateDriverSearch() {
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _isConnecting = true;
      });
    });
  }

  // --- Ride Booking ---
  void _bookRide() async {
    if (!_isSearchStarted) {
      setState(() {
        _isConnecting = true;
        _isSearchStarted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Searching for driver...')));

      String? tokens = AppPreference().getString(PreferencesKey.authToken);

      try {
        List<double> pickupCoords = [
          widget.pickupLocation?.longitude ?? 0.0,
          widget.pickupLocation?.latitude ?? 0.0,
        ];

        List<double> dropCoords = [
          widget.dropLocation?.longitude ?? 0.0,
          widget.dropLocation?.latitude ?? 0.0,
        ];

        final response = await http.post(
          Uri.parse('https://trogo-app-backend.onrender.com/api/bookings/bookings'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokens',
          },
          body: json.encode({
            "bookingType": "passenger",
            "vehicleTypeId": widget.carId ?? "",
            "pickup": {
              "address": widget.pickupLocation?.address ?? "Pickup location",
              "coordinates": pickupCoords,
            },
            "drop": {
              "address": widget.dropLocation?.address ?? "Drop location",
              "coordinates": dropCoords,
            },
          }),
        );

        print('📡 Booking API Response Status: ${response.statusCode}');
        print('📡 Booking API Response Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = json.decode(response.body);
          print('✅ Booking successful!');

          // Extract booking ID (adjust based on your API response structure)
          if (responseData['booking'] != null && responseData['booking']['_id'] != null) {
            _bookingId = responseData['booking']['_id'];
          } else if (responseData['_id'] != null) {
            _bookingId = responseData['_id'];
          } else if (responseData['data'] != null && responseData['data']['_id'] != null) {
            _bookingId = responseData['data']['_id'];
          }

          if (_bookingId != null) {
            print('📋 Booking ID: $_bookingId');

            // Join socket room
            if (_socket?.connected == true) {
              _socket?.emit('joinBooking', {'bookingId': _bookingId});
              _socket?.emit('requestDriver', {'bookingId': _bookingId});
            } else {
              _socket?.connect();
            }

            // Start connection timer
            _startConnectionTimer();
            _simulateDriverSearch();

            // Fetch driver info immediately
            Future.delayed(Duration(seconds: 2), () {
              _fetchDriverInfoFromAPI();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking confirmed! Searching for driver...'),
              ),
            );
          } else {
            print('❌ Could not extract booking ID from response');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking successful but could not get booking ID'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            _isConnecting = false;
            _isSearchStarted = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking failed. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (error) {
        print('🔥 Network/API Error: $error');

        setState(() {
          _isConnecting = false;
          _isSearchStarted = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Fetch Driver Location (Manual/Socket version) ---
  Future<void> _fetchDriverLocation() async {
    print('🔄 Manual driver location fetch requested');

    if (_socket?.connected == true && _bookingId != null) {
      _socket?.emit('requestDriverLocation', {
        'bookingId': _bookingId,
        'requestTime': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requesting driver location via socket...')),
      );
    } else if (_bookingId != null) {
      print('⚠️ Socket not connected, using HTTP API');
      try {
        final response = await http.get(
          Uri.parse('https://trogo-app-backend.onrender.com/api/bookings/$_bookingId/transporter-location'),
          headers: {
            'Authorization': 'Bearer ${AppPreference().getString(PreferencesKey.authToken)}',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _handleDriverUpdate(data);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Driver location updated from API')),
          );
        } else {
          print('❌ HTTP API failed: ${response.statusCode}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get driver location: ${response.statusCode}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (error) {
        print('❌ HTTP API error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    } else {
      print('❌ No booking ID available');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please book a ride first')));
    }
  }

  void _completeRideBooking() {
    if (!_isRideBooked) {
      setState(() {
        _isRideBooked = true;
      });
      _timer?.cancel();
      _driverLocationTimer?.cancel();
      print('🎉 Ride booking completed!');
      Future.delayed(Duration(seconds: 1), widget.onRideBooked);
    }
  }

  void _cancelRide() {
    print('❌ Ride cancelled by user');

    _timer?.cancel();
    _driverLocationTimer?.cancel();

    if (_socket?.connected == true && _bookingId != null) {
      _socket?.emit('cancelRide', {'bookingId': _bookingId});
    }

    setState(() {
      _isSearchStarted = false;
      _isConnecting = false;
      _driverFound = false;
      _isRideBooked = false;
      _bookingId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ride cancelled'), backgroundColor: Colors.red),
    );
    widget.onBack();
  }

  void _callDriver() {
    if (!_driverFound) {
      print('📞 Cannot call driver: Driver not found yet');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver not found yet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('📞 Calling driver: ${_driverInfo['name']}');
    print('   Phone: ${_driverInfo['phone']}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling ${_driverInfo['name']}...')),
    );
  }

  void _messageDriver() {
    if (!_driverFound) {
      print('💬 Cannot message driver: Driver not found yet');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver not found yet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('💬 Opening chat with driver: ${_driverInfo['name']}');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening chat with driver...')));
  }

  void _confirmDriver() {
    if (_driverFound && !_isRideBooked) {
      print('✅ User confirmed driver: ${_driverInfo['name']}');

      if (_socket?.connected == true && _bookingId != null) {
        _socket?.emit('confirmDriver', {
          'bookingId': _bookingId,
          'confirmed': true,
        });
      }

      _completeRideBooking();
    } else {
      print('⚠️ Cannot confirm driver: Driver not found or already booked');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot confirm driver'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _driverLocationTimer?.cancel();
    _socket?.disconnect();
    _socket?.clearListeners();
    super.dispose();
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    // Calculate initial position for map
    LatLng initialPosition = widget.pickupLocation != null
        ? LatLng(widget.pickupLocation!.latitude!, widget.pickupLocation!.longitude!)
        : LatLng(19.0760, 72.8777); // Default to Mumbai

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -------- HEADER --------
        Row(
          children: [
            GestureDetector(
              onTap: widget.onBack,
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                child: Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSearchStarted
                      ? (_driverFound ? "Driver Found!" : "Finding your driver")
                      : "Confirm your ride",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  _isSearchStarted
                      ? (_driverFound
                          ? "${_driverInfo['name'].isNotEmpty ? _driverInfo['name'] : 'Driver'} is on the way"
                          : "Searching for nearby drivers...")
                      : "Review details and book your ride",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),

        SizedBox(height: 20),

        // // -------- DEBUG INFO --------
        // if (kDebugMode)
        //   Container(
        //     padding: EdgeInsets.all(10),
        //     margin: EdgeInsets.only(bottom: 10),
        //     decoration: BoxDecoration(
        //       color: Colors.blue.shade50,
        //       borderRadius: BorderRadius.circular(8),
        //       border: Border.all(color: Colors.blue.shade200),
        //     ),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Row(
        //           children: [
        //             Icon(Icons.bug_report, size: 12, color: Colors.blue),
        //             SizedBox(width: 4),
        //             Text(
        //               'Debug Info',
        //               style: TextStyle(
        //                 fontSize: 10,
        //                 fontWeight: FontWeight.bold,
        //                 color: Colors.blue,
        //               ),
        //             ),
        //           ],
        //         ),
        //         SizedBox(height: 6),
        //         Text(
        //           'Socket: ${_socket?.connected == true ? "Connected" : "Disconnected"}',
        //           style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
        //         ),
        //         SizedBox(height: 2),
        //         Text(
        //           'Booking ID: ${_bookingId ?? "Not created"}',
        //           style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
        //         ),
        //         SizedBox(height: 2),
        //         Text(
        //           'Driver Found: $_driverFound',
        //           style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
        //         ),
        //         SizedBox(height: 2),
        //         Text(
        //           'Time: $_connectionTime s',
        //           style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
        //         ),
        //         if (_driverFound) SizedBox(height: 2),
        //         Text(
        //           'Driver: ${_driverInfo['name']}',
        //           style: TextStyle(fontSize: 9, color: Colors.blue.shade800),
        //         ),
        //       ],
        //     ),
        //   ),

        // -------- GOOGLE MAP using CommonGoogleMap --------
        // Check if mapWidget is provided from parent, otherwise use local map
        // if (widget.mapWidget != null)
        //   widget.mapWidget!
        // else
        //   CommonGoogleMap(
        //     initialLatLng: initialPosition,
        //     markers: _markers,
        //     polylines: _polylines,
        //     height: 250,
        //     onMapCreated: (GoogleMapController controller) {
        //       _mapController.complete(controller);
        //     },
        //   ),

        SizedBox(height: 20),

        // -------- CONNECTION STATUS --------
        if (_isConnecting && !_driverFound)
          Column(
            children: [
              SizedBox(
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                      strokeWidth: 3,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_taxi, size: 34, color: Colors.green.shade700),
                        SizedBox(height: 8),
                        Text(
                          '$_connectionTime s',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  print("DEBUG: Manual driver location fetch");
                  _fetchDriverLocation();
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        _socket?.connected == true
                            ? "Searching for driver... (Tap to refresh)"
                            : "Connecting to server... (Tap to retry)",
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        else if (_driverFound && !_isRideBooked)
          _buildDriverInfoCard(),

        SizedBox(height: 20),

        // -------- PICKUP/DROP TIMELINE --------
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.circle, size: 14, color: Colors.green.shade700),
                  Container(width: 2, height: 40, color: Colors.green.shade200),
                  Icon(Icons.circle_outlined, size: 14, color: Colors.red.shade400),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pickupLocation?.address ?? "Pickup location",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    Text(
                      widget.dropLocation?.address ?? "Drop location",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // -------- RIDE DETAILS --------
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Ride Type", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(widget.rideType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Estimated Fare", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text("₹${widget.price}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Payment", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Row(
                    children: [
                      Icon(Icons.credit_card, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text("Cash", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // -------- ACTION BUTTONS --------
        if (_driverFound && !_isRideBooked)
          Column(
            children: [
              Row(
                children: [
               
                  SizedBox(width: 10),
                 
                ],
              ),
              SizedBox(height: 10),
             
            ],
          )
        else if (_isRideBooked)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ride Booked Successfully!",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                      ),
                      Text(
                        "Your driver will arrive in ${_driverInfo['eta']}",
                        style: TextStyle(fontSize: 10, color: Colors.green.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: 10),

        // -------- MAIN BOOK BUTTON --------
        if (!_isSearchStarted && !_isRideBooked)
          ElevatedButton(
            onPressed: _bookRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_taxi_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  "Confirm & Book Ride",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        // -------- CANCEL BUTTON --------
        if (!_isRideBooked)
          TextButton(
            onPressed: _cancelRide,
            child: Text(
              _isSearchStarted ? "Cancel Search" : "Cancel",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),

        // -------- SAFETY TIP --------
        SizedBox(height: 15),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.security, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Verify driver name and vehicle before boarding",
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                ),
              ),
            ],
          ),
        ),

        // -------- DEBUG BUTTON --------
        if (kDebugMode)
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: () {
                print('🔍 SOCKET DEBUG INFO');
                print('   Connected: ${_socket?.connected}');
                print('   Booking ID: $_bookingId');
                print('   Driver Found: $_driverFound');
                print('   Connection Time: $_connectionTime');
                print('   Driver Name: ${_driverInfo['name']}');
                print('   Driver Phone: ${_driverInfo['phone']}');

                if (_socket?.connected == true) {
                  _socket?.emit('testPing', {'message': 'Hello from client'});
                  print('   Test ping sent');
                }
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bug_report, size: 14, color: Colors.orange),
                    SizedBox(width: 6),
                    Text(
                      'Socket Debug',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- Driver Info Card Widget ---
  Widget _buildDriverInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.green.shade100,
            backgroundImage: _driverInfo['profileImage']?.isNotEmpty == true
                ? NetworkImage(_driverInfo['profileImage'])
                : null,
            child: _driverInfo['profileImage']?.isNotEmpty == true
                ? null
                : Icon(Icons.person, size: 30, color: Colors.green.shade700),
          ),
          SizedBox(width: 12),
          Expanded(
            child:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _driverInfo['name'].isNotEmpty ? _driverInfo['name'] : 'Driver',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.orange),
                        SizedBox(width: 2),
                        Text(
                          _driverInfo['rating'].toStringAsFixed(1),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 4),
                if (_driverInfo['carModel']?.isNotEmpty == true)
                  // Text(_driverInfo['carModel'], style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                if (_driverInfo['carNumber']?.isNotEmpty == true)
                  Text(_driverInfo['carNumber'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      _driverInfo['distance'],
                      style: TextStyle(fontSize: 10, color: Colors.green.shade700),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.timer, size: 12, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      "ETA: ${_driverInfo['eta']}",
                      style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                    ),
                  ],
                ),
                if (_driverInfo['phone']?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "📱 ${_driverInfo['phone']}",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommonGoogleMap extends StatelessWidget {
  final LatLng initialLatLng;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final double height;
  final void Function(GoogleMapController)? onMapCreated;

  const CommonGoogleMap({
    super.key,
    required this.initialLatLng,
    this.markers = const {},
    this.polylines = const {},
    this.height = 250,
    this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: onMapCreated,
          initialCameraPosition: CameraPosition(
            target: initialLatLng,
            zoom: 14,
          ),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          compassEnabled: true,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
        ),
      ),
    );
  }
}