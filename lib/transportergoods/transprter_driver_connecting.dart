import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class TransprterDriverConnectingUI extends StatefulWidget {
  final VoidCallback onBack;
  final String rideType;
  final String? carId;
  final int? price;
  final SelectedLocation? pickupLocation;
  final SelectedLocation? dropLocation;
  final VoidCallback onRideBooked;
  final SelectedLocation? currentLocation; // Add this
  final double? destLatitude; // Add this
  final double? destLongitude; // Add this
  final String? destinationAddress; // Add this
  final Widget? mapWidget;
  final Function(Map<String, dynamic>, LatLng, double, String?)? onDriverUpdate;

  const TransprterDriverConnectingUI({
    super.key,
    required this.onBack,
    required this.rideType,
    required this.price,
    this.pickupLocation,
    this.dropLocation,
    this.carId,
    required this.onRideBooked,
    this.mapWidget,
    this.onDriverUpdate,
    this.currentLocation,
    this.destLatitude,
    this.destLongitude,
    this.destinationAddress,
  });

  @override
  _TransprterDriverConnectingUIState createState() => _TransprterDriverConnectingUIState();
}

class _TransprterDriverConnectingUIState extends State<TransprterDriverConnectingUI> {
  // Timer & State Variables
  int _connectionTime = 0;
  bool _isConnecting = false;
  bool _driverFound = false;
  bool _isRideBooked = false;
  bool _isSearchStarted = false;
  Timer? _timer;
  String? _bookingId;
  Timer? _driverLocationTimer;

  // Driver Information
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

  // Google Maps Variables
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  static const String GOOGLE_MAPS_API_KEY = "YOUR_API_KEY";
  final PolylinePoints polylinePoints = PolylinePoints(
    apiKey: GOOGLE_MAPS_API_KEY,
  );
  List<LatLng> _routeCoordinates = [];

  // Socket.IO
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ==================== INITIALIZATION ====================
  void _initialize() {
    ;
    _initSocket();
  }

  // ==================== SOCKET.IO ====================
  void _initSocket() {
    try {
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

      _setupSocketListeners();
      _socket?.connect();
    } catch (e) {
      debugPrint('Socket initialization error: $e');
    }
  }

  void _setupSocketListeners() {
    _socket?.onConnect((_) {
      _authenticateSocket();
      _joinBookingRoom();
    });

    _socket?.on('driverAssigned', _handleDriverUpdate);
    _socket?.on('driverLocationUpdate', _handleDriverLocationUpdate);
    _socket?.on('driverLocationResponse', _handleDriverLocationUpdate);
    _socket?.on('rideStatus', _handleRideStatusUpdate);
    _socket?.on('driverUpdate', _handleDriverUpdate);
    _socket?.on('bookingUpdated', _handleBookingUpdate);
  }

  void _authenticateSocket() {
    final token = AppPreference().getString(PreferencesKey.authToken);
    _socket?.emit('auth', {'token': token});
  }

  void _joinBookingRoom() {
    if (_bookingId != null) {
      _socket?.emit('joinBooking', {'bookingId': _bookingId});
    }
  }

  // ==================== MAP FUNCTIONS ====================

  // ==================== RIDE BOOKING ====================
  Future<void> _bookRide() async {
    // Validate inputs
    if (!_validateBookingInputs()) return;

    // Update UI state
    _setBookingState(true);

    // Show loading indicator
    _showSnackBar('Searching for driver...');

    try {
      // Prepare booking data
      final bookingData = _prepareBookingData();

      // Make API call
      final response = await _makeBookingApiCall(bookingData);

      // Handle response
      await _handleBookingResponse(response);
    } catch (error) {
      _handleBookingError(error);
    }
  }

  bool _validateBookingInputs() {
    final token = AppPreference().getString(PreferencesKey.authToken);

    if (token == null || token.isEmpty) {
      _showErrorSnackBar('Please login again');
      return false;
    }

    if (widget.pickupLocation == null || widget.dropLocation == null) {
      _showErrorSnackBar('Please select pickup and drop locations');
      return false;
    }

    return true;
  }

