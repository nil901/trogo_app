import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:trogo_app/Phone%20Number%20Screen.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/auth/profile_update_screen.dart';
import 'package:trogo_app/localization/app_strings.dart';
import 'package:trogo_app/payment_page.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
// Old StateProvider removed - using lib/providers/user_profile_provider.dart
import 'package:trogo_app/models/user_profile.dart';
import 'package:trogo_app/wigets/privacy_policy.dart';
import 'package:trogo_app/wigets/setting_screen.dart';
import '../providers/user_profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<void> _openProfileEditor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    if (!mounted) return;
    ref.read(userProfileProvider.notifier).fetchProfile();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => passengerSummaryApi(ref));
    ref.read(userProfileProvider.notifier).fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(passengerSummaryProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    debugPrint('ProfilePage profileAsync: $profileAsync');
    debugPrint('ProfilePage profile: $profile');
    final savedName = AppPreference().getString(PreferencesKey.userName);
    final savedEmail = AppPreference().getString(PreferencesKey.userEmail);
    final savedProfileImage = AppPreference().getString(
      PreferencesKey.userProfileImage,
    );

    final displayName =
        (profile?.name ?? '').trim().isNotEmpty
            ? profile!.name
            : (savedName.isNotEmpty ? savedName : 'Profile');
    final displayEmail =
        (profile?.email ?? '').trim().isNotEmpty ? profile!.email : savedEmail;

    final profileImageUrl =
        ((profile?.profileImage ?? '').trim().isNotEmpty
                ? profile?.profileImage
                : savedProfileImage)
            ?.trim() ??
        '';
    final hasProfileImage =
        profileImageUrl.isNotEmpty && profileImageUrl.toLowerCase() != 'null';
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Icon(Icons.arrow_back, color: Colors.black),
        title: Text(
          AppStrings.t('myAccount'),
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          InkWell(
            onTap: _openProfileEditor,
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
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 32, 32, 32),
                        Color.fromARGB(255, 37, 38, 39),
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child:
                        hasProfileImage
                            ? CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: NetworkImage(profileImageUrl),
                              onBackgroundImageError: (_, __) {
                                debugPrint(
                                  'Profile image failed to load: $profileImageUrl',
                                );
                              },
                            )
                            : CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.grey.shade200,
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                  ),
                ),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      displayEmail,
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
                _statCard(AppStrings.t('totalRides'), "${summary?.totalRides ?? 0}"),
                _statCard(AppStrings.t('completed'), "${summary?.completedRides ?? 0}"),
                _statCard(AppStrings.t('cancel'), "${summary?.cancelledRides ?? 0}"),
              ],
            ),

            SizedBox(height: 24),

            /// MENU ITEMS
            // _menuItem(Icons.wallet_outlined, "Payment", () {
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const PaymentPage()),
            //   );
            // }),
            _menuItem(Icons.privacy_tip, AppStrings.t('privacyPolicy'), () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrivacyPolicyScreen()),
              );
            }),
            // _menuItem(Icons.notifications_none, "Promotion", () {}),
            _menuItem(Icons.settings_outlined, AppStrings.t('setting'), () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            }),

            SizedBox(height: 10),
            // Divider(height: 40),

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
                            Icon(Icons.logout, color: Colors.red, size: 48),
                            SizedBox(height: 16),
                            Text(
                              AppStrings.t('logOutTitle'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              AppStrings.t('logOutMessage'),
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
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      AppStrings.t('cancel'),
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      AppPreference().clearSharedPreferences();
                                      ref
                                          .read(userProfileProvider.notifier)
                                          .reset();
                                      AppPreference().clearSharedPreferences();
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PhoneNumberScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      AppStrings.t('logOut'),
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
