// goods_tracking_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:trogo_app/api_service/urls.dart';

import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';

class GoodsTrackingPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;
  final Function? onRideCompleted;

  const GoodsTrackingPage({
    super.key,
    required this.bookingId,
    required this.bookingData,
    this.onRideCompleted,
  });

  @override
  State<GoodsTrackingPage> createState() => _GoodsTrackingPageState();
}

class _GoodsTrackingPageState extends State<GoodsTrackingPage> {
  // Map
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _driverLatLng;
  LatLng? _previousDriverLatLng;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  CameraPosition? _currentCameraPosition;
  BitmapDescriptor? _driverCarIcon;
  double _driverBearing = 0.0;

  // Driver
  Map<String, dynamic> _driverInfo = {
    'name': 'Searching for driver...',
    'phone': '',
    'rating': 0.0,
    'carModel': '',
    'carNumber': '',
    'profileImage': '',
    'distance': '--',
    'eta': '--',
    'status': 'searching',
  };
  String? _driverOtp;
  bool _driverFound = false;
  bool _rideStarted = false;
  bool _rideCompleted = false;
  bool _showPayment = false;
  String _rideStatus =
      'searching'; // searching, assigned, arrived, started, completed

  // Socket
  IO.Socket? _socket;
  Timer? _locationTimer;
  Timer? _statusTimer;

  // Payment
  String _selectedPayment = 'cash';
  bool _isPaying = false;
  bool _isCancellingRide = false;

  // Trip Info
  Map<String, dynamic> _tripInfo = {};
  double _fareAmount = 0.0;

  static String get BASE_URL => socketBaseUrl;

  @override
  void initState() {
    super.initState();
    _initializeFromBookingData();
    _loadDriverCarIcon();
    _initSocket();
    _startStatusPolling();
  }

