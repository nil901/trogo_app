

import 'package:flutter/material.dart';
import 'package:trogo_app/Phone%20Number%20Screen.dart';
import 'package:trogo_app/api_service/active_booking_service.dart';
import 'package:trogo_app/language_selection_screen.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/transportergoods/transproter_first_screen.dart';


class SplashServices {
  final ActiveBookingService _activeBookingService = ActiveBookingService();

  Future<void> checkAuthentication(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 1));
    await routeNext(context);
  }

  Future<void> routeNext(BuildContext context) async {
    if (!context.mounted) return;

    final hasSelectedLanguage = AppPreference().getBool(
      PreferencesKey.languageSelected,
    );
    final selectedLanguage = AppPreference().getString(
      PreferencesKey.appLanguage,
    );
    if (!hasSelectedLanguage || selectedLanguage.isEmpty) {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LanguageSelectionScreen(),
        ),
      );
      return;
    }

    final token = AppPreference().getString(PreferencesKey.authToken);
    if (token.isEmpty) {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PhoneNumberScreen()),
      );
      return;
    }

    final activeBooking = await _activeBookingService.fetchActiveBooking(
      allowCacheFallback: false,
    );
    final shouldBlockRideRestore =
        await _activeBookingService.shouldBlockRideRestoreForTransporter();
    if (!context.mounted) return;

    if (!shouldBlockRideRestore &&
        _activeBookingService.shouldResumeRide(activeBooking)) {
      final pickup = activeBooking?['pickup'] as Map<String, dynamic>?;
      final pickupCoordinates = _extractCoordinates(pickup);
      final bookingType = activeBooking?['bookingType']?.toString().toLowerCase();

      if (pickupCoordinates != null && pickupCoordinates.length >= 2) {
        final pickupLocation = SelectedLocation(
          latitude: (pickupCoordinates[1] as num).toDouble(),
          longitude: (pickupCoordinates[0] as num).toDouble(),
          address: pickup?['address']?.toString(),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (bookingType == 'goods') {
                return TransportRideHomePage(
                  currentLocation: pickupLocation,
                  initialActiveRide: activeBooking,
                  restoreToDriverConnecting: true,
                );
              }

              return RideHomePage(
                currentLocation: pickupLocation,
                initialActiveRide: activeBooking,
                restoreToDriverConnecting: true,
              );
            },
          ),
        );
        return;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LocationPermissionScreen()),
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

}
