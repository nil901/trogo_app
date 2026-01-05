
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

import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';


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
    this.mapWidget,
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
    print('📍 DriverConnectingUI initialized');
    print('   Pickup: ${widget.pickupLocation?.latitude}, ${widget.pickupLocation?.longitude}');
    print('   Drop: ${widget.dropLocation?.latitude}, ${widget.dropLocation?.longitude}');
    print('   Ride Type: ${widget.rideType}, Price: ₹${widget.price}');

    // Initialize immediately
    _initSocket();
    _setupMapAndRoute();
    
    // Start booking process automatically after a short delay
    Future.delayed(Duration(milliseconds: 500), () {
      if (!_isSearchStarted) {
        _bookRide();
      }
    });
  }

  // --- Socket.IO Initialization ---
  void _initSocket() {
    try {
      print('🔌 Initializing Socket.IO connection...');
      
      _socket = IO.io(
        'https://trogo-app-backend.onrender.com',
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .setTimeout(30000)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(5)
            .build(),
      );

      // Socket Event Listeners
      _socket?.onConnect((_) {
        print('✅ Socket connected successfully');
        print('   Socket ID: ${_socket?.id}');
        
        // Authenticate with token
        _socket?.emit('auth', {
          'token': AppPreference().getString(PreferencesKey.authToken),
        });

        // Join booking room if booking exists
        if (_bookingId != null) {
          print('   Joining booking room: $_bookingId');
          _socket?.emit('joinBooking', {'bookingId': _bookingId});
          _socket?.emit('requestDriverLocation', {'bookingId': _bookingId});
        }
      });

      _socket?.onConnectError((error) {
        print('❌ Socket connection error: $error');
      });

      _socket?.onDisconnect((_) {
        print('⚠️ Socket disconnected');
        setState(() {
          _isConnecting = true;
        });
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

      _socket?.on('bookingUpdated', (data) {
        print('📋 Booking updated: $data');
        if (data is Map && data['driverId'] != null) {
          print('   Driver ID found in booking update: ${data['driverId']}');
          // Fetch driver info using driverId
          _fetchDriverInfoFromAPI();
        }
      });

      // Connect socket
      _socket?.connect();
      print('🔄 Socket connection initiated...');
      
    } catch (e) {
      print('🔥 Socket initialization error: $e');
    }
  }

  // --- Google Map Setup ---
  Future<void> _setupMapAndRoute() async {
    print('🗺️ Setting up map and route...');
    
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Pickup'),
        ),
      );
      print('📍 Added pickup marker at: ${pickupLatLng.latitude}, ${pickupLatLng.longitude}');
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
      print('📍 Added drop marker at: ${dropLatLng.latitude}, ${dropLatLng.longitude}');

      // Fetch route if both locations available
      if (widget.pickupLocation != null) {
        await _fetchRoutePolyline();
      }
    }

    setState(() {});
    print('✅ Map setup complete');
  }

  Future<void> _fetchRoutePolyline() async {
    if (widget.pickupLocation == null || widget.dropLocation == null) return;

    try {
      print('🛣️ Fetching route polyline...');
      
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
        
        print('✅ Route polyline fetched with ${_routeCoordinates.length} points');
      } else {
        print('❌ No route points found: ${result.errorMessage}');
      }
    } catch (e) {
      print('🔥 Error fetching route: $e');
    }
  }

  // --- Driver Location Handlers ---
  void _handleDriverUpdate(dynamic data) {
    print('🔄 Processing driver update...');
    print('   Raw data: $data');

    if (data is Map) {
      Map<String, dynamic> driverData = {};

      // Check for different response formats
      if (data['driver'] != null) {
        driverData = data['driver'];
        print('   Found driver in "driver" key');
      } else if (data['name'] != null) {
        driverData = data as Map<String, dynamic>;
        print('   Found driver in root object');
      } else if (data['transporter'] != null) {
        driverData = data['transporter'];
        print('   Found driver in "transporter" key');
      }

      if (driverData.isNotEmpty) {
        print('✅ Driver data extracted:');
        print('   Name: ${driverData['name']}');
        print('   Phone: ${driverData['mobile'] ?? driverData['phone']}');
        print('   Location: ${driverData['location']}');

        setState(() {
          _driverInfo['name'] = driverData['name'] ?? 'Driver';
          _driverInfo['rating'] = (driverData['rating'] ?? 4.5).toDouble();
          _driverInfo['phone'] = driverData['mobile'] ?? driverData['phone'] ?? '';
          _driverInfo['profileImage'] = driverData['profileImage'] ?? '';
          _driverInfo['transporterId'] = driverData['transporterId'] ?? driverData['_id'] ?? '';
          _driverInfo['carModel'] = driverData['carModel'] ?? 'Car';
          _driverInfo['carNumber'] = driverData['carNumber'] ?? '';

          // Handle location data
          if (driverData['location'] != null) {
            _driverInfo['location'] = driverData['location'];

            // Update ETA based on location
            if (driverData['location']['coordinates'] is List &&
                widget.pickupLocation != null) {
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
                print('📍 Driver location updated: $lat, $lng');
              }
            }
          }

          _driverFound = true;
          _isConnecting = false;
        });

        print('✅ Driver info updated successfully');
        print('   Driver Found: $_driverFound');
        print('   Driver Name: ${_driverInfo['name']}');
        print('   Driver ETA: ${_driverInfo['eta']}');

        // Start real-time updates IMMEDIATELY
        _startDriverLocationUpdates();
      } else {
        print('⚠️ Driver data is empty in response');
      }
    } else {
      print('❌ Driver data is not a Map');
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
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

    print('📍 Added driver marker on map');
    
    // Move camera to show driver
    _moveCameraToDriver(driverLatLng);
  }

  void _handleDriverLocationUpdate(dynamic data) {
    if (data is Map) {
      print('📍 Processing real-time driver location update...');
      print('   Raw location data: $data');

      dynamic? lat, lng, bearing;

      if (data['location'] != null && data['location']['coordinates'] is List) {
        List<dynamic> coords = data['location']['coordinates'];
        if (coords.length >= 2) {
          lat = coords[1]?.toDouble();
          lng = coords[0]?.toDouble();
          print('   Found coordinates in location.coordinates');
        }
      } else if (data['coordinates'] is List) {
        List<dynamic> coords = data['coordinates'];
        if (coords.length >= 2) {
          lat = coords[1]?.toDouble();
          lng = coords[0]?.toDouble();
          print('   Found coordinates in coordinates key');
        }
      } else if (data['latitude'] != null && data['longitude'] != null) {
        lat = data['latitude']?.toDouble();
        lng = data['longitude']?.toDouble();
        print('   Found coordinates in latitude/longitude keys');
      } else if (data['location']?['lat'] != null && data['location']?['lng'] != null) {
        lat = data['location']['lat']?.toDouble();
        lng = data['location']['lng']?.toDouble();
        print('   Found coordinates in location.lat/lng');
      }

      if (lat != null && lng != null) {
        bearing = data['bearing']?.toDouble() ?? data['heading']?.toDouble() ?? 0.0;
        final driverLatLng = LatLng(lat, lng);

        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'driver');
          _markers.add(
            Marker(
              markerId: MarkerId('driver'),
              position: driverLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
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
        });

        print('✅ Driver location updated on map');
        print('   Latitude: $lat, Longitude: $lng');
        print('   Distance: ${_driverInfo['distance']}, ETA: ${_driverInfo['eta']}');

        if (_driverFound && !_isRideBooked) {
          _moveCameraToDriver(driverLatLng);
        }
      } else {
        print('❌ Could not extract lat/lng from location data');
      }
    }
  }

  void _handleRideStatusUpdate(dynamic data) {
    if (data is Map) {
      print('🔄 Ride status update received: ${data['status']}');
      if (data['status'] == 'completed' || data['status'] == 'cancelled') {
        _timer?.cancel();
        _driverLocationTimer?.cancel();
        widget.onRideBooked();
      }
    }
  }

  // --- Distance & ETA Calculations ---
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3; // Earth's radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c / 1000; // Convert to kilometers
  }

  int _calculateETA(double distanceKm) {
    // Assuming average speed of 30 km/h in city traffic
    final etaMinutes = (distanceKm / 0.5).ceil(); // 0.5 km per minute = 30 km/h
    return max(etaMinutes, 2); // Minimum 2 minutes
  }

  // --- Driver Location Updates via Socket ---
  void _startDriverLocationUpdates() {
    print('🚀 Starting real-time driver location updates...');
    
    _driverLocationTimer?.cancel();

    if (_socket?.connected == true && _bookingId != null) {
      print('   Requesting driver location via socket...');
      _socket?.emit('getDriverLocation', {
        'bookingId': _bookingId,
        'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } else {
      print('⚠️ Socket not connected or booking ID missing');
      print('   Socket connected: ${_socket?.connected}');
      print('   Booking ID: $_bookingId');
    }

    // Start polling API every 3 seconds for updates
    _driverLocationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      print('🔄 Polling driver location... (${DateTime.now().toLocal()})');
      
      if (_bookingId != null) {
        print('   Fetching driver info for booking: $_bookingId');
        _fetchDriverInfoFromAPI();
      } else {
        print('⚠️ No booking ID available for polling');
      }
    });

    print('✅ Driver location updates started');
  }

  // --- Fetch Driver Info from API ---
  Future<void> _fetchDriverInfoFromAPI() async {
    if (_bookingId == null) {
      print('❌ Cannot fetch driver info: Booking ID is null');
      return;
    }

    try {
      print('🚗 Fetching driver info from API...');
      print('   Booking ID: $_bookingId');
      print('   API Endpoint: https://trogo-app-backend.onrender.com/api/bookings/$_bookingId/transporter-location');

      final token = AppPreference().getString(PreferencesKey.authToken);
      if (token == null || token.isEmpty) {
        print('❌ Auth token is missing');
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://trogo-app-backend.onrender.com/api/bookings/$_bookingId/transporter-location',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Driver info received from API');
        
        // Check if response contains driver data
        if (responseData['driver'] != null || 
            responseData['name'] != null || 
            responseData['transporter'] != null) {
          _handleDriverUpdate(responseData);
        } else if (responseData['message'] != null) {
          print('ℹ️ API Message: ${responseData['message']}');
          
          // If driver not assigned yet, show searching status
          if (!_driverFound && _connectionTime < 60) {
            setState(() {
              _isConnecting = true;
            });
          }
        } else {
          print('⚠️ No driver data in API response');
        }
      } else if (response.statusCode == 404) {
        print('🔍 Driver not assigned yet (404)');
        setState(() {
          _isConnecting = true;
        });
      } else if (response.statusCode == 401) {
        print('🔐 Unauthorized - Token may be invalid');
      } else {
        print('❌ API Error: ${response.statusCode}');
      }
    } catch (error) {
      print('🔥 Error fetching driver info: $error');
      print('   Error type: ${error.runtimeType}');
    }
  }

  // --- Connection Timer ---
  void _startConnectionTimer() {
    print('⏱️ Starting connection timer...');
    
    _connectionTime = 0;
    _isSearchStarted = true;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _connectionTime++;
      });

      // Request driver location via socket
      if (_socket?.connected == true && _bookingId != null) {
        _socket?.emit('requestLocation', {
          'bookingId': _bookingId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Fetch driver info every 3 seconds
      if (_connectionTime % 3 == 0 && !_driverFound && _bookingId != null) {
        print('🔄 Periodic driver info fetch - Time: $_connectionTime');
        _fetchDriverInfoFromAPI();
      }

      // Log status every 5 seconds
      if (_connectionTime % 5 == 0) {
        print('📊 Status Update:');
        print('   Time: $_connectionTime seconds');
        print('   Driver Found: $_driverFound');
        print('   Booking ID: $_bookingId');
        print('   Socket Connected: ${_socket?.connected}');
        print('   Is Connecting: $_isConnecting');
      }

      // Auto-simulate after 15 seconds if still no driver (for testing only)
      if (_connectionTime >= 15 && !_driverFound && kDebugMode) {
        print('🕐 Test mode: Simulating driver assignment');
        _simulateDriverAssignment();
      }

      // Timeout after 60 seconds
      if (_connectionTime >= 60 && !_driverFound) {
        print('⏰ Connection timeout - No driver found after 60 seconds');
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No drivers available. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  // --- Simulate Driver Assignment (for testing only) ---
  void _simulateDriverAssignment() {
    if (!_driverFound) {
      print('🎯 Test mode: Simulating driver assignment');
      
      // Test coordinates near Mumbai
      final testLat = 19.0760 + (Random().nextDouble() * 0.01);
      final testLng = 72.8777 + (Random().nextDouble() * 0.01);
      
      final testData = {
        'name': 'Test Driver',
        'mobile': '+91 9876543210',
        'profileImage': '',
        'transporterId': 'test_123',
        'carModel': 'Maruti Swift',
        'carNumber': 'MH01AB1234',
        'rating': 4.7,
        'location': {
          'type': 'Point',
          'coordinates': [testLng, testLat],
        },
      };

      _handleDriverUpdate(testData);
      
      // Show test mode indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test Mode: Driver simulation active'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _moveCameraToDriver(LatLng driverLatLng) async {
    try {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newLatLng(driverLatLng)
      );
      print('📡 Camera moved to driver location');
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
      print('📋 Starting ride booking process...');
      
      setState(() {
        _isConnecting = true;
        _isSearchStarted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searching for driver...'))
      );

      String? tokens = AppPreference().getString(PreferencesKey.authToken);
      if (tokens == null || tokens.isEmpty) {
        print('❌ Auth token not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please login again'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        List<double> pickupCoords = [
          widget.pickupLocation?.longitude ?? 0.0,
          widget.pickupLocation?.latitude ?? 0.0,
        ];

        List<double> dropCoords = [
          widget.dropLocation?.longitude ?? 0.0,
          widget.dropLocation?.latitude ?? 0.0,
        ];

        print('📤 Sending booking request...');
        print('   Vehicle Type ID: ${widget.carId}');
        print('   Pickup Coords: $pickupCoords');
        print('   Drop Coords: $dropCoords');

        final response = await http.post(
          Uri.parse(
            'https://trogo-app-backend.onrender.com/api/bookings/bookings',
          ),
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
        ).timeout(Duration(seconds: 30));

        print('📡 Booking API Response Status: ${response.statusCode}');
        print('📡 Booking API Response Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = json.decode(response.body);
          print('✅ Booking successful!');

          // Extract booking ID
          if (responseData['booking'] != null && 
              responseData['booking']['_id'] != null) {
            _bookingId = responseData['booking']['_id'];
          } else if (responseData['_id'] != null) {
            _bookingId = responseData['_id'];
          } else if (responseData['data'] != null && 
                   responseData['data']['_id'] != null) {
            _bookingId = responseData['data']['_id'];
          }

          if (_bookingId != null) {
            print('📋 Booking ID extracted: $_bookingId');

            // 🔴 CRITICAL: Start driver location updates IMMEDIATELY
            _startDriverLocationUpdates();
            
            // 🔴 CRITICAL: Fetch driver info immediately
            Future.delayed(Duration(seconds: 1), () {
              _fetchDriverInfoFromAPI();
            });

            // Join socket room
            if (_socket?.connected == true) {
              _socket?.emit('joinBooking', {'bookingId': _bookingId});
              _socket?.emit('requestDriver', {'bookingId': _bookingId});
              print('✅ Joined socket room for booking');
            } else {
              print('⚠️ Socket not connected, trying to connect...');
              _socket?.connect();
            }

            // Start connection timer
            _startConnectionTimer();
            _simulateDriverSearch();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking confirmed! Searching for driver...'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            print('❌ Could not extract booking ID from response');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Booking successful but could not get booking ID',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            _isConnecting = false;
            _isSearchStarted = false;
          });

          print('❌ Booking failed with status: ${response.statusCode}');
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
      _fetchDriverInfoFromAPI();
    } else {
      print('❌ No booking ID available');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please book a ride first'))
      );
    }
  }

  void _completeRideBooking() {
    if (!_isRideBooked) {
      print('🎉 Completing ride booking...');
      
      setState(() {
        _isRideBooked = true;
      });
      
      _timer?.cancel();
      _driverLocationTimer?.cancel();
      
      print('✅ Ride booking completed!');
      
      Future.delayed(Duration(seconds: 2), () {
        widget.onRideBooked();
      });
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening chat with driver...'))
    );
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
    print('♻️ Disposing DriverConnectingUI...');
    
    _timer?.cancel();
    _driverLocationTimer?.cancel();
    
    if (_socket != null) {
      _socket?.disconnect();
      _socket?.clearListeners();
      _socket?.dispose();
    }
    
    super.dispose();
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    print('🎨 Building DriverConnectingUI UI...');
    print('   Driver Found: $_driverFound');
    print('   Is Connecting: $_isConnecting');
    print('   Connection Time: $_connectionTime');

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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green.shade700,
                      ),
                      strokeWidth: 3,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_taxi,
                          size: 34,
                          color: Colors.green.shade700,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '$_connectionTime s',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              if (_bookingId != null)
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Booking ID: ${_bookingId!.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      fontFamily: 'Monospace',
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
                  Icon(
                    Icons.circle_outlined,
                    size: 14,
                    color: Colors.red.shade400,
                  ),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pickupLocation?.address ?? "Pickup location",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    Text(
                      widget.dropLocation?.address ?? "Drop location",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
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
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Ride Type",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    widget.rideType,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Estimated Fare",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    "₹${widget.price}",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Payment",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Icon(Icons.credit_card, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        "Cash",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _callDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(Icons.phone, size: 16),
                      label: Text(
                        'Call Driver',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _messageDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(Icons.message, size: 16),
                      label: Text(
                        'Message',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _confirmDriver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Confirm & Track Ride',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        "Your driver will arrive in ${_driverInfo['eta']}",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade600,
                        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

        // -------- DEBUG PANEL --------
        if (kDebugMode)
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bug_report, size: 14, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        'Debug Panel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Socket: ${_socket?.connected == true ? "✅ Connected" : "❌ Disconnected"}',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              'Booking ID: ${_bookingId != null ? "✅ ${_bookingId!.substring(0, 8)}..." : "❌ None"}',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              'Driver: ${_driverFound ? "✅ Found" : "❌ Searching"}',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              'Time: ${_connectionTime}s',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              print('🔍 SOCKET DEBUG INFO');
                              print('   Connected: ${_socket?.connected}');
                              print('   Socket ID: ${_socket?.id}');
                              print('   Booking ID: $_bookingId');
                              print('   Driver Found: $_driverFound');
                              print('   Connection Time: $_connectionTime');
                              print('   Driver Name: ${_driverInfo['name']}');
                              print('   Driver Phone: ${_driverInfo['phone']}');

                              if (_socket?.connected == true) {
                                _socket?.emit('testPing', {
                                  'message': 'Debug ping from client',
                                  'timestamp': DateTime.now().toIso8601String(),
                                });
                                print('   Test ping sent');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size(0, 0),
                            ),
                            child: Text(
                              'Socket Test',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                          SizedBox(height: 6),
                          ElevatedButton(
                            onPressed: _fetchDriverInfoFromAPI,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size(0, 0),
                            ),
                            child: Text(
                              'Fetch Driver',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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
                : Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.green.shade700,
                  ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _driverInfo['name'].isNotEmpty
                          ? _driverInfo['name']
                          : 'Driver',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.orange),
                        SizedBox(width: 2),
                        Text(
                          _driverInfo['rating'].toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 4),
                if (_driverInfo['carModel']?.isNotEmpty == true)
                  Text(
                    _driverInfo['carModel'],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                if (_driverInfo['carNumber']?.isNotEmpty == true)
                  Text(
                    _driverInfo['carNumber'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      _driverInfo['distance'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.timer, size: 12, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      "ETA: ${_driverInfo['eta']}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                if (_driverInfo['phone']?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 10, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          _driverInfo['phone'],
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
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
