import 'package:flutter/material.dart';
import 'package:trogo_app/models/history_model.dart';
import 'package:trogo_app/RideDetailsScreen.dart';
import 'package:trogo_app/transportergoods/tracking_screen.dart';

class BookingCard extends StatelessWidget {
  final BookingHistory booking;
  final Future<void> Function()? onHistoryChanged;

  const BookingCard({
    super.key,
    required this.booking,
    this.onHistoryChanged,
  });

  Color _getStatusColor() {
    switch (booking.status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'ongoing':
      case 'requested':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getStatusText() {
    switch (booking.status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'ongoing':
        return 'Ongoing';
      case 'requested':
        return 'Requested';
      default:
        return booking.status;
    }
  }

  String get _orderId {
    try {
      return 'ORDR${booking.id.substring(booking.id.length - 4).toUpperCase()}';
    } catch (e) {
      return 'ORDRXXXX';
    }
  }

  String get _recipient => booking.receiver?.name ?? booking.passenger.name;

  String get _formattedDate {
    try {
      final date = booking.createdAt;
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = monthNames[date.month - 1];
      final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final period = date.hour >= 12 ? 'pm' : 'am';
      return '${date.day} $month ${date.year}, ${hour12}:${date.minute.toString().padLeft(2, '0')}$period';
    } catch (e) {
      return 'Date unavailable';
    }
  }

  Map<String, dynamic> _buildGoodsTrackingData() {
    return {
      '_id': booking.id,
      'status': booking.status,
      'estimatedFare': booking.estimatedFare,
      'finalFare': booking.finalFare,
      'pickup': {
        'address': booking.pickup.address,
        'coordinates': booking.pickup.location.coordinates,
        'location': {
          'type': booking.pickup.location.type,
          'coordinates': booking.pickup.location.coordinates,
        },
      },
      'drop': {
        'address': booking.drop.address,
        'coordinates': booking.drop.location.coordinates,
        'location': {
          'type': booking.drop.location.type,
          'coordinates': booking.drop.location.coordinates,
        },
      },
      'goods': {
        'name': booking.goods?.name ?? '',
        'weightKg': booking.goods?.weightKg ?? 0.0,
      },
      'receiver': {
        'name': booking.receiver?.name ?? '',
        'phone': booking.receiver?.phone ?? '',
      },
      if (booking.transporter != null)
        'transporter': {
          '_id': booking.transporter!.id,
          'name': booking.transporter!.name,
          'mobile': booking.transporter!.mobile,
          'profileImage': booking.transporter!.profileImage,
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final status = booking.status.toLowerCase();
        if (['requested', 'ongoing'].contains(status)) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => GoodsTrackingPage(
                    bookingId: booking.id,
                    bookingData: _buildGoodsTrackingData(),
                  ),
            ),
          );

          if (result == true) {
            await onHistoryChanged?.call();
          }
        } else {
          // Completed/cancelled details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RideDetailsScreen(booking: booking),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _orderId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              'Recipient: $_recipient',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.local_shipping, color: Colors.blueGrey),
                    Container(width: 2, height: 35, color: Colors.grey.shade300),
                    const Icon(Icons.location_on, color: Colors.green),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Drop off',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.drop.address,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formattedDate,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
