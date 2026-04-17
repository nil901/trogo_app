import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/estimateurl_model.dart';

Future<List<FareEstimate>> fareEstimateApi({
  required WidgetRef ref,
  required String category,
  required String vehicleTypeId,
  required String pickupAddress,
  required List<double> pickupCoordinates,
  required String dropAddress,
  required List<double> dropCoordinates,
}) async {
  // Mock implementation - replace with real API call later
  await Future.delayed(const Duration(milliseconds: 1500));

  // Calculate mock distance
  final double latDiff = dropCoordinates[0] - pickupCoordinates[0];
  final double lngDiff = dropCoordinates[1] - pickupCoordinates[1];
  final double distanceKm = (latDiff.abs() + lngDiff.abs()) * 111; // Rough km estimate

  return [
    FareEstimate(
      vehicleTypeId: vehicleTypeId.isNotEmpty ? vehicleTypeId : 'sedan',
      name: 'Sedan',
      image: 'assets/images/sedan.png',
      bestFor: 'Solo or couple',
      distanceKm: distanceKm,
      etaMinutes: (distanceKm * 3).round(),
      estimatedFare: (distanceKm * 25).round().toInt(),
    ),
    FareEstimate(
      vehicleTypeId: vehicleTypeId == 'suv' ? vehicleTypeId : 'suv',
      name: 'SUV',
      image: 'assets/images/suv.png',
      bestFor: 'Family or luggage',
      distanceKm: distanceKm,
      etaMinutes: (distanceKm * 3.5).round(),
      estimatedFare: (distanceKm * 35).round().toInt(),
    ),
  ];
}
