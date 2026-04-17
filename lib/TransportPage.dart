import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/models/history_model.dart';
import 'package:trogo_app/RideDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:trogo_app/MyRidesHistoryPage.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/auth/notication_screen.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/schedule_delivery_page.dart';
import 'package:trogo_app/localization/app_strings.dart';
import 'package:trogo_app/transportergoods/transproter_first_screen.dart';
import 'package:trogo_app/widgets/BookingCard.dart';

class GoodsTransportPage extends ConsumerStatefulWidget {
  const GoodsTransportPage({super.key, required this.selectedLocation});
  final SelectedLocation selectedLocation;

  @override
  ConsumerState<GoodsTransportPage> createState() => _GoodsTransportPageState();
}

class _GoodsTransportPageState extends ConsumerState<GoodsTransportPage> {
  Future<void> _refreshHistory() async {
    ref.read(bookingHistoryProvider.notifier).state = [];
    await getBookingHistoryApi(ref);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingHistoryProvider);
    debugPrint('Goods history count: ${bookings.length}');
    for (int i = 0; i < bookings.length; i++) {
      final booking = bookings[i];
      // debugPrint(
      //   'Goods history booking[$i]: '
      //   '{id: ${booking.id}, status: ${booking.status}, '
      //   'pickup: ${booking.pickup.address}, drop: ${booking.drop.address}, '
      //   'estimatedFare: ${booking.estimatedFare}, '
      //   'goods: ${booking.goods?.name}, receiver: ${booking.receiver?.name}, '
      //   'transporter: ${booking.transporter?.name}}',
      // );
    }

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppStrings.t('goodsTransport'),
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

                Text(
                  AppStrings.t('whatWouldYouLikeToDo'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 14),

                _optionCard(
                  title: AppStrings.t('sendGoodsTransport'),
                  subtitle: AppStrings.t('sendWithCityLimit'),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => GoodsFlowManager(
                            
                            ),
                      ),
                    );

                    if (!mounted) return;
                    await _refreshHistory();
                  },
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.t('history'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Text(
                    //   "View all",
                    //   style: TextStyle(
                    //     color: Colors.green.shade700,
                    //     fontWeight: FontWeight.w500,
                    //   ),
                    // ),
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
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.t('noHistoryFound'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.t('goodsBookingsWillAppearHere'),
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
                        await _refreshHistory();
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return BookingCard(
                            booking: bookings[index],
                            onHistoryChanged: _refreshHistory,
                          );
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







}
