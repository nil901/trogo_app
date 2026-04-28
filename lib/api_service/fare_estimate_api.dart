import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/login_notifier.dart' show fareEstimateProvider;
import '../models/estimateurl_model.dart';
import 'api_service.dart';
import 'urls.dart';

Future<List<FareEstimate>> fareEstimateApi({
  required WidgetRef ref,
  required String category,
  required String vehicleTypeId,
  required String pickupAddress,
  required List<double> pickupCoordinates,
  required String dropAddress,
  required List<double> dropCoordinates,
}) async {
  try {
    final body = <String, dynamic>{
      "category": category,
      "drop": {
        "coordinates": dropCoordinates,
      },
    };

    if (vehicleTypeId.trim().isNotEmpty) {
      body["vehicleTypeId"] = vehicleTypeId.trim();
    }

    debugPrint("STEP 4: API HIT");
    debugPrint("fareEstimateApi URL: $fareEstimateUrl");
    debugPrint("BODY: $body");

    final response = await ApiService().postRequest(fareEstimateUrl, body);
    debugPrint("fareEstimateApi status: ${response?.statusCode}");
    debugPrint("RESPONSE: ${response?.data}");

    if (response != null && response.statusCode == 200) {
      final vehicles = response.data['vehicles'];
      if (vehicles is List) {
        final fares =
            vehicles
                .map((json) => FareEstimate.fromJson(json))
                .toList();
        ref.read(fareEstimateProvider.notifier).state = fares;
        return fares;
      }
    }
  } catch (e) {
    debugPrint("fareEstimateApi exception: $e");
  }

  ref.read(fareEstimateProvider.notifier).state = [];
  return [];
}
