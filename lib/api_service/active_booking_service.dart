import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class ActiveBookingService {
  static const List<String> _restorableStatuses = [
    'requested',
    'accepted',
    'arriving',
    'ongoing',
  ];
  static const List<String> _terminalStatuses = [
    'completed',
    'cancelled',
  ];

  Future<Map<String, dynamic>?> fetchActiveBooking({
    bool allowCacheFallback = true,
  }) async {
    final token = AppPreference().getString(PreferencesKey.authToken);
    if (token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('${baseUrl}bookings/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        await clearCachedActiveBooking();
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        await clearCachedActiveBooking();
        return null;
      }

      final booking = decoded['booking'];
      if (booking is! Map<String, dynamic>) {
        await clearCachedActiveBooking();
        return null;
      }

      final bookingStatus = booking['status']?.toString().toLowerCase();
      if (bookingStatus != null && _terminalStatuses.contains(bookingStatus)) {
        await clearCachedActiveBooking();
        return null;
      }

      if (!_isRestorableBooking(booking)) {
        await clearCachedActiveBooking();
        return null;
      }

      final normalized = Map<String, dynamic>.from(booking);
      await cacheActiveBooking(normalized);
      return normalized;
    } catch (_) {
      if (allowCacheFallback) {
        final cachedBooking = getCachedActiveBooking();
        final cachedStatus = cachedBooking?['status']?.toString().toLowerCase();
        if (cachedStatus != null && _terminalStatuses.contains(cachedStatus)) {
          await clearCachedActiveBooking();
          return null;
        }
        return cachedBooking;
      }
      return null;
    }
  }

  Future<bool> shouldBlockRideRestoreForTransporter() async {
    final token = AppPreference().getString(PreferencesKey.authToken);
    if (token.isEmpty) return false;
    if (_extractTokenType(token) != 'transporter') return false;

    try {
      final response = await http.get(
        Uri.parse(transporterGlobalStatusUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) return false;
  
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return false;

      final statusPayload = decoded['status'];
      if (statusPayload is! Map<String, dynamic>) return false;

      final activeBooking = statusPayload['activeBooking'];
      if (activeBooking is! Map<String, dynamic>) return false;

      final bookingStatus = activeBooking['status']?.toString().toLowerCase();
      if (bookingStatus == null || bookingStatus.isEmpty) return false;

      if (_terminalStatuses.contains(bookingStatus)) {
        await clearCachedActiveBooking();
        return true;
      }

      return !_restorableStatuses.contains(bookingStatus);
    } catch (_) {
      return false;
    }
  }

  bool shouldResumeRide(Map<String, dynamic>? booking) {
    if (booking == null) return false;
    final bookingId = booking['_id']?.toString();
    final pickup = booking['pickup'];
    final drop = booking['drop'];
    final driver = booking['driver'];
    final transporter = booking['transporter'];
    final hasAssignedDriver =
        driver is Map<String, dynamic> ||
        transporter is Map<String, dynamic> ||
        booking['driverId'] != null ||
        booking['transporterId'] != null;

    return _isRestorableBooking(booking) &&
        bookingId != null &&
        bookingId.isNotEmpty &&
        pickup is Map &&
        drop is Map &&
        hasAssignedDriver;
  }

  bool _isRestorableBooking(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    return status != null && _restorableStatuses.contains(status);
  }

  String? _extractTokenType(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = json.decode(decoded);
      if (payload is Map<String, dynamic>) {
        return payload['type']?.toString().toLowerCase();
      }
    } catch (_) {}

    return null;
  }

  Future<void> cacheActiveBooking(Map<String, dynamic> booking) async {
    await AppPreference().setString(
      PreferencesKey.activeRideJson,
      json.encode(booking),
    );
  }

  Map<String, dynamic>? getCachedActiveBooking() {
    final raw = AppPreference().getString(PreferencesKey.activeRideJson);
    if (raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  Future<void> clearCachedActiveBooking() async {
    await AppPreference().setString(PreferencesKey.activeRideJson, '');
  }
}
