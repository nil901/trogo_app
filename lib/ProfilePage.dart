import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:trogo_app/Phone%20Number%20Screen.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/auth/profile_update_screen.dart';
import 'package:trogo_app/payment_page.dart';
import 'package:trogo_app/prefs/app_preference.dart';
final userProfileProvider =
    StateProvider<UserProfile?>((ref) => null);

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends ConsumerState<ProfilePage> {
  late Future<UserProfile> _profileFuture;
    final ProfileService _profileService = ProfileService();
  @override
  void initState() {
     _profileFuture = _profileService.fetchProfile();
    Future.microtask(() =>passengerSummaryApi(ref));
      Future.microtask(() => getUserProfileApi(ref));
    // TODO: implement initState
    super.initState();
  }

  Future<UserProfile?> getUserProfileApi(WidgetRef ref) async {
  try {
    final response = await ApiService().getRequest(
      '${baseUrl}auth/profile',
    );

    if (response != null && response.statusCode == 200) {
      final record = response.data['record'];

      final profile = UserProfile.fromJson(record);

      /// 🔥 Riverpod state update
      ref.read(userProfileProvider.notifier).state = profile;

      return profile;
    } else {
      throw Exception(
        response?.data['message'] ?? "Failed to fetch profile",
      );
    }
  } catch (e) {
    print("❌ Error fetching profile: $e");
  }
  return null;
}

  @override
  Widget build(BuildContext context) {

    final summary = ref.watch(passengerSummaryProvider); 
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Icon(Icons.arrow_back, color: Colors.black),
        title: Text(
          "My account",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          InkWell(
            onTap: () {
              // Navigat e to profile screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            child: Icon(Icons.edit_outlined, color: Colors.black),
          ),
          SizedBox(width: 16),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// USER PROFILE
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundImage: NetworkImage("${profile?.profileImage.toString()}"),
                ),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${profile?.name??"Searching"}",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${profile?.email ?? ""}",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 20),

            /// STATS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statCard("Total rides", "${summary?.totalRides ??0}"),
                _statCard("Completed", "${summary?.completedRides??0}"),
                _statCard("Cancel", "${summary?.cancelledRides??0}"),
              ],
            ),

            SizedBox(height: 24),

            /// MENU ITEMS
            _menuItem(Icons.wallet_outlined, "Payment", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentPage()),
              );
            }),

            _menuItem(Icons.delivery_dining, "Delivery History", () {}),
            _menuItem(Icons.notifications_none, "Promotion", () {}),
            _menuItem(Icons.settings_outlined, "Setting", () {}),

            SizedBox(height: 10),
            Divider(height: 40),

            /// LOGOUT
           GestureDetector(
  onTap: () {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  "Log Out?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Are you sure you want to log out of your account?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                         
                         AppPreference().clearSharedPreferences();
                           Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => PhoneNumberScreen()),
              );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Log Out",
                          style: TextStyle(color: Colors.white),
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
  },
  child: Row(
    children: [
      Icon(Icons.logout, color: Colors.red),
      SizedBox(width: 12),
      Text(
        "Log Out",
        style: TextStyle(
          fontSize: 14,
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// STAT CARD
  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey)),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  /// MENU ITEM WITH NAVIGATION
  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.blueGrey.shade700),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
