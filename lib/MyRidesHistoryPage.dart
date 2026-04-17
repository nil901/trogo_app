import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/localization/app_strings.dart';

import 'package:trogo_app/models/history_model.dart';
import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/transportergoods/tracking_screen.dart';
import 'package:trogo_app/transportergoods/transproter_first_screen.dart';
import 'package:trogo_app/RideDetailsScreen.dart';

class MyRidesHistoryPage extends ConsumerStatefulWidget {
  const MyRidesHistoryPage({super.key, required this.selectedLocation});
   final SelectedLocation selectedLocation;

  @override
  ConsumerState<MyRidesHistoryPage> createState() => _MyRidesHistoryPageState();
}

class _MyRidesHistoryPageState extends ConsumerState<MyRidesHistoryPage> {
  String _normalizedStatus(String status) {
    final value = status.toLowerCase().trim();
    if (value == 'in_progress' || value == 'in-progress') {
      return 'ongoing';
    }
    return value;
  }

  String _statusLabel(String status) {
    switch (_normalizedStatus(status)) {
      case 'requested':
        return AppStrings.t('requested');
      case 'ongoing':
        return AppStrings.t('inProgress');
      case 'completed':
        return AppStrings.t('completed');
      case 'cancelled':
        return AppStrings.t('cancelled');
      default:
        return status;
    }
  }

  Map<String, dynamic> _buildGoodsTrackingData(BookingHistory booking) {
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

  Future<void> _handleBookingTap(BookingHistory booking) async {
    final status = _normalizedStatus(booking.status);
    final isTrackableGoodsBooking =
        booking.bookingType == 'goods' &&
        ['requested', 'ongoing'].contains(status);

    if (isTrackableGoodsBooking) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => GoodsTrackingPage(
                bookingId: booking.id,
                bookingData: _buildGoodsTrackingData(booking),
              ),
        ),
      );

      if (result == true && mounted) {
        ref.read(bookingHistoryProvider.notifier).state = [];
        await getBookingHistoryApi(ref);
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RideDetailsScreen(booking: booking)),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingHistoryProvider.notifier).state = [];
      getBookingHistoryApi(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingHistoryProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        
        // leading: GestureDetector(
        //   onTap: () => Navigator.pop(context),
        //   child: Icon(Icons.arrow_back, color: Colors.black),
        // ),
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TransportRideHomePage()),
            );
          },
          child: Text(
            AppStrings.t('myRides'),
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),

      body: bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 12),
                  Text(
                    AppStrings.t('noHistoryFound'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    AppStrings.t('ridesAndGoodsBookingsWillAppearHere'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await getBookingHistoryApi(ref);
              },
              child: ListView.separated(
                padding: EdgeInsets.all(16),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _rideHistoryCard(bookings[index]);
                },
              ),
            ),
    );
  }

  Widget _rideHistoryCard(BookingHistory booking) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final createdAt = dateFormat.format(booking.createdAt);
    
    // Status color logic
    Color statusColor = Colors.blueGrey.shade900;
    String statusText = _statusLabel(booking.status);
    
    final normalizedStatus = _normalizedStatus(booking.status);

    if (normalizedStatus == 'completed') {
      statusColor = Colors.green;
    } else if (normalizedStatus == 'cancelled') {
      statusColor = Colors.red;
    } else if (normalizedStatus == 'requested') {
      statusColor = Colors.orange;
    } else if (normalizedStatus == 'ongoing') {
      statusColor = Colors.blue;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _handleBookingTap(booking),
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// DATE
            Text(
              createdAt,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),

            SizedBox(height: 14),

            /// DRIVER INFO (if available)
            if (booking.transporter != null)
              Row(
                children: [
                CircleAvatar(
  radius: 24,
  backgroundImage: (booking.transporter?.profileImage != null &&
          booking.transporter!.profileImage!.isNotEmpty)
      ? NetworkImage(booking.transporter!.profileImage!)
      : const AssetImage("assets/images/driverflutter.png"),
),

                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.transporter!.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        booking.transporter!.mobile,
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              )
            else if (booking.bookingType == 'goods')
              Text(
                "${AppStrings.t('goodsDelivery')} • ${booking.goods?.name ?? AppStrings.t('package')}",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.blueGrey,
                ),
              ),

            SizedBox(height: 18),

            /// TIMELINE
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// DOTS + LINE
                Column(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: Colors.blueGrey,
                      size: 16,
                    ),
                    Container(
                      height: 45,
                      width: 2,
                      color: Colors.blueGrey.shade200,
                    ),
                    Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.blueGrey,
                      size: 16,
                    ),
                  ],
                ),

                SizedBox(width: 12),

                /// PICKUP + DROPOFF TEXT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('pickUp'),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        booking.pickup.address,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),

                      SizedBox(height: 16),

                      Text(
                        AppStrings.t('dropOff'),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        booking.drop.address,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// AMOUNT
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (booking.finalFare != null && booking.finalFare! > 0)
                      Text(
                        "₹${booking.finalFare!.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    Text(
                      "${AppStrings.t('estimatedPrefix')} ₹${booking.estimatedFare.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                /// STATUS PILL
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            /// ADDITIONAL INFO FOR GOODS
            if (booking.bookingType == 'goods' && booking.goods != null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.inventory, size: 14, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      "${booking.goods!.name} • ${booking.goods!.weightKg} kg",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}




