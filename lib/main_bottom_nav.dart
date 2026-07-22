import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trogo_app/api_service/active_booking_service.dart';
import 'package:trogo_app/Home_Screen.dart';
import 'package:trogo_app/MyRidesHistoryPage.dart';
import 'package:trogo_app/ProfilePage.dart';
import 'package:trogo_app/TransportPage.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/localization/app_strings.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/services/ride_location_tracking_service.dart';
import 'package:trogo_app/transportergoods/transproter_first_screen.dart';

class MainBottomNav extends StatefulWidget {
  const MainBottomNav({
    super.key,
    required this.selectedLocation,
    this.initialIndex = 0,
  });
  final SelectedLocation selectedLocation;
  final int initialIndex;

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav>
    with WidgetsBindingObserver {
  static const String _trackingOwner = 'main_bottom_nav';
  int index = 0;
  int _homeRefreshTrigger = 0;
  late SelectedLocation _selectedLocation;
  late List<Widget> pages;
  bool _checkedActiveRide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    index = widget.initialIndex;
    _selectedLocation = widget.selectedLocation;
    _rebuildPages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSelectedLocation();
      RideLocationTrackingService.instance.start(owner: _trackingOwner);
      _restoreActiveRideIfNeeded();
    });
  }

  void _rebuildPages() {
    pages = [
      HomeScreen(
        selectedLocation: _selectedLocation,
        onLocationUpdated: _handleLocationUpdated,
        refreshTrigger: _homeRefreshTrigger,
      ),
      GoodsTransportPage(selectedLocation: _selectedLocation),
      MyRidesHistoryPage(selectedLocation: _selectedLocation),
      ProfilePage(),
    ];
  }

  void _handleLocationUpdated(SelectedLocation location) {
    if (!mounted) return;
    final hasChanged =
        _selectedLocation.latitude != location.latitude ||
        _selectedLocation.longitude != location.longitude ||
        _selectedLocation.address != location.address;

    if (!hasChanged) return;

    setState(() {
      _selectedLocation = location;
      _rebuildPages();
    });
  }

  Future<void> _refreshSelectedLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      String address = _selectedLocation.address ?? '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            place.street,
            place.locality,
            place.administrativeArea,
          ].where((part) => part != null && part!.trim().isNotEmpty).cast<String>();
          address = parts.join(', ');
        }
      } catch (_) {}

      final updatedLocation = SelectedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      await AppPreference().setDouble(
        PreferencesKey.savedLocationLat,
        updatedLocation.latitude,
      );
      await AppPreference().setDouble(
        PreferencesKey.savedLocationLng,
        updatedLocation.longitude,
      );
      await AppPreference().setString(
        PreferencesKey.savedLocationAddress,
        updatedLocation.address ?? '',
      );

      _handleLocationUpdated(updatedLocation);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSelectedLocation();
      RideLocationTrackingService.instance.restart(owner: _trackingOwner);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RideLocationTrackingService.instance.stop(owner: _trackingOwner);
    super.dispose();
  }

  Future<void> _restoreActiveRideIfNeeded() async {
    if (_checkedActiveRide || !mounted) return;
    _checkedActiveRide = true;

    final service = ActiveBookingService();
    Map<String, dynamic>? activeBooking;
    bool shouldBlockRideRestore = false;

    try {
      activeBooking = await service
          .fetchActiveBooking(
            allowCacheFallback: false,
          )
          .timeout(const Duration(seconds: 12));
      shouldBlockRideRestore = await service
          .shouldBlockRideRestoreForTransporter()
          .timeout(const Duration(seconds: 12));
    } catch (error) {
      debugPrint('Active ride restore skipped after timeout/error: $error');
      return;
    }

    if (!mounted ||
        shouldBlockRideRestore ||
        !service.shouldResumeRide(activeBooking)) {
      return;
    }

    final pickup = activeBooking?['pickup'] as Map<String, dynamic>?;
    final pickupCoordinates = _extractCoordinates(pickup);
    if (pickupCoordinates == null || pickupCoordinates.length < 2) return;

    final pickupLocation = SelectedLocation(
      latitude: (pickupCoordinates[1] as num).toDouble(),
      longitude: (pickupCoordinates[0] as num).toDouble(),
      address: pickup?['address']?.toString(),
    );

    final bookingType = activeBooking?['bookingType']?.toString().toLowerCase();

    if (bookingType == 'goods') {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => TransportRideHomePage(
                currentLocation: pickupLocation,
                initialActiveRide: activeBooking,
                restoreToDriverConnecting: true,
              ),
        ),
      );
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => RideHomePage(
              currentLocation: pickupLocation,
              initialActiveRide: activeBooking,
              restoreToDriverConnecting: true,
            ),
      ),
    );
  }

  List? _extractCoordinates(Map<String, dynamic>? location) {
    if (location == null) return null;
    final direct = location['coordinates'];
    if (direct is List && direct.length >= 2) {
      return direct;
    }

    final nested = location['location'];
    if (nested is Map<String, dynamic>) {
      final coordinates = nested['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        return coordinates;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await SystemNavigator.pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xffF6F6F6),
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? 12 : 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  navItem(Icons.home_rounded, AppStrings.t('home'), 0),
                  navItem(
                    Icons.local_shipping_rounded,
                    AppStrings.t('transport'),
                    1,
                  ),
                  navItem(
                    Icons.history_rounded,
                    AppStrings.t('history'),
                    2,
                  ),
                  navItem(Icons.person_rounded, AppStrings.t('profile'), 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int i) {
    final isSelected = index == i;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (index == i) return;

          setState(() {
            final previousIndex = index;
            index = i;
            if (i == 0 && previousIndex != 0) {
              _homeRefreshTrigger++;
              _rebuildPages();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff111111) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: AnimatedScale(
            scale: isSelected ? 1 : 0.96,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? Colors.white : const Color(0xff7A7A7A),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isSelected ? Colors.white : const Color(0xff7A7A7A),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
