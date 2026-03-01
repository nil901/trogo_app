import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:trogo_app/MyRidesHistoryPage.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/auth/notication_screen.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/schedule_delivery_page.dart';
import 'package:trogo_app/transportergoods/transproter_first_screen.dart';

class GoodsTransportPage extends ConsumerStatefulWidget {
  const GoodsTransportPage({super.key, required this.selectedLocation});
  final SelectedLocation selectedLocation;

  @override
  ConsumerState<GoodsTransportPage> createState() => _GoodsTransportPageState();
}

class _GoodsTransportPageState extends ConsumerState<GoodsTransportPage> {
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
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Goods Transport",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
            child: const Icon(Icons.notifications, color: Colors.black),
          ),
          const SizedBox(width: 16),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 TOP FIXED CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                const Text(
                  "What would you like to do?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 14),

                _optionCard(
                  title: "Send Goods Transport",
                  subtitle: "Send with city limit",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => GoodsFlowManager(
                            
                            ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "History",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "View all",
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          /// 🔹 ONLY LIST SCROLLS
          Expanded(
            child:
                bookings.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: () async {
                        await getBookingHistoryApi(ref);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return BookingCard(booking: bookings[index]);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  /// OPTION CARD UI
  Widget _optionCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.teal.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.location_on, color: Colors.green),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// HISTORY CARD UI
  Widget _historyCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ORDR1234",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Completed",
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          const Text(
            "Recipient: Paul Pogba",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.motorcycle, color: Colors.blueGrey),
                  Container(width: 2, height: 35, color: Colors.grey.shade300),
                  Icon(Icons.location_on, color: Colors.green),
                ],
              ),
              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Drop off",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Maryland bustop, Anthony Ikeja",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "12 January 2020, 2:43pm",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