  void _setBookingState(bool isBooking) {
    setState(() {
      _isConnecting = isBooking;
      _isSearchStarted = isBooking;
    });
  }

  Map<String, dynamic> _prepareBookingData() {
    return {
      "bookingType": "passenger",
      "vehicleTypeId": widget.carId ?? "",
      "pickup": {
        "address": widget.pickupLocation?.address ?? "Pickup location",
        "coordinates": [
          widget.pickupLocation?.longitude ?? 0.0,
          widget.pickupLocation?.latitude ?? 0.0,
        ],
      },
      "drop": {
        "address": widget.dropLocation?.address ?? "Drop location",
        "coordinates": [
          widget.dropLocation?.longitude ?? 0.0,
          widget.dropLocation?.latitude ?? 0.0,
        ],
      },
    };
  }

  Future<http.Response> _makeBookingApiCall(
    Map<String, dynamic> bookingData,
  ) async {
    final token = AppPreference().getString(PreferencesKey.authToken);

    return await http
        .post(
          Uri.parse(
            'https://trogo-app-backend.onrender.com/api/bookings/bookings',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(bookingData),
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<void> _handleBookingResponse(http.Response response) async {
    debugPrint('Booking API Response Status: ${response.statusCode}');
    debugPrint('Booking API Response Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      _bookingId = _extractBookingId(responseData);

      if (_bookingId != null) {
        await _handleSuccessfulBooking();
      } else {
        _handleMissingBookingId();
      }
    } else {
      _handleFailedBooking(response);
    }
  }

  String? _extractBookingId(Map<String, dynamic> responseData) {
    if (responseData['booking']?['_id'] != null) {
      return responseData['booking']['_id'];
    } else if (responseData['_id'] != null) {
      return responseData['_id'];
    } else if (responseData['data']?['_id'] != null) {
      return responseData['data']['_id'];
    }
    return null;
  }

  Future<void> _handleSuccessfulBooking() async {
    _showSuccessSnackBar('Booking confirmed! Searching for driver...');

    // Start driver tracking
    _startConnectionTimer();
    _startDriverLocationUpdates();

    // Join socket room
    if (_socket?.connected == true) {
      _socket?.emit('joinBooking', {'bookingId': _bookingId});
      _socket?.emit('requestDriver', {'bookingId': _bookingId});
    }

    // Fetch driver info
    await Future.delayed(const Duration(seconds: 1));
    await _fetchDriverInfoFromAPI();
  }

  void _handleMissingBookingId() {
    _showErrorSnackBar('Booking successful but could not get booking ID');
    _setBookingState(false);
  }

  void _handleFailedBooking(http.Response response) {
    _showErrorSnackBar('Booking failed. Status: ${response.statusCode}');
    _setBookingState(false);
  }

  void _handleBookingError(dynamic error) {
    debugPrint('Network/API Error: $error');
    _showErrorSnackBar('Network error: $error');
    _setBookingState(false);
  }

  // ==================== DRIVER MANAGEMENT ====================
  void _handleDriverUpdate(dynamic data) {
    if (data is! Map) return;

    final driverData = _extractDriverData(data);
    if (driverData.isEmpty) return;

    _updateDriverInfo(driverData);

    if (driverData['location'] != null) {
      _updateDriverLocation(driverData['location']);
    }

    setState(() {
      _driverFound = true;
      _isConnecting = false;
    });

    _startDriverLocationUpdates();
  }

  Map<String, dynamic> _extractDriverData(Map data) {
    if (data['driver'] != null) return data['driver'];
    if (data['name'] != null) return Map<String, dynamic>.from(data);
    if (data['transporter'] != null) return data['transporter'];
    return {};
  }

  void _updateDriverInfo(Map<String, dynamic> driverData) {
    _driverInfo['name'] = driverData['name'] ?? 'Driver';
    _driverInfo['rating'] = (driverData['rating'] ?? 4.5).toDouble();
    _driverInfo['phone'] = driverData['mobile'] ?? driverData['phone'] ?? '';
    _driverInfo['profileImage'] = driverData['profileImage'] ?? '';
    _driverInfo['transporterId'] =
        driverData['transporterId'] ?? driverData['_id'] ?? '';
    _driverInfo['carModel'] = driverData['carModel'] ?? 'Car';
    _driverInfo['carNumber'] = driverData['carNumber'] ?? '';
    _driverOtp = driverData['startOtp']?.toString();
    _driverInfo['location'] = driverData['location'] ?? _driverInfo['location'];
    if (_driverOtp == null || _driverOtp!.isEmpty) {
      _driverOtp = driverData['startOtp']?.toString();
      print("✅ OTP SET: $_driverOtp");
    }
  }

  void _updateDriverLocation(Map<String, dynamic> locationData) {
    final coordinates = locationData['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return;

    // 🔥 FIX: backend sends [lat, lng]
    final lat = coordinates[0]?.toDouble();
    final lng = coordinates[1]?.toDouble();

    if (lat == null || lng == null) return;

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

    _notifyParentAboutDriver(lat, lng, 0.0);
  }

  String? _driverOtp = "";

  void _handleDriverLocationUpdate(dynamic data) {
    final latLng = _parseDriverLatLng(data);
    print('📡 SOCKET driverLocationUpdate RECEIVED');
    print(data);
    if (latLng == null) return;

    _updateDriverETA(latLng.latitude, latLng.longitude);
    _notifyParentAboutDriver(latLng.latitude, latLng.longitude, 0.0);
  }

  void _notifyParentAboutDriver(double lat, double lng, double bearing) {
    print('📞 DEBUG: _notifyParentAboutDriver called');
    print('   Parent callback exists: ${widget.onDriverUpdate != null}');

    print('ssOTP: $_driverOtp');

    if (widget.onDriverUpdate != null) {
      widget.onDriverUpdate!(
        _driverInfo,
        LatLng(lat, lng),
        bearing,
        _driverOtp,
      );
    } else {
      print('❌ onDriverUpdate is NULL!');
    }
  }

  void _updateDriverETA(double lat, double lng) {
    if (widget.pickupLocation == null) return;

    final distance = _calculateDistance(
      lat,
      lng,
      widget.pickupLocation!.latitude!,
      widget.pickupLocation!.longitude!,
    );

    setState(() {
      _driverInfo['distance'] = '${distance.toStringAsFixed(1)} km away';
      _driverInfo['eta'] = '${_calculateETA(distance)} min';
    });
  }

  void _handleRideStatusUpdate(dynamic data) {
    if (data is Map &&
        (data['status'] == 'completed' || data['status'] == 'cancelled')) {
      _cleanupTimers();
      setState(() {
        _isRideCompleted = true; // ✅ PAYMENT दाखवण्यासाठी
      });
      widget.onRideBooked();
    }
  }

  void _handleBookingUpdate(dynamic data) {
    if (data is Map && data['driverId'] != null) {
      _fetchDriverInfoFromAPI();
    }
  }

  // ==================== DRIVER API ====================
  Future<void> _fetchDriverInfoFromAPI() async {
    if (_bookingId == null) return;

    try {
      final token = AppPreference().getString(PreferencesKey.authToken);

      final response = await http
          .get(
            Uri.parse(
              'https://trogo-app-backend.onrender.com/api/bookings/$_bookingId/transporter-location',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));
      print('================ API RESPONSE START ================');
      print('Status Code: ${response.statusCode}');
      print('Raw Body: ${response.body}');
      print('===================================================');

      final responseData = json.decode(response.body);

      print('Parsed JSON:');
      print(responseData);

      print('OTP FROM API: ${responseData['startOtp']}');
      print('Location: ${responseData['location']}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle the response based on your API structure
        if (responseData['transporterId'] != null) {
          _driverOtp = responseData['startOtp'];
          // Extract driver info from response
          _driverInfo['transporterId'] = responseData['transporterId'];
          _driverInfo['name'] = responseData['name'] ?? 'Driver';
          _driverInfo['mobile'] = responseData['mobile'] ?? '';
          _driverInfo['profileImage'] = responseData['profileImage'] ?? '';

          final latLng = _parseDriverLatLng(responseData);
          if (latLng != null) {
            _notifyParentAboutDriver(latLng.latitude, latLng.longitude, 0.0);
          }

          setState(() {
            _driverFound = true;
            _isConnecting = false;
          });
        }
      }
    } catch (error) {
      debugPrint('Error fetching driver info: $error');
    }
  }

  // ==================== TIMERS ====================
  void _startConnectionTimer() {
    _connectionTime = 0;
    _isSearchStarted = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _connectionTime++);

      // Request driver location via socket
      if (_socket?.connected == true && _bookingId != null) {
        _socket?.emit('requestLocation', {
          'bookingId': _bookingId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      print("sssss");
      // Fetch driver info every 3 seconds
      if (_connectionTime % 3 == 0 && !_driverFound && _bookingId != null) {
        _fetchDriverInfoFromAPI();
      }

      // Timeout after 60 seconds
      if (_connectionTime >= 60 && !_driverFound) {
        timer.cancel();
        _showErrorSnackBar('No drivers available. Please try again.');
      }
    });
  }

  void _startDriverLocationUpdates() {
    _driverLocationTimer?.cancel();

    if (_socket?.connected == true && _bookingId != null) {
      _socket?.emit('getDriverLocation', {
        'bookingId': _bookingId,
        'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    }

    _driverLocationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bookingId != null) {
        _fetchDriverInfoFromAPI();
      }
    });
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371e3;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c / 1000;
  }

  int _calculateETA(double distanceKm) {
    final etaMinutes = (distanceKm / 0.5).ceil();
    return max(etaMinutes, 2);
  }

  bool _cameraMovedOnce = false;

  // ==================== UI HELPERS ====================
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  LatLng? _parseDriverLatLng(dynamic data) {
    List? coords;

    if (data is Map &&
        data['location'] != null &&
        data['location']['coordinates'] is List) {
      coords = data['location']['coordinates'];
    } else if (data is Map && data['coordinates'] is List) {
      coords = data['coordinates'];
    }

    if (coords == null || coords.length < 2) return null;

    // ✅ BACKEND = [lat, lng]
    final lat = coords[0]?.toDouble();
    final lng = coords[1]?.toDouble();

    if (lat == null || lng == null) return null;

    print('✅ FIXED DRIVER LOCATION: $lat, $lng');
    return LatLng(lat, lng);
  }

  bool _isRideCompleted = false;

  // ==================== CLEANUP ====================
  void _cleanupTimers() {
    _timer?.cancel();
    _driverLocationTimer?.cancel();
  }

  @override
  void dispose() {
    _cleanupTimers();
    _socket?.disconnect();
    _socket?.clearListeners();
    _socket?.dispose();
    super.dispose();
  }

  bool _paymentCompleted = false;

  @override
  Widget build(BuildContext context) {
    print(_bookingId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),

        // 🔥 PAYMENT COMPLETE झाल्यावर फक्त success UI
        if (_paymentCompleted) ...[
          _buildConnectionStatus(),
          _buildRideCompletedUI(),
        ] else ...[
          _buildConnectionStatus(),
          const SizedBox(height: 20),

          _buildLocationTimeline(),
          const SizedBox(height: 20),

          _buildRideDetails(),
          const SizedBox(height: 20),

          // Book button
          if (!_isSearchStarted && !_isRideBooked && !_driverFound) ...[
            const SizedBox(height: 20),
            _buildBookingButton(),
          ],

          // Cancel button
          if ((_isSearchStarted || _driverFound) && !_isRideBooked) ...[
            const SizedBox(height: 10),
            _buildCancelButton(),
          ],

          // 🔥 Payment section फक्त ride complete झाल्यावर
          _buildPaymentSection(),
        ],
      ],
    );
  }

  Widget _buildRideCompletedUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      // decoration: BoxDecoration(
      //   color: Colors.green.shade50,
      //   borderRadius: BorderRadius.circular(16),
      //   border: Border.all(color: Colors.green),
      // ),
      child: Column(
        children: const [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 12),
          Text(
            "Ride Completed Successfully",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Redirecting to home...",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Complete Payment",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ListTile(
            leading: const Icon(Icons.money, color: Colors.green),
            title: const Text("Pay Cash"),
            onTap: () => _completePayment("Cash"),
          ),

          ListTile(
            leading: const Icon(Icons.credit_card, color: Colors.blue),
            title: const Text("Pay Online"),
            onTap: () => _completePayment("Online"),
          ),
        ],
      ),
    );
  }

