import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:trogo_app/api_service/active_booking_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:trogo_app/api_service/urls.dart';
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
  final VoidCallback? onRideCompleted;
  final VoidCallback? onRideCancelled;
  final SelectedLocation? currentLocation; // Add this
  final double? destLatitude; // Add this
  final double? destLongitude; // Add this
  final String? destinationAddress; // Add this
  final Widget? mapWidget;
  final Function(Map<String, dynamic>, LatLng, double, String?, List<LatLng>?)?
  onDriverUpdate;
  final Map<String, dynamic>? initialBookingData;

  const DriverConnectingUI({
    super.key,
    required this.onBack,
    required this.rideType,
    required this.price,
    this.pickupLocation,
    this.dropLocation,
    this.carId,
    required this.onRideBooked,
    this.onRideCompleted,
    this.onRideCancelled,
    this.mapWidget,
    this.onDriverUpdate,
    this.currentLocation,
    this.destLatitude,
    this.destLongitude,
    this.destinationAddress,
    this.initialBookingData,
  });

  @override
  _DriverConnectingUIState createState() => _DriverConnectingUIState();
}

class _DriverConnectingUIState extends State<DriverConnectingUI>
    with WidgetsBindingObserver {
  static const double _maxDriverDistanceKm = 15.0;
  final ActiveBookingService _activeBookingService = ActiveBookingService();

  // Timer & State Variables
  int _connectionTime = 0;
  bool _isConnecting = false;
  bool _driverFound = false;
  bool _isRideBooked = false;
  bool _isSearchStarted = false;
  bool _isCancellingRide = false;
  final List<String> _cancelReasons = [
    'Driver is late',
    'Wrong pickup location',
    'Change of plans',
    'Driver unavailable',
    'Other',
  ];
  Timer? _timer;
  String? _bookingId;
  Timer? _driverLocationTimer;
  Timer? _terminalStatusRedirectTimer;
  LatLng? _lastDriverLatLng;

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

  Future<bool> _cancelRideApi(String reason) async {
    if (_bookingId == null || _bookingId!.isEmpty) {
      _showErrorSnackBar("Booking not found");
      return false;
    }

    try {
      final token = AppPreference().getString(PreferencesKey.authToken);
      if (token.isEmpty) {
        _showErrorSnackBar("Please login again");
        return false;
      }

      final response = await http.post(
        Uri.parse(bookingCancelUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"bookingId": _bookingId, "reason": reason}),
      );

      print("CANCEL RESPONSE: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        String successMessage = "Ride cancelled";
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body["message"] != null) {
            successMessage = body["message"].toString();
          }
        } catch (_) {}

        _showSnackBar(successMessage);
        return true;
      }

      String errorMessage = "Cancel failed";
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body["message"] != null) {
          errorMessage = body["message"].toString();
        }
      } catch (_) {}

      _showErrorSnackBar(errorMessage);
      return false;
    } catch (e) {
      print(e);
      _showErrorSnackBar("Cancel error");
      return false;
    }
  }

  // Google Maps Variables
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  static const String GOOGLE_MAPS_API_KEY =
      "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";
  final PolylinePoints polylinePoints = PolylinePoints(
    apiKey: GOOGLE_MAPS_API_KEY,
  );
  List<LatLng> _routeCoordinates = [];

  // Socket.IO
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  // ==================== INITIALIZATION ====================
  void _initialize() {
    _restoreExistingBookingIfAvailable();
    _initSocket();
  }

  Future<void> _handleAppResumed() async {
    if (!mounted) return;

    if (_socket?.connected != true) {
      _socket?.connect();
    } else {
      _authenticateSocket();
      _joinBookingRoom();
      _requestDriverInfo();
    }

    if (_bookingId != null && _bookingId!.isNotEmpty) {
      _startDriverLocationUpdates();
      await _fetchDriverInfoFromAPI();
      return;
    }

    await _restoreActiveBookingAfterInterruption(showRestoreMessage: false);
  }

  void _restoreExistingBookingIfAvailable() {
    final booking = widget.initialBookingData;
    if (booking == null) return;

    _bookingId = booking['_id']?.toString();
    if (_bookingId == null || _bookingId!.isEmpty) return;

    final driverData = _extractDriverData(booking);
    final hasDriver = driverData.isNotEmpty;
    final bookingStatus = booking['status']?.toString().toLowerCase() ?? '';

    _driverInfo['status'] =
        bookingStatus == 'ongoing'
            ? 'Trip in progress'
            : 'Driver coming to pickup';

    if (hasDriver) {
      _updateDriverInfo(driverData);
      if (driverData['location'] != null) {
        _updateDriverLocation(driverData['location']);
      }
    }

    _isSearchStarted = true;
    _isConnecting = !hasDriver;
    _driverFound = hasDriver;

    _startConnectionTimer();
    _startDriverLocationUpdates();
  }

  // ==================== SOCKET.IO ====================
  void _initSocket() {
    try {
      _socket = IO.io(
        socketBaseUrl,
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
      _requestDriverInfo();
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

  void _requestDriverInfo() {
    if (_bookingId == null || _bookingId!.isEmpty) return;

    _socket?.emit('requestDriver', {'bookingId': _bookingId});
    _socket?.emit('getDriverInfo', {'bookingId': _bookingId});
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
    if (!mounted) return;
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
    final requestBody = json.encode(bookingData);

    debugPrint('Booking Create URL: $bookingCreateUrl');
    debugPrint('Booking Create Token Present: ${token.isNotEmpty}');
    debugPrint('Booking Create Payload: $requestBody');
    debugPrint('Booking Create token: $token');

    return await http
        .post(
          Uri.parse(bookingCreateUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<void> _handleBookingResponse(http.Response response) async {
    debugPrint('Booking API Response Status: ${response.statusCode}');
    debugPrint('Booking API Response Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      if (responseData['booking'] is Map<String, dynamic>) {
        AppPreference().setString(
          PreferencesKey.activeRideJson,
          json.encode(responseData['booking']),
        );
      }
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
      _joinBookingRoom();
      _requestDriverInfo();
    }

    // Fetch driver info
    await Future.delayed(const Duration(seconds: 1));
    await _fetchDriverInfoFromAPI();
  }

  void _handleMissingBookingId() {
    _showBookingErrorDialog(
      'Booking Failed',
      'We processed your payment but could not retrieve the booking ID.\n\nPlease try again or contact support.',
    );
    _setBookingState(false);
  }

  void _handleFailedBooking(http.Response response) {
    _showErrorSnackBar('Booking failed. Status: ${response.statusCode}');
    _setBookingState(false);
  }

  void _showBookingErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onBack();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleBookingError(dynamic error) {
    debugPrint('Network/API Error: $error');
    _recoverFromBookingFailure(error);
  }

  Future<void> _recoverFromBookingFailure(dynamic error) async {
    final restored = await _restoreActiveBookingAfterInterruption(
      showRestoreMessage: true,
    );
    if (restored) return;

    final message = _friendlyBookingErrorMessage(error);
    _showErrorSnackBar(message);
    _setBookingState(false);
  }

  String _friendlyBookingErrorMessage(dynamic error) {
    final raw = error.toString().toLowerCase();
    if (error is http.ClientException ||
        raw.contains('software caused connection abort') ||
        raw.contains('connection abort')) {
      return 'Network interrupted. Please try again.';
    }
    if (raw.contains('timeout')) {
      return 'Request timed out. Please check network and try again.';
    }
    return 'Network error. Please try again.';
  }

  Future<bool> _restoreActiveBookingAfterInterruption({
    bool showRestoreMessage = false,
  }) async {
    final activeBooking = await _activeBookingService.fetchActiveBooking();
    if (!mounted || activeBooking == null) return false;

    final bookingId = activeBooking['_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return false;

    _bookingId = bookingId;
    await _activeBookingService.cacheActiveBooking(activeBooking);

    final driverData = _extractDriverData(activeBooking);
    final hasDriver = driverData.isNotEmpty;
    final bookingStatus =
        activeBooking['status']?.toString().toLowerCase() ?? '';

    if (hasDriver) {
      _updateDriverInfo(driverData);
      if (driverData['location'] != null) {
        _updateDriverLocation(driverData['location']);
      }
    }

    if (!mounted) return true;

    setState(() {
      _isSearchStarted = true;
      _isConnecting = !hasDriver;
      _driverFound = hasDriver;
      _driverInfo['status'] =
          bookingStatus == 'ongoing'
              ? 'Trip in progress'
              : hasDriver
              ? 'Driver coming to pickup'
              : 'Searching for driver';
    });

    _joinBookingRoom();
    _startConnectionTimer();
    _startDriverLocationUpdates();
    await _fetchDriverInfoFromAPI();

    if (showRestoreMessage && mounted) {
      _showSuccessSnackBar('Existing booking restored');
    }

    return true;
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
    if (data['driver'] is Map) return Map<String, dynamic>.from(data['driver']);
    if (data['transporter'] is Map) {
      return Map<String, dynamic>.from(data['transporter']);
    }
    if (data['booking'] is Map) {
      final nested = _extractDriverData(
        Map<String, dynamic>.from(data['booking']),
      );
      if (nested.isNotEmpty) return nested;
    }
    if (data['data'] is Map) {
      final nested = _extractDriverData(
        Map<String, dynamic>.from(data['data']),
      );
      if (nested.isNotEmpty) return nested;
    }
    if (data['name'] != null) return Map<String, dynamic>.from(data);
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
    final latLng = _resolveDriverLatLng(locationData['coordinates']);
    if (latLng == null) return;
    final lat = latLng.latitude;
    final lng = latLng.longitude;

    if (widget.pickupLocation != null) {
      final distance = _calculateDistance(
        lat,
        lng,
        widget.pickupLocation!.latitude,
        widget.pickupLocation!.longitude,
      );

      _driverInfo['distance'] = '${distance.toStringAsFixed(1)} km away';
      _driverInfo['eta'] = '${_calculateETA(distance)} min';
    }

    _notifyParentAboutDriver(lat, lng);
  }

  String? _driverOtp = "";

  void _handleDriverLocationUpdate(dynamic data) {
    final latLng = _parseDriverLatLng(data);
    if (latLng == null) return;

    _updateDriverETA(latLng.latitude, latLng.longitude);
    _notifyParentAboutDriver(latLng.latitude, latLng.longitude);
  }

  void _notifyParentAboutDriver(
    double lat,
    double lng, {
    List<LatLng>? routePath,
  }) {
    final currentLatLng = LatLng(lat, lng);
    final bearing = _calculateBearing(_lastDriverLatLng, currentLatLng);
    _lastDriverLatLng = currentLatLng;

    print('📞 DEBUG: _notifyParentAboutDriver called');

    if (widget.onDriverUpdate != null) {
      widget.onDriverUpdate!(
        _driverInfo,
        currentLatLng,
        bearing,
        _driverOtp,
        routePath,
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
      widget.pickupLocation!.latitude,
      widget.pickupLocation!.longitude,
    );

    setState(() {
      if (distance <= 0.08) {
        _driverInfo['distance'] = 'Driver arrived';
        _driverInfo['eta'] = 'Now';
        _driverInfo['status'] = 'Driver arrived at pickup';
      } else {
        _driverInfo['distance'] = '${distance.toStringAsFixed(1)} km away';
        _driverInfo['eta'] = '${_calculateETA(distance)} min';
      }
    });
  }

  double _calculateBearing(LatLng? from, LatLng to) {
    if (from == null) return 0.0;

    final lat1 = from.latitude * pi / 180;
    final lng1 = from.longitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final lng2 = to.longitude * pi / 180;
    final dLng = lng2 - lng1;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  void _handleRideStatusUpdate(dynamic data) {
    if (data is! Map) return;

    final status = data['status']?.toString().toLowerCase();
    if (status != 'completed' && status != 'cancelled') return;

    if (status == 'completed') {
      _handleCompletedRideFlow();
      return;
    }

    _handleCancelledRideFlow();
  }

  void _handleBookingUpdate(dynamic data) {
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final driverData = _extractDriverData(map);
    final hasDriverAssignment =
        map['driverId'] != null ||
        map['transporterId'] != null ||
        driverData.isNotEmpty ||
        (map['booking'] is Map &&
            (((map['booking'] as Map)['driverId'] != null) ||
                ((map['booking'] as Map)['transporterId'] != null)));

    if (driverData.isNotEmpty) {
      _handleDriverUpdate(map);
    }

    if (hasDriverAssignment) {
      _requestDriverInfo();
      _fetchDriverInfoFromAPI();
    }
  }

  // ==================== DRIVER API ====================
  Future<void> _fetchDriverInfoFromAPI() async {
    if (_bookingId == null) return;

    try {
      final token = AppPreference().getString(PreferencesKey.authToken);
      debugPrint(
        'TRANSPORTER LOCATION CURL: curl --location --request GET "$bookingsBaseUrl/$_bookingId/transporter-location" --header "Authorization: Bearer $token" --header "Content-Type: application/json"',
      );

      final response = await http
          .get(
            Uri.parse('$bookingsBaseUrl/$_bookingId/transporter-location'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bookingStatus =
            responseData['status']?.toString().toLowerCase().trim() ?? '';

        if (bookingStatus == 'completed') {
          _handleCompletedRideFlow();
          return;
        }

        if (bookingStatus == 'cancelled') {
          _handleCancelledRideFlow();
          return;
        }

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
            _updateDriverETA(latLng.latitude, latLng.longitude);
            _notifyParentAboutDriver(latLng.latitude, latLng.longitude);
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
    _timer?.cancel();
    _connectionTime = 0;
    _isSearchStarted = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
      if (_socket?.connected == true && _bookingId != null) {
        _socket?.emit('getDriverLocation', {
          'bookingId': _bookingId,
          'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        _socket?.emit('requestLocation', {
          'bookingId': _bookingId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

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

  String? _getCurrentToDestinationDistanceLabel() {
    if (widget.currentLocation == null || widget.dropLocation == null) return null;
    final distance = _calculateDistance(
      widget.currentLocation!.latitude,
      widget.currentLocation!.longitude,
      widget.dropLocation!.latitude,
      widget.dropLocation!.longitude,
    );
    return '${distance.toStringAsFixed(1)} km from current to destination';
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
    if (data is! Map) return null;

    final directLatLng = _extractLatLngFromMap(Map<String, dynamic>.from(data));
    if (directLatLng != null) return directLatLng;

    for (final nestedKey in ['driver', 'transporter', 'data', 'booking']) {
      final nested = data[nestedKey];
      if (nested is Map) {
        final nestedLatLng = _extractLatLngFromMap(
          Map<String, dynamic>.from(nested),
        );
        if (nestedLatLng != null) return nestedLatLng;
      }
    }

    return null;
  }

  LatLng? _extractLatLngFromMap(Map<String, dynamic> data) {
    final location = data['location'];
    if (location is Map) {
      final nestedLocation = _extractLatLngFromMap(
        Map<String, dynamic>.from(location),
      );
      if (nestedLocation != null) return nestedLocation;
    }

    final coordinates = data['coordinates'];
    if (coordinates is List && coordinates.length >= 2) {
      return _resolveDriverLatLng(coordinates);
    }

    final lat = _toDouble(data['latitude'] ?? data['lat']);
    final lng = _toDouble(data['longitude'] ?? data['lng'] ?? data['lon']);
    if (lat != null && lng != null && _isValidLatLng(lat, lng)) {
      final latLng = LatLng(lat, lng);
      if (!_looksLikeBogusLocation(latLng) &&
          _isReasonableDriverLocation(latLng)) {
        return latLng;
      }
    }

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  LatLng? _resolveDriverLatLng(dynamic rawCoords) {
    if (rawCoords is! List || rawCoords.length < 2) return null;

    final first = (rawCoords[0] as num?)?.toDouble();
    final second = (rawCoords[1] as num?)?.toDouble();
    if (first == null || second == null) return null;

    final latLngAsIs =
        _isValidLatLng(first, second) ? LatLng(first, second) : null;
    final latLngSwapped =
        _isValidLatLng(second, first) ? LatLng(second, first) : null;

    if (latLngAsIs != null &&
        !_looksLikeBogusLocation(latLngAsIs) &&
        latLngSwapped == null) {
      print(
        '✅ DRIVER LOCATION parsed as [lat, lng]: ${latLngAsIs.latitude}, ${latLngAsIs.longitude}',
      );
      return latLngAsIs;
    }

    if (latLngSwapped != null &&
        !_looksLikeBogusLocation(latLngSwapped) &&
        latLngAsIs == null) {
      print(
        '✅ DRIVER LOCATION parsed as [lng, lat]: ${latLngSwapped.latitude}, ${latLngSwapped.longitude}',
      );
      return latLngSwapped;
    }

    if (latLngAsIs != null &&
        latLngSwapped != null &&
        widget.pickupLocation != null) {
      final pickup = widget.pickupLocation!;
      final asIsDistance = _calculateDistance(
        latLngAsIs.latitude,
        latLngAsIs.longitude,
        pickup.latitude,
        pickup.longitude,
      );
      final swappedDistance = _calculateDistance(
        latLngSwapped.latitude,
        latLngSwapped.longitude,
        pickup.latitude,
        pickup.longitude,
      );

      final resolved =
          asIsDistance <= swappedDistance ? latLngAsIs : latLngSwapped;
      if (_looksLikeBogusLocation(resolved) ||
          !_isReasonableDriverLocation(resolved)) {
        print(
          '❌ Ignoring bogus driver location: ${resolved.latitude}, ${resolved.longitude}',
        );
        return null;
      }
      print(
        '✅ DRIVER LOCATION resolved by nearest pickup: ${resolved.latitude}, ${resolved.longitude}',
      );
      return resolved;
    }

    final fallback = latLngAsIs ?? latLngSwapped;
    if (fallback == null ||
        _looksLikeBogusLocation(fallback) ||
        !_isReasonableDriverLocation(fallback)) {
      if (fallback != null) {
        print(
          '❌ Ignoring fallback driver location: ${fallback.latitude}, ${fallback.longitude}',
        );
      }
      return null;
    }
    return fallback;
  }

  bool _isValidLatLng(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  bool _looksLikeBogusLocation(LatLng location) {
    return location.latitude.abs() < 0.0001 &&
        location.longitude.abs() < 0.0001;
  }

  bool _isReasonableDriverLocation(LatLng location) {
    final pickup = widget.pickupLocation;
    if (pickup == null) return true;

    final distanceFromPickup = _calculateDistance(
      location.latitude,
      location.longitude,
      pickup.latitude,
      pickup.longitude,
    );

    if (distanceFromPickup <= _maxDriverDistanceKm) return true;

    final drop = widget.dropLocation;
    if (drop == null) return false;

    final distanceFromDrop = _calculateDistance(
      location.latitude,
      location.longitude,
      drop.latitude,
      drop.longitude,
    );

    return distanceFromDrop <= _maxDriverDistanceKm;
  }

  bool _isRideCompleted = false;

  // ==================== CLEANUP ====================
  void _cleanupTimers() {
    _timer?.cancel();
    _driverLocationTimer?.cancel();
    _terminalStatusRedirectTimer?.cancel();
  }

  void _handleCompletedRideFlow() {
    if (!mounted) return;
    if (_isRideCompleted || _paymentCompleted) return;

    _cleanupTimers();
    AppPreference().setString(PreferencesKey.activeRideJson, '');

    _showSuccessSnackBar('Ride completed successfully');
    setState(() {
      _isRideCompleted = true;
      _paymentCompleted = true;
    });

    _terminalStatusRedirectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      widget.onRideCompleted?.call();
    });
  }

  void _handleCancelledRideFlow() {
    _cleanupTimers();
    AppPreference().setString(PreferencesKey.activeRideJson, '');

    if (!mounted) return;

    _showErrorSnackBar('Ride was cancelled');
    widget.onRideCancelled?.call();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final isTrackingMode = _isSearchStarted || _driverFound;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        if (isTrackingMode) ...[
          _buildTrackingHeroCard(),
          const SizedBox(height: 16),
        ],

        // 🔥 PAYMENT COMPLETE झाल्यावर फक्त success UI
        if (_paymentCompleted) ...[
          _buildConnectionStatus(),
          _buildRideCompletedUI(),
        ] else ...[
          _buildConnectionStatus(),
          const SizedBox(height: 16),
          _buildLocationTimeline(),
          const SizedBox(height: 16),
          _buildRideDetails(),
          const SizedBox(height: 16),
          if (!_isSearchStarted && !_isRideBooked && !_driverFound) ...[
            const SizedBox(height: 20),
            _buildBookingButton(),
          ],
          const SizedBox(height: 10),
          _buildCancelButton(),
          SizedBox(height: 10),
          _buildPaymentSection(),
        ],
      ],
    );
  }

  Widget _buildTrackingHeroCard() {
    final statusLabel =
        _driverFound
            ? (_driverInfo['eta']?.toString().isNotEmpty == true
                ? _driverInfo['eta'].toString()
                : 'Driver nearby')
            : 'Searching';
    final statusSubLabel =
        _driverFound
            ? (_driverInfo['distance']?.toString().isNotEmpty == true
                ? _driverInfo['distance'].toString()
                : 'Live tracking active')
            : 'Finding nearby drivers';
    final tripDistanceLabel = _getCurrentToDestinationDistanceLabel();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A7B61), Color(0xFF0F9D58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverFound
                          ? 'Driver is on the way'
                          : 'Live ride search running',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _driverFound
                          ? (_driverInfo['name']?.toString().isNotEmpty == true
                              ? '${_driverInfo['name']} is moving toward pickup'
                              : 'Tracking driver live on the map')
                          : 'Live tracking is active on the map',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A7B61),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _driverFound ? 'ETA' : 'Status',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black.withOpacity(0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTrackingInfoChip(
                  icon: _driverFound ? Icons.route_rounded : Icons.search,
                  label: statusSubLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTrackingInfoChip(
                  icon: Icons.pin_drop_outlined,
                  label:
                      widget.dropLocation?.address?.toString().isNotEmpty ==
                              true
                          ? widget.dropLocation!.address!
                          : 'Destination selected',
                ),
              ),
            ],
          ),
          if (tripDistanceLabel != null) ...[
            const SizedBox(height: 10),
            _buildTrackingInfoChip(
              icon: Icons.directions,
              label: tripDistanceLabel,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
        Uri.parse(bookingCompleteAndRateUrl),
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
        _handleCompletedRideFlow();
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
    final topSpacing = MediaQuery.of(context).padding.top > 24 ? 12.0 : 4.0;
    final showBackButton = !_driverFound;
    return Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: Row(
        children: [
          if (showBackButton)
            GestureDetector(
              onTap: widget.onBack,
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
          SizedBox(width: showBackButton ? 12 : 0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSearchStarted
                    ? (_driverFound ? "Driver Found!" : "Finding your driver")
                    : "Confirm your ride",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
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
      ),
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
    return OutlinedButton.icon(
      onPressed: _isCancellingRide ? null : _cancelRide,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(color: Colors.red.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: SizedBox(
        width: 18,
        height: 18,
        child:
            _isCancellingRide
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                  size: 20,
                ),
      ),
      label: Text(
        _driverFound ? "Cancel Ride" : "Cancel Search",
        style: const TextStyle(
          color: Colors.red,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
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

  Future<String?> _showCancelReasonDialog() async {
    String selectedReason = _cancelReasons.first;
    String? customReason;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isOther = selectedReason == 'Other';
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.cancel_outlined,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cancel Ride',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tell us why',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Please select a reason for cancelling this ride:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            ..._cancelReasons.asMap().entries.map((entry) {
                              int index = entry.key;
                              String reason = entry.value;
                              return Column(
                                children: [
                                  RadioListTile<String>(
                                    value: reason,
                                    groupValue: selectedReason,
                                    title: Text(
                                      reason,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    activeColor: Colors.red,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        selectedReason = value;
                                        if (selectedReason != 'Other') {
                                          customReason = null;
                                        }
                                      });
                                    },
                                  ),
                                  if (index < _cancelReasons.length - 1)
                                    Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      if (isOther) ...[
                        const SizedBox(height: 16),
                        Text(
                          'What else?',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          autofocus: true,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Tell us why...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onChanged: (value) {
                            setState(() {
                              customReason = value;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade400),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Dismiss',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  (isOther &&
                                          (customReason?.trim().isEmpty ??
                                              true))
                                      ? null
                                      : () {
                                        final reason =
                                            selectedReason == 'Other'
                                                ? (customReason?.trim() ?? '')
                                                : selectedReason;
                                        Navigator.of(context).pop(reason);
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelRide() async {
    if (_isCancellingRide) return;

    final selectedReason =
        (_driverFound || _isRideBooked)
            ? await _showCancelReasonDialog()
            : 'Search cancelled by user';

    if (selectedReason == null || selectedReason.isEmpty) return;

    setState(() {
      _isCancellingRide = true;
    });

    final bookingId = _bookingId;
    final isCancelled = await _cancelRideApi(selectedReason);

    if (!mounted) return;

    if (isCancelled) {
      _cleanupTimers();

      if (_socket?.connected == true && bookingId != null) {
        _socket?.emit('cancelRide', {'bookingId': bookingId});
      }

      setState(() {
        _isSearchStarted = false;
        _isConnecting = false;
        _driverFound = false;
        _isRideBooked = false;
        _bookingId = null;
        _isCancellingRide = false;
      });

      AppPreference().setString(PreferencesKey.activeRideJson, '');
      widget.onBack();
      return;
    }

    setState(() {
      _isCancellingRide = false;
    });
  }
}
