import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/models/history_model.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/rider_book_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final BookingHistory booking;

  const RideDetailsScreen({
    super.key,
    required this.booking,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  bool _isCancellingRide = false;

  SelectedLocation _bookingPickupToSelectedLocation(PickupLocation pickup) {
    final coords = pickup.location.coordinates;
    final lat = coords.length > 1 ? coords[1].toDouble() : 0.0;
    final lng = coords.isNotEmpty ? coords[0].toDouble() : 0.0;
    return SelectedLocation(
      latitude: lat,
      longitude: lng,
      address: pickup.address,
    );
  }

  String _normalizedStatus() {
    final status = widget.booking.status.toLowerCase().trim();
    if (status == 'in_progress' || status == 'in-progress') {
      return 'ongoing';
    }
    return status;
  }

  bool _isActiveRide() {
    final status = _normalizedStatus();
    return status == 'requested' || status == 'ongoing';
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'requested':
        return 'Requested';
      case 'ongoing':
      case 'in_progress':
      case 'in-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _getActionLabel() {
    switch (_normalizedStatus()) {
      case 'ongoing':
        return 'View In Progress Ride';
      case 'requested':
        return 'Continue Ride';
      default:
        return 'Ride Completed';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'requested':
        return Colors.orange;
      case 'ongoing':
      case 'in_progress':
      case 'in-progress':
        return Colors.blue;
      default:
        return Colors.blueGrey.shade900;
    }
  }

  Future<void> _cancelRide() async {
    if (_isCancellingRide || !_isActiveRide()) return;

    setState(() {
      _isCancellingRide = true;
    });

    try {
      final token = AppPreference().getString(PreferencesKey.authToken);
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login again')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$bookingsBaseUrl/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bookingId': widget.booking.id,
          'reason': 'User cancelled',
        }),
      );

      print('RIDE DETAILS CANCEL STATUS: ${response.statusCode}');
      print('RIDE DETAILS CANCEL RESPONSE: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        String successMessage = 'Ride cancelled successfully';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            successMessage = body['message'].toString();
          }
        } catch (_) {}

        await AppPreference().setString(PreferencesKey.activeRideJson, '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
        Navigator.pop(context, true);
        return;
      }

      String errorMessage = 'Unable to cancel ride';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          errorMessage = body['message'].toString();
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancel ride failed')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancellingRide = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final booking = widget.booking;
    final createdAt = dateFormat.format(booking.createdAt);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ride Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// DATE
            Text(
              createdAt,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            /// MAIN INFO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// DRIVER INFO (if available)
                  if (booking.transporter != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: (booking.transporter!.profileImage != null &&
                                  booking.transporter!.profileImage!.isNotEmpty)
                              ? NetworkImage(booking.transporter!.profileImage!)
                              : const AssetImage("assets/images/driver.png"),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.transporter!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              booking.transporter!.mobile,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else if (booking.bookingType == 'goods') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Goods Delivery • ${booking.goods?.name ?? 'Package'}",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  /// LOCATIONS TIMELINE
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// DOTS + LINE
                      Column(
                        children: [
                          Container(
                            width: 3,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            width: 3,
                            height: 60,
                            color: Colors.grey.shade300,
                          ),
                          Container(
                            width: 3,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      /// ADDRESSES
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pickup',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.pickup.address,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Dropoff',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.drop.address,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  /// FARE & STATUS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// FARE
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (booking.finalFare != null && booking.finalFare! > 0)
                            Text(
                              '₹${booking.finalFare!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                color: Colors.green,
                              ),
                            ),
                          Text(
                            'Est: ₹${booking.estimatedFare.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      /// STATUS
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(booking.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusLabel(booking.status).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  /// GOODS INFO
                  if (booking.bookingType == 'goods' && booking.goods != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.goods!.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${booking.goods!.weightKg.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            /// ACTION BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isActiveRide() ? Colors.blue : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                onPressed: _isActiveRide()
                    ? () {
                        final pickupLocation = _bookingPickupToSelectedLocation(booking.pickup);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideHomePage(
                              currentLocation: pickupLocation,
                              initialActiveRide: {
                                '_id': booking.id,
                                'pickup': {
                                  'address': booking.pickup.address,
                                  'location': {
                                    'type': 'Point',
                                    'coordinates': booking.pickup.location.coordinates,
                                  },
                                },
                                'drop': {
                                  'address': booking.drop.address,
                                  'location': {
                                    'type': 'Point',
                                    'coordinates': booking.drop.location.coordinates,
                                  },
                                },
                                'status': booking.status,
                                if (booking.transporter != null)
                                  'transporter': {
                                    '_id': booking.transporter!.id,
                                    'name': booking.transporter!.name,
                                    'mobile': booking.transporter!.mobile,
                                    'profileImage': booking.transporter!.profileImage,
                                  },
                              },
                              restoreToDriverConnecting:
                                  _normalizedStatus() == 'ongoing',
                            ),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  _isActiveRide() ? _getActionLabel() : 'Ride Completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_isActiveRide()) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isCancellingRide ? null : _cancelRide,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                  label: const Text(
                    'Cancel Ride',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

