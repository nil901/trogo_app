// lib/home_screen.dart
import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:trogo_app/ProfilePage.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/models/recent_drop_model.dart';
import 'package:trogo_app/auth/notication_screen.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/models/vehicle_type_model.dart';
import 'package:trogo_app/models/user_profile.dart';
import 'package:trogo_app/localization/app_strings.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/providers/user_profile_provider.dart';

import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/wigets/around_you_cars_loactions.dart';
import 'package:trogo_app/wigets/bannars.dart';

import 'package:trogo_app/wigets/drop_provider.dart';

const _homeAccent = Colors.black;
const _homeAccentSoft = Color(0x14111111);
const _homeAccentGradient = [Color(0xFF111111), Color(0xFF2A2A2A)];

class HomeScreen extends ConsumerStatefulWidget {
  final SelectedLocation selectedLocation;
  final ValueChanged<SelectedLocation>? onLocationUpdated;
  final int refreshTrigger;
  const HomeScreen({
    super.key,
    required this.selectedLocation,
    this.onLocationUpdated,
    this.refreshTrigger = 0,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late SelectedLocation _currentLocation;
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? _lastHomeRefreshAt;

  Future<void> _refreshHomeDataIfNeeded({Duration minGap = const Duration(milliseconds: 800)}) async {
    final now = DateTime.now();
    final lastRefreshAt = _lastHomeRefreshAt;
    if (lastRefreshAt != null && now.difference(lastRefreshAt) < minGap) {
      debugPrint('Skipping duplicate home refresh.');
      return;
    }

    _lastHomeRefreshAt = now;
    await _refreshHomeData();
  }

  Future<void> _refreshHomeData() async {
    final authToken = AppPreference().getString(PreferencesKey.authToken);
    if (authToken.isEmpty) {
      debugPrint('Skipping home data refresh because auth token is missing.');
      return;
    }

    ref.invalidate(fetchAllCategoriesProvider);
    ref.read(userProfileProvider.notifier).reset();
    await ref.read(userProfileProvider.notifier).fetchProfile();
    
    await vehicletypesApi(ref, "passenger");
    await passengerSummaryApi(ref);
    await getBookingHistoryApi(ref);
    await fetchRecentDrops(ref);
  }

  // Updated method to navigate to RideBookScreen instead of RideHomePage
Future<void> _openRideBook() async {

  if (_currentLocation.latitude == 0.0 ||
      _currentLocation.longitude == 0.0) {
    _fetchCurrentLocation(); // background
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RideHomePage(
        currentLocation: _currentLocation,
      ),
    ),
  );
}

  // Method to open RideBookScreen with selected drop location
void _openRideBookWithLocation(RecentDropModel drop) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RideHomePage(
        currentLocation: SelectedLocation(
          latitude: drop.drop.lat,
          longitude: drop.drop.lng,
          address: drop.drop.address,
        ),
      ),
    ),
  );
}
  void _openAllCategories(List<BannerCategory> categories) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllCategoriesPage(categories: categories),
      ),
    );
  }

  Future<void> _openAllSuggestions(List<VehicleType> vehicles) async {
    // await _fetchCurrentLocation();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AllSuggestionsPage(
              vehicles: vehicles,
              selectedLocation: _currentLocation,
            ),
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
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

      String address = _currentLocation.address ?? '';
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

      if (!mounted) return;
      setState(() {
        _currentLocation = updatedLocation;
      });
      widget.onLocationUpdated?.call(updatedLocation);
    } catch (_) {}
  }

  void _startLocationUpdates() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        _updateLocationFromPosition(position);
      });
    } catch (_) {}
  }

  Future<void> _updateLocationFromPosition(Position position) async {
    String address = _currentLocation.address ?? '';
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

    if (!mounted) return;
    setState(() {
      _currentLocation = updatedLocation;
    });
    widget.onLocationUpdated?.call(updatedLocation);
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '${AppStrings.t('goodMorning')} 🌅';
    if (hour < 17) return '${AppStrings.t('goodAfternoon')} ☀️';
    if (hour < 21) return '${AppStrings.t('goodEvening')} 🌇';
    return '${AppStrings.t('goodNight')} 🌙';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentLocation = widget.selectedLocation;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _refreshHomeDataIfNeeded();
      _fetchCurrentLocation();
      _startLocationUpdates();
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.selectedLocation.latitude != widget.selectedLocation.latitude ||
        oldWidget.selectedLocation.longitude !=
            widget.selectedLocation.longitude ||
        oldWidget.selectedLocation.address != widget.selectedLocation.address;
    final shouldRefresh = oldWidget.refreshTrigger != widget.refreshTrigger;

    if (locationChanged) {
      setState(() {
        _currentLocation = widget.selectedLocation;
      });
    }

    if (!shouldRefresh) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchCurrentLocation();
      _refreshHomeDataIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchCurrentLocation();
      _refreshHomeDataIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(fetchAllCategoriesProvider);
    final categories = ref.watch(bannerCategoryProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final vihicle = ref.watch(vihicletypeProvider);
    final recentDrops = ref.watch(recentDropProvider);
    final isRecentDropsLoading = ref.watch(recentDropLoadingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: categoriesAsync.when(
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => _buildErrorWidget(error),
        data: (_) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom App Bar
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  title: _buildAnimatedSearchBar(),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: _homeAccentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.notifications_none,
                          color: _homeAccent,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationScreen(),
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),

                // Main Content
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // User Greeting
                      _buildUserGreeting(),

                      // Recent Locations
                      _buildRecentLocations(recentDrops, isRecentDropsLoading),

                      const SizedBox(height: 24),

                      // Categories Section with Background
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // Suggestions Section
                            _buildSuggestionsHeader(vihicle),

                            // Vehicle Types
                            _buildVehicleTypes(vihicle),

                            const SizedBox(height: 10),
                            _buildCategoriesHeader(categories),
                            const SizedBox(height: 10),
                            if (categories.isNotEmpty)
                              _buildCategoriesList(categories),
                            // Selected Category Banners
                            if (selectedCategoryId != null)
                              _buildSelectedCategorySection(
                                categories,
                                selectedCategoryId,
                              ),

                            // Around You Section
                           // _buildAroundYouHeader(),

                            const SizedBox(height: 16),

                            // Around You Map
                            // Container(
                            //   height: 220,
                            //   margin: const EdgeInsets.symmetric(
                            //     horizontal: 16,
                            //   ),
                            //   decoration: BoxDecoration(
                            //     borderRadius: BorderRadius.circular(20),
                            //     boxShadow: [
                            //       BoxShadow(
                            //         color: Colors.grey.withOpacity(0.1),
                            //         blurRadius: 10,
                            //         offset: const Offset(0, 4),
                            //       ),
                            //     ],
                            //   ),
                            //   child: ClipRRect(
                            //     borderRadius: BorderRadius.circular(20),
                            //     child: const AroundYouCarsMap(),
                            //   ),
                            // ),

                            // const SizedBox(height: 24),

                            // Bottom Padding
                            // const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Shimmer Loading Effect
  Widget _buildShimmerLoading() {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(dynamic error) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t('oopsSomethingWentWrong'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.refresh(fetchAllCategoriesProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: _homeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppStrings.t('tryAgain')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSearchBar() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: InkWell(
        onTap: () {
          _openRideBook(); // Changed from _openRideHome to _openRideBook
        },
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.t('whereTo'),
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _homeAccentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppStrings.t('now'),
                  style: TextStyle(
                    color: _homeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserGreeting() {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
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
              radius: 22,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  '${profile?.profileImage.toString()}',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 700),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 6 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: Text(
                    _timeGreeting(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile?.name ?? AppStrings.t('user'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLocations(List<RecentDropModel> recentDrops, bool isLoading) {
    if (isLoading) {
      return _buildRecentDropsShimmer();
    }

    if (recentDrops.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // locationTile(
            //   icon: Icons.history,
            //   title: "Select Citywalk Mall",
            //   sub: "Saket District Center, Pushp Vihar, New Delhi",
            //   color: Colors.blue,
            // ),
            // const Divider(height: 0, indent: 50),
            // locationTile(
            //   icon: Icons.favorite,
            //   title: "5, Kullar Farms Rd",
            //   sub: "Manglapuri Village, New Delhi",
            //   color: Colors.red,
            // ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(0),
          child: Row(
            children: [
             
             
            ],
          ),
        ),
        ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16,vertical:0),
          itemCount: recentDrops.length > 3 ? 3 : recentDrops.length,
          itemBuilder: (context, index) {
            final drop = recentDrops[index];
            return InkWell(
              onTap: () {
                _openRideBookWithLocation(drop); // Navigate to RideBookScreen
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 79, 78, 77).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on, color: Color.fromARGB(255, 78, 77, 75), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getShortAddress(drop.drop.address),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            drop.drop.address,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: 5,)
      ],
    );
  }

  Widget _buildRecentDropsShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 150,
                    height: 20,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            ...List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 16,
                            width: 120,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 12,
                            width: double.infinity,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getShortAddress(String fullAddress) {
    if (fullAddress.isEmpty) return AppStrings.t('unknownLocation');
    List<String> parts = fullAddress.split(',');
    if (parts.isEmpty) return fullAddress;
    return parts[0].trim();
  }

  Widget _buildCategoriesHeader(List<BannerCategory> categories) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppStrings.t('exploreCategories'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (categories.isNotEmpty)
            TextButton(
              onPressed: () => _openAllCategories(categories),
              style: TextButton.styleFrom(foregroundColor: _homeAccent),
              child: Text(AppStrings.t('seeAll')),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(List<BannerCategory> categories) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected =
              ref.watch(selectedCategoryIdProvider) == category.id;

          return TweenAnimationBuilder(
            duration: Duration(milliseconds: 200 + (index * 50)),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: GestureDetector(
              onTap: () {
                ref.read(selectedCategoryIdProvider.notifier).state =
                    category.id;
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isSelected
                          ? const LinearGradient(
                            colors: _homeAccentGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  color: isSelected ? null : Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    _cleanText(category.name),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionsHeader(List<VehicleType> vehicles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppStrings.t('suggestionsForYou'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (vehicles.isNotEmpty)
            TextButton(
              onPressed: () => _openAllSuggestions(vehicles),
              style: TextButton.styleFrom(foregroundColor: _homeAccent),
              child: Text(AppStrings.t('seeAll')),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypes(List<VehicleType> vihicle) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: vihicle.length,
        itemBuilder: (context, index) {
          final data = vihicle[index];
          return TweenAnimationBuilder(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () {
                  _openRideBook(); // Changed from _openRideHome to _openRideBook
                },
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Image.network(
                          data.image,
                          height: 50,
                          width: 50,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.directions_car,
                                color: Colors.black,
                                size: 30,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedCategorySection(
    List<BannerCategory> categories,
    String selectedCategoryId,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: _homeAccentGradient,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getCategoryName(categories, selectedCategoryId),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  final category = categories.firstWhere(
                    (c) => c.id == selectedCategoryId,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CategoryBannersPage(
                            categoryId: selectedCategoryId,
                            categoryName: category.cleanName,
                          ),
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: _homeAccent),
                child: Text(AppStrings.t('seeAll')),
              ),
            ],
          ),
        ),
        _buildBannersSection(selectedCategoryId),
      ],
    );
  }

  Widget _buildBannersSection(String categoryId) {
    return Consumer(
      builder: (context, ref, child) {
        final bannersAsync = ref.watch(
          fetchCategoryBannersProvider(categoryId),
        );

        return bannersAsync.when(
          loading: () => _buildBannerShimmer(),
          error: (error, stack) => _buildBannerError(error),
          data: (banners) {
            if (banners.isEmpty) {
              return _buildEmptyBanners();
            }

            return SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: banners.length > 5 ? 5 : banners.length,
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return _buildAnimatedBannerCard(banner, index);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedBannerCard(MyBanner banner, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () {
            // Banner click handler
          },
          child: Card(
            elevation: 2,
            shadowColor: Colors.grey.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (banner.image.isNotEmpty)
                          Image.network(
                            banner.image,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        else
                          Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        // Gradient overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.cleanTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          banner.cleanSubtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  Widget _buildBannerShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 150,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerError(dynamic error) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              AppStrings.t('oopsSomethingWentWrong'),
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBanners() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              AppStrings.t('noBannersAvailable'),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAroundYouHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _homeAccentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on, color: _homeAccent, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby Riders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Available around you',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '12 online',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(List<BannerCategory> categories, String? id) {
    if (id == null) return '';
    try {
      return categories.firstWhere((c) => c.id == id).cleanName;
    } catch (e) {
      return '';
    }
  }

  String _cleanText(String text) {
    if (text.isEmpty) return '';
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    return cleaned.trim();
  }
}

// Enhanced Location Tile Component
Widget locationTile({
  required IconData icon,
  required String title,
  required String sub,
  required Color color,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AllCategoriesPage extends StatelessWidget {
  final List<BannerCategory> categories;

  const AllCategoriesPage({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(AppStrings.t('allCategories')),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => CategoryBannersPage(
                        categoryId: category.id,
                        categoryName: category.cleanName,
                      ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _homeAccentGradient),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  category.cleanName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AllSuggestionsPage extends StatelessWidget {
  final List<VehicleType> vehicles;
  final SelectedLocation selectedLocation;

  const AllSuggestionsPage({
    super.key,
    required this.vehicles,
    required this.selectedLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(AppStrings.t('allVehicles')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: vehicles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final data = vehicles[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (selectedLocation.latitude == 0.0 &&
                  selectedLocation.longitude == 0.0) {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(
                    content: Text(
                      AppStrings.t('currentLocationNotAvailable'),
                    ),
                  ),
                );
                return;
              }
              // Navigate to RideBookScreen instead of RideHomePage
             Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => RideHomePage(
      currentLocation: SelectedLocation(
        latitude: selectedLocation.latitude,
        longitude: selectedLocation.longitude,
        address: selectedLocation.address ?? '',
      ),
    ),
  ),
);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        '${data.image}',
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.directions_car,
                              color: Colors.black,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data.bestFor ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
