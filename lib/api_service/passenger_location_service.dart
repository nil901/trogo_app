import 'package:flutter/foundation.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';

class PassengerLocationService {
  Future<void> syncPassengerLocation({
    required double latitude,
    required double longitude,
    String source = 'unknown',
  }) async {
    if (!latitude.isFinite || !longitude.isFinite) {
      debugPrint(
        'Passenger location skipped for $source because coordinates are invalid.',
      );
      return;
    }

    if (latitude == 0.0 && longitude == 0.0) {
      debugPrint(
        'Passenger location skipped for $source because coordinates are 0,0.',
      );
      return;
    }

    try {
      final payload = {
        'longitude':longitude ,
        'latitude': latitude,
      };

      debugPrint('Passenger location endpoint: $passengerLocationUrl');
      debugPrint('Passenger location source: $source');
      debugPrint('Passenger location request: $payload');

      final response = await ApiService().postRequest(
        passengerLocationUrl,
        payload,
        
      );

      debugPrint('Passenger location status: ${response?.statusCode}');
      debugPrint('Passenger location response: ${response?.data}');
    } catch (e) {
      debugPrint('Passenger location sync failed for $source: $e');
    }
  }
}
