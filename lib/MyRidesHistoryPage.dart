import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/location_permission_screen.dart';

import 'package:trogo_app/models/history_model.dart';
import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/transportergoods/transproter_first_screen.dart';

class MyRidesHistoryPage extends ConsumerStatefulWidget {
  const MyRidesHistoryPage({super.key, required this.selectedLocation});
   final SelectedLocation selectedLocation;

  @override
  ConsumerState<MyRidesHistoryPage> createState() => _MyRidesHistoryPageState();
}

class _MyRidesHistoryPageState extends ConsumerState<MyRidesHistoryPage> {
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
            "My rides",
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
              child: CircularProgressIndicator(),
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
    String statusText = booking.status;
    
    if (booking.status == 'completed') {
      statusColor = Colors.green;
    } else if (booking.status == 'cancelled') {
      statusColor = Colors.red;
    } else if (booking.status == 'requested') {
      statusColor = Colors.orange;
    } else if (booking.status == 'ongoing') {
      statusColor = Colors.blue;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RideHomePage()),
        );
      },
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
                "Goods Delivery • ${booking.goods?.name ?? 'Package'}",
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
                        "Pick-up",
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
                        "Drop off",
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
                      "Est: ₹${booking.estimatedFare.toStringAsFixed(2)}",
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



class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});
final BookingHistory booking;
  @override
  Widget build(BuildContext context) {
      final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final createdAt = dateFormat.format(booking.createdAt);
    
    // Status color logic
    Color statusColor = Colors.blueGrey.shade900;
    String statusText = booking.status;
    
    if (booking.status == 'completed') {
      statusColor = Colors.green;
    } else if (booking.status == 'cancelled') {
      statusColor = Colors.red;
    } else if (booking.status == 'requested') {
      statusColor = Colors.orange;
    } else if (booking.status == 'ongoing') {
      statusColor = Colors.blue;
    }

    return 
  
    InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RideHomePage()),
        );
      },
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
                "Goods Delivery • ${booking.goods?.name ?? 'Package'}",
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
                        "Pick-up",
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
                        "Drop off",
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
                      "Est: ₹${booking.estimatedFare.toStringAsFixed(2)}",
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