  Future<void> _loadDriverCarIcon() async {
    if (_driverCarIcon != null) return;

    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(80, 80)),
        'assets/images/sedan.png',
      );
      _driverCarIcon =
          icon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    } catch (e) {
      debugPrint('Driver car icon load failed: $e');
      _driverCarIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }
  }

  void _initializeFromBookingData() {
    _tripInfo = {
      'pickup': widget.bookingData['pickup']?['address'] ?? 'Pickup Location',
      'drop': widget.bookingData['drop']?['address'] ?? 'Drop Location',
      'goods': widget.bookingData['goods']?['name'] ?? 'Goods',
      'weight': '${widget.bookingData['goods']?['weightKg'] ?? 0} kg',
      'receiver': widget.bookingData['receiver']?['name'] ?? 'Receiver',
      'receiverPhone': widget.bookingData['receiver']?['phone'] ?? '',
    };

    _fareAmount = (widget.bookingData['estimatedFare'] ?? 0.0).toDouble();
    _pickupLatLng = _extractBookingLatLng(widget.bookingData['pickup']);
    _dropLatLng = _extractBookingLatLng(widget.bookingData['drop']);

    _currentCameraPosition = CameraPosition(
      target: _pickupLatLng ?? const LatLng(19.0760, 72.8777),
      zoom: _pickupLatLng != null ? 14.0 : 12.0,
    );

    _updateMapMarkers();
    _updatePolylines();
    _logRoutePoints();
  }

  LatLng? _extractBookingLatLng(dynamic locationData) {
    if (locationData is! Map) return null;

    final coords =
        locationData['coordinates'] ??
        locationData['location']?['coordinates'];

    if (coords is! List || coords.length < 2) return null;

    final lng = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();

    return LatLng(lat, lng);
  }

  LatLng? _extractDriverLatLng(dynamic locationData) {
    List<dynamic>? coords;

    if (locationData is Map) {
      final directCoordinates = locationData['coordinates'];
      final nestedCoordinates = locationData['location']?['coordinates'];
      if (nestedCoordinates is List) {
        coords = nestedCoordinates;
      } else if (directCoordinates is List) {
        coords = directCoordinates;
      }
    } else if (locationData is List) {
      coords = locationData;
    }

    if (coords == null || coords.length < 2) return null;

    final first = (coords[0] as num).toDouble();
    final second = (coords[1] as num).toDouble();

    final firstLooksLikeLat = first.abs() <= 90;
    final secondLooksLikeLng = second.abs() <= 180;
    if (firstLooksLikeLat && secondLooksLikeLng) {
      return LatLng(first, second);
    }

    final firstLooksLikeLng = first.abs() <= 180;
    final secondLooksLikeLat = second.abs() <= 90;
    if (firstLooksLikeLng && secondLooksLikeLat) {
      return LatLng(second, first);
    }

    return null;
  }

  void _logRoutePoints() {
    debugPrint('Pickup LatLng: $_pickupLatLng');
    debugPrint('Drop LatLng: $_dropLatLng');
  }

  void _initSocket() {
    try {
      _socket = IO.io(
        BASE_URL,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .build(),
      );

      _socket?.onConnect((_) {
        _authenticateSocket();
        _joinBookingRoom();
        _requestDriverInfo();
      });

      _socket?.on('connect_error', (data) {
        print('Socket connection error: $data');
      });

      _socket?.on('driverAssigned', _handleDriverAssigned);
      _socket?.on('driverLocationUpdate', _handleDriverLocation);
      _socket?.on('driverLocationResponse', _handleDriverLocation);
      _socket?.on('rideStatus', _handleRideStatus);
      _socket?.on('rideStarted', _handleRideStarted);
      _socket?.on('rideCompleted', _handleRideCompleted);
      _socket?.on('otpGenerated', _handleOTPGenerated);

      _socket?.connect();
    } catch (e) {
      print('Socket initialization error: $e');
    }
  }

  void _authenticateSocket() {
    final token = AppPreference().getString(PreferencesKey.authToken);
    _socket?.emit('auth', {'token': token});
  }

  void _joinBookingRoom() {
    _socket?.emit('joinBooking', {'bookingId': widget.bookingId});
  }

  void _requestDriverInfo() {
    _socket?.emit('getDriverInfo', {'bookingId': widget.bookingId});
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!_driverFound) {
        _fetchDriverInfoFromAPI();
      }

      if (_socket?.connected == true) {
        _socket?.emit('requestLocation', {
          'bookingId': widget.bookingId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  Future<void> _fetchDriverInfoFromAPI() async {
    try {
      final token = AppPreference().getString(PreferencesKey.authToken);
      final response = await http.get(
        Uri.parse(
          '$BASE_URL/api/bookings/${widget.bookingId}/transporter-location',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['transporterId'] != null) {
          setState(() {
            _driverFound = true;
            _driverInfo = {
              'name': data['name'] ?? 'Driver',
              'phone': data['mobile'] ?? '',
              'rating': (data['rating'] ?? 4.5).toDouble(),
              'carModel': data['carModel'] ?? '',
              'carNumber': data['carNumber'] ?? '',
              'profileImage': data['profileImage'] ?? '',
              'status': 'assigned',
            };
            _driverOtp = data['startOtp']?.toString();
            _rideStatus = 'assigned';
          });

          // Update driver location if available
          if (data['location'] != null) {
            _handleDriverLocation(data);
          }
        }
      }
    } catch (e) {
      print('Error fetching driver info: $e');
    }
  }

  void _handleDriverAssigned(dynamic data) {
    print('Driver assigned: $data');

    if (data is! Map) return;

    final driver = data['driver'] ?? data;
    setState(() {
      _driverFound = true;
      _driverInfo = {
        'name': driver['name'] ?? 'Driver',
        'phone': driver['mobile'] ?? driver['phone'] ?? '',
        'rating': (driver['rating'] ?? 4.5).toDouble(),
        'carModel': driver['carModel'] ?? '',
        'carNumber': driver['carNumber'] ?? '',
        'profileImage': driver['profileImage'] ?? '',
        'status': 'assigned',
      };
      _rideStatus = 'assigned';
    });

    if (driver['startOtp'] != null) {
      setState(() {
        _driverOtp = driver['startOtp'].toString();
      });
    }

    // Start location updates
    _updatePolylines();
    _startLocationUpdates();
  }

  void _handleDriverLocation(dynamic data) {
    if (data is! Map) return;

    final nextDriverLatLng = _extractDriverLatLng(data);
    if (nextDriverLatLng == null) return;

    setState(() {
      _driverBearing = _calculateBearing(_driverLatLng, nextDriverLatLng);
      _previousDriverLatLng = _driverLatLng;
      _driverLatLng = nextDriverLatLng;
    });

    _updateDriverMarker();
    _updatePolylines();
    _calculateDistanceAndETA();

    _followDriverCamera();
  }

  void _updateDriverMarker() {
    if (_driverLatLng == null) return;

    _markers.removeWhere((marker) => marker.markerId.value == 'driver');
    _markers.add(_buildDriverMarker());

    if (mounted) setState(() {});
  }

  Marker _buildDriverMarker() {
    return Marker(
      markerId: const MarkerId('driver'),
      position: _driverLatLng!,
      icon:
          _driverCarIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      flat: true,
      anchor: const Offset(0.5, 0.58),
      rotation: _driverBearing,
      zIndex: 10,
      infoWindow: InfoWindow(
        title: _driverInfo['name'],
        snippet: _rideStatus == 'arrived' ? 'Arrived at pickup' : 'On the way',
      ),
    );
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

  void _calculateDistanceAndETA() {
    if (_driverLatLng == null || _pickupLatLng == null) return;

    final distance = _calculateDistance(
      _driverLatLng!.latitude,
      _driverLatLng!.longitude,
      _pickupLatLng!.latitude,
      _pickupLatLng!.longitude,
    );

    final eta = _calculateETA(distance);

    setState(() {
      _driverInfo['distance'] = '${distance.toStringAsFixed(1)} km';
      _driverInfo['eta'] = '$eta min';
    });
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371e3;
    final phi1 = lat1 * 3.14159 / 180;
    final phi2 = lat2 * 3.14159 / 180;
    final deltaPhi = (lat2 - lat1) * 3.14159 / 180;
    final deltaLambda = (lon2 - lon1) * 3.14159 / 180;

    final a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c / 1000;
  }

  int _calculateETA(double distanceKm) {
    final averageSpeed = 40;
    final etaMinutes = (distanceKm / averageSpeed * 60).ceil();
    return etaMinutes < 2 ? 2 : etaMinutes;
  }

  void _handleRideStatus(dynamic data) {
    if (data is! Map) return;

    final status = data['status'];
    final message = data['message'];

    print('Ride status update: $status - $message');

    setState(() {
      _rideStatus = status;

      if (status == 'arrived') {
        _driverInfo['status'] = 'arrived';
      } else if (status == 'started') {
        _rideStarted = true;
        _driverInfo['status'] = 'started';
      } else if (status == 'completed') {
        _rideCompleted = true;
        _showPayment = true;
      }
    });

    if (message != null) {
      _showSnackBar(message);
    }
  }

  void _handleRideStarted(dynamic data) {
    setState(() {
      _rideStarted = true;
      _rideStatus = 'started';
      _driverInfo['status'] = 'started';
    });
    _showSnackBar('Ride has started!');
  }

  void _handleRideCompleted(dynamic data) {
    setState(() {
      _rideCompleted = true;
      _rideStatus = 'completed';
      _showPayment = true;
    });
    _showSnackBar('Ride completed! Please complete payment.');
  }

  void _handleOTPGenerated(dynamic data) {
    if (data is Map && data['otp'] != null) {
      setState(() {
        _driverOtp = data['otp'].toString();
      });
      _showSnackBar('OTP generated: ${data['otp']}');
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (_socket?.connected == true && widget.bookingId != null) {
        _socket?.emit('requestLocation', {
          'bookingId': widget.bookingId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  Future<void> _updateCameraToDriver() async {
    if (_driverLatLng == null) return;

    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLng(_driverLatLng!));
  }

  Future<void> _followDriverCamera() async {
    if (_driverLatLng == null || !_mapController.isCompleted) return;

    try {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _driverLatLng!,
            zoom: _rideStarted ? 17.5 : 16.5,
            tilt: _rideStarted ? 55 : 45,
            bearing: _driverBearing,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Unable to follow driver camera: $e');
    }
  }

  void _updateMapMarkers() {
    _markers.clear();

    // Add pickup marker
    if (_pickupLatLng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('pickup'),
          position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Pickup Location'),
        ),
      );
    }

    // Add drop marker
    if (_dropLatLng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('drop'),
          position: _dropLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Drop Location'),
        ),
      );
    }

    // Add driver marker if available
    if (_driverLatLng != null) {
      _markers.add(_buildDriverMarker());
    }
  }

  void _updatePolylines() {
    _polylines.clear();

    if (_pickupLatLng != null && _dropLatLng != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('pickup_drop_route'),
          color: Colors.black87,
          width: 4,
          points: [_pickupLatLng!, _dropLatLng!],
        ),
      );
    }

    if (_driverLatLng != null && _pickupLatLng != null && !_rideStarted) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_pickup_route'),
          color: Colors.blue,
          width: 5,
          points: [_driverLatLng!, _pickupLatLng!],
        ),
      );
    }

    if (_rideStarted && _driverLatLng != null && _dropLatLng != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_drop_route'),
          color: Colors.green,
          width: 5,
          points: [_driverLatLng!, _dropLatLng!],
        ),
      );
    }

    if (mounted) setState(() {});
    _fitMapToVisiblePoints();
  }

  Future<void> _fitMapToVisiblePoints() async {
    final points = <LatLng>[
      if (_pickupLatLng != null) _pickupLatLng!,
      if (_dropLatLng != null) _dropLatLng!,
      if (_driverLatLng != null) _driverLatLng!,
    ];

    if (points.length < 2 || !_mapController.isCompleted) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  Future<void> _completePayment() async {
    if (_isPaying) return;

    setState(() => _isPaying = true);

    try {
      final token = AppPreference().getString(PreferencesKey.authToken);
      final response = await http.post(
        Uri.parse(bookingCompleteAndRateUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bookingId': widget.bookingId,
          'paymentMethod': _selectedPayment,
          'paid': true,
          'rating': 5,
          'comment': 'Great service!',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccess('Payment successful! Thank you for your business.');

        // Notify parent
        if (widget.onRideCompleted != null) {
          Future.delayed(Duration(seconds: 2), () {
            widget.onRideCompleted!();
          });
        }
      } else {
        _showError('Payment failed. Please try again.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isPaying = false);
    }
  }

  Future<void> _callDriver() async {
    if (_driverInfo['phone']?.isEmpty == true) {
      _showError('Driver phone number not available');
      return;
    }

    // Implement phone call
    _showSnackBar('Calling ${_driverInfo['name']}...');
  }

  Future<void> _messageDriver() async {
    _showSnackBar('Opening chat with driver...');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<bool> _cancelRideApi() async {
    try {
      final token = AppPreference().getString(PreferencesKey.authToken);
      if (token.isEmpty) {
        _showError('Please login again');
        return false;
      }

      final response = await http.post(
        Uri.parse(bookingCancelUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bookingId': widget.bookingId,
          'reason': 'User cancelled',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        String successMessage = 'Ride cancelled';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            successMessage = body['message'].toString();
          }
        } catch (_) {}

        _showSuccess(successMessage);
        return true;
      }

      String errorMessage = 'Cancel failed';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          errorMessage = body['message'].toString();
        }
      } catch (_) {}

      _showError(errorMessage);
      return false;
    } catch (e) {
      _showError('Cancel error: $e');
      return false;
    }
  }

  Future<void> _cancelRide() async {
    if (_isCancellingRide || _rideStarted || _rideCompleted) return;

    setState(() {
      _isCancellingRide = true;
    });

    final isCancelled = await _cancelRideApi();
    if (!mounted) return;

    if (isCancelled) {
      _locationTimer?.cancel();
      _statusTimer?.cancel();

      if (_socket?.connected == true) {
        _socket?.emit('cancelRide', {'bookingId': widget.bookingId});
      }

      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isCancellingRide = false;
    });
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition:
          _currentCameraPosition ??
          CameraPosition(target: LatLng(19.0760, 72.8777), zoom: 12),
      onMapCreated: (controller) {
        _mapController.complete(controller);
        _fitMapToVisiblePoints();
      },
      markers: _markers,
      polylines: _polylines,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      buildingsEnabled: true,
      trafficEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      onCameraMove: (position) {
        _currentCameraPosition = position;
      },
    );
  }

  Widget _buildStatusHeader() {
    String statusText = 'Searching for driver...';
    Color statusColor = Colors.orange;

    switch (_rideStatus) {
      case 'assigned':
        statusText = 'Driver assigned';
        statusColor = Colors.blue;
        break;
      case 'arrived':
        statusText = 'Driver arrived at pickup';
        statusColor = Colors.green;
        break;
      case 'started':
        statusText = 'Ride in progress';
        statusColor = Colors.purple;
        break;
      case 'completed':
        statusText = 'Ride completed';
        statusColor = Colors.black;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: statusColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
          if (_rideStatus == 'searching')
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    _driverInfo['profileImage']?.isNotEmpty == true
                        ? NetworkImage(_driverInfo['profileImage'])
                        : null,
                child:
                    _driverInfo['profileImage']?.isNotEmpty == true
                        ? null
                        : Icon(Icons.person, size: 30, color: Colors.grey),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverInfo['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(_driverInfo['rating'].toStringAsFixed(1)),
                        SizedBox(width: 12),
                        if (_driverInfo['carModel']?.isNotEmpty == true)
                          Text(
                            _driverInfo['carModel'],
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    if (_driverInfo['carNumber']?.isNotEmpty == true)
                      Text(
                        _driverInfo['carNumber'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.phone, color: Colors.green),
                    onPressed: _driverFound ? _callDriver : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.message, color: Colors.blue),
                    onPressed: _driverFound ? _messageDriver : null,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          if (_rideStatus == 'assigned' || _rideStatus == 'arrived')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.location_on, size: 20, color: Colors.blue),
                    SizedBox(height: 4),
                    Text(
                      _driverInfo['distance'],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Distance',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.timer, size: 20, color: Colors.orange),
                    SizedBox(height: 4),
                    Text(
                      _driverInfo['eta'],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'ETA',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.directions_car, size: 20, color: Colors.green),
                    SizedBox(height: 4),
                    Text(
                      _rideStatus == 'arrived' ? 'Arrived' : 'En route',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Status',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOTPCard() {
    if (_driverOtp == null || _rideStarted) return SizedBox();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Share OTP with Driver',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            _driverOtp!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Driver will enter this OTP to start the delivery',
            style: TextStyle(color: Colors.white60, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfoCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${_fareAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildTripDetailRow('Pickup', _tripInfo['pickup']),
          _buildTripDetailRow('Delivery', _tripInfo['drop']),
          _buildTripDetailRow('Goods', _tripInfo['goods']),
          _buildTripDetailRow('Weight', _tripInfo['weight']),
          _buildTripDetailRow('Receiver', _tripInfo['receiver']),
          if (_tripInfo['receiverPhone']?.isNotEmpty == true)
            _buildTripDetailRow('Receiver Phone', _tripInfo['receiverPhone']),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    if (_rideStarted || _rideCompleted) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCancellingRide ? null : _cancelRide,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        icon: SizedBox(
          width: 18,
          height: 18,
          child: _isCancellingRide
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Icon(Icons.cancel_outlined, color: Colors.red),
        ),
        label: const Text(
          'Cancel Ride',
          style: TextStyle(
            color: Colors.red,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTripDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Complete Payment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Total Amount: ₹${_fareAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              SizedBox(height: 12),
              _buildPaymentOption('Cash', 'cash', Icons.money),
              _buildPaymentOption('Online', 'online', Icons.credit_card),
              _buildPaymentOption('Card', 'card', Icons.payment),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isPaying ? null : _completePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isPaying
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                          'PAY NOW',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption(String title, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              _selectedPayment == value ? Colors.green : Colors.grey.shade300,
          width: _selectedPayment == value ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: _selectedPayment == value ? Colors.green : Colors.grey,
        ),
        title: Text(title),
        trailing:
            _selectedPayment == value
                ? Icon(Icons.check_circle, color: Colors.green)
                : null,
        onTap: () {
          setState(() {
            _selectedPayment = value;
          });
        },
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 20),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            if (_driverOtp != null && !_rideStarted) _buildOTPCard(),
            if (_driverFound) _buildDriverCard(),
            _buildTripInfoCard(),
            if (!_showPayment) _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildMap()),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildStatusHeader(),
                      ),
                      Positioned(
                        top: 56,
                        left: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 8),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              if (_showPayment) return;
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBottomPanel()),
              ],
            ),
          ),
          if (_showPayment) Positioned.fill(child: _buildPaymentSheet()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _statusTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