  Future<void> _completePayment(String method) async {
    if (_bookingId == null) {
      _showErrorSnackBar("Booking ID missing");
      return;
    }

    try {
      final token = AppPreference().getString(PreferencesKey.authToken);

      final response = await http.post(
        Uri.parse(
          'https://trogo-app-backend.onrender.com/api/bookings/complete-and-rate',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "bookingId": _bookingId,
          "paymentMethod": method, // 🔥 Cash / Online
          "paid": true,
          "rating": 5, // static for now
        }),
      );

      print('PAYMENT RESPONSE: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar("Ride completed successfully (Cash)");
        setState(() {
          _paymentCompleted = true; // 🔥 UI hide trigger
        });

        _showSuccessSnackBar("Ride completed successfully");

        // ⏳ 2 minutes delay → Home
        Future.delayed(const Duration(minutes: 2), () {
          widget.onRideBooked();
        });
        // ✅ Reset & Go Home
        widget.onRideBooked();
      } else {
        setState(() {
          _paymentCompleted = false; // 🔥 UI hide trigger
        });

        _showErrorSnackBar("Payment failed");
      }
    } catch (e) {
      setState(() {
        _paymentCompleted = false; // 🔥 UI hide trigger
      });
      print(e);
      _showErrorSnackBar("Something went wrong");
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onBack,
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.arrow_back, color: Colors.black),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isSearchStarted
                  ? (_driverFound ? "Driver Found!" : "Finding your driver")
                  : "Confirm your ride",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              _isSearchStarted
                  ? (_driverFound
                      ? "${_driverInfo['name'].isNotEmpty ? _driverInfo['name'] : 'Driver'} is on the way"
                      : "Searching for nearby drivers...")
                  : "Review details and book your ride",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    if (_isConnecting && !_driverFound) {
      return _buildConnectingWidget();
    } else if (_driverFound && !_isRideBooked) {
      return _buildDriverInfoCard();
    }
    return Container();
  }

  Widget _buildConnectingWidget() {
    return Column(
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
                  const SizedBox(height: 8),
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
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _fetchDriverInfoFromAPI,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
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
        if (_bookingId != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
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
      ],
    );
  }

  Widget _buildDriverInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.green.shade100,
                backgroundImage:
                    _driverInfo['profileImage']?.isNotEmpty == true
                        ? NetworkImage(_driverInfo['profileImage'])
                        : null,
                child:
                    _driverInfo['profileImage']?.isNotEmpty == true
                        ? null
                        : Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.green.shade700,
                        ),
              ),
              const SizedBox(width: 12),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.orange),
                            const SizedBox(width: 2),
                            Text(
                              _driverInfo['rating'].toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_driverInfo['carModel']?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        _driverInfo['carModel'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    if (_driverInfo['carNumber']?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        _driverInfo['carNumber'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          _driverInfo['distance'],
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timer, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          "ETA: ${_driverInfo['eta']}",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (_driverInfo['phone']?.isNotEmpty == true) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.phone, size: 10, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'Driver Phone',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (_driverOtp != null && _driverOtp!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your trip OTP',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                _paymentCompleted == false
                    ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _driverOtp!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    )
                    : SizedBox(),
                const SizedBox(height: 6),
                const Text(
                  'Share this OTP with your driver',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationTimeline() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pickupLocation?.address ?? "Pickup location",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.dropLocation?.address ?? "Drop location",
                  style: const TextStyle(
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
    );
  }

  Widget _buildRideDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildRideDetailRow("Ride Type", widget.rideType),
          const SizedBox(height: 8),
          _buildRideDetailRow("Estimated Fare", "₹${widget.price}"),
          const SizedBox(height: 8),
          _buildRideDetailRow("Payment", "Cash", icon: Icons.credit_card),
        ],
      ),
    );
  }

  Widget _buildRideDetailRow(String label, String value, {IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        icon != null
            ? Row(
              children: [
                Icon(icon, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
            : Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
      ],
    );
  }

  Widget _buildBookingButton() {
    return ElevatedButton(
      onPressed: _bookRide,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_taxi_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            "Confirm & Book Ride",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: _cancelRide,
      child: Text(
        _isSearchStarted ? "Cancel Search" : "Cancel",
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  Widget _buildSafetyTip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.security, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Verify driver name and vehicle before boarding",
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Text(
                'Debug Panel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Socket: ${_socket?.connected == true ? "✅ Connected" : "❌ Disconnected"}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    Text(
                      'Booking ID: ${_bookingId != null ? "✅ ${_bookingId!.substring(0, 8)}..." : "❌ None"}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    Text(
                      'Driver: ${_driverFound ? "✅ Found" : "❌ Searching"}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    Text(
                      'Time: ${_connectionTime}s',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _logDebugInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Socket Test',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: _fetchDriverInfoFromAPI,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
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
    );
  }

  void _logDebugInfo() {
    debugPrint('🔍 SOCKET DEBUG INFO');
    debugPrint('   Connected: ${_socket?.connected}');
    debugPrint('   Socket ID: ${_socket?.id}');
    debugPrint('   Booking ID: $_bookingId');
    debugPrint('   Driver Found: $_driverFound');
    debugPrint('   Connection Time: $_connectionTime');
    debugPrint('   Driver Name: ${_driverInfo['name']}');
    debugPrint('   Driver Phone: ${_driverInfo['phone']}');

    if (_socket?.connected == true) {
      _socket?.emit('testPing', {
        'message': 'Debug ping from client',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void _callDriver() {
    if (!_driverFound) {
      _showErrorSnackBar('Driver not found yet');
      return;
    }
    _showSnackBar('Calling ${_driverInfo['name']}...');
  }

  void _messageDriver() {
    if (!_driverFound) {
      _showErrorSnackBar('Driver not found yet');
      return;
    }
    _showSnackBar('Opening chat with driver...');
  }

  void _confirmDriver() {
    if (_driverFound && !_isRideBooked) {
      if (_socket?.connected == true && _bookingId != null) {
        _socket?.emit('confirmDriver', {
          'bookingId': _bookingId,
          'confirmed': true,
        });
      }
      _completeRideBooking();
    } else {
      _showErrorSnackBar('Cannot confirm driver');
    }
  }

  void _completeRideBooking() {
    if (!_isRideBooked) {
      setState(() => _isRideBooked = true);
      _cleanupTimers();

      Future.delayed(const Duration(seconds: 2), () {
        widget.onRideBooked();
      });
    }
  }

  void _cancelRide() {
    _cleanupTimers();

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

    _showErrorSnackBar('Ride cancelled');
    widget.onBack();
  }
}
