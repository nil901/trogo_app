// utils/booking_utils.dart
import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class BookingUtils {
  static Future<Map<String, dynamic>> getBookingStatus(String bookingId) async {
    final token = AppPreference().getString(PreferencesKey.authToken);
    final response = await http.get(
      Uri.parse('https://trogo-app-backend.onrender.com/api/bookings/$bookingId/status'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get booking status');
  }

  static Future<void> cancelBooking(String bookingId) async {
    final token = AppPreference().getString(PreferencesKey.authToken);
    await http.post(
      Uri.parse('https://trogo-app-backend.onrender.com/api/bookings/$bookingId/cancel'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  static Future<void> rateDriver(String bookingId, int rating, String? comment) async {
    final token = AppPreference().getString(PreferencesKey.authToken);
    await http.post(
      Uri.parse('https://trogo-app-backend.onrender.com/api/bookings/$bookingId/rate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'rating': rating,
        'comment': comment,
      }),
    );
  }
}

// utils/map_utils.dart
class MapUtils {
  static Future<List<LatLng>> getRoutePolyline(
    LatLng origin,
    LatLng destination,
  ) async {
    // Implement Google Directions API call
    // Return list of LatLng points for polyline
    return [origin, destination];
  }

  static double calculateFare(
    double distance,
    double duration,
    String vehicleType,
  ) {
    double baseFare = 50;
    double distanceFare = distance * 15;
    double timeFare = duration * 2;
    
    return baseFare + distanceFare + timeFare;
  }
}