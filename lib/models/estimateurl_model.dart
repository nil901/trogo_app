class FareEstimate {
  final String vehicleTypeId;
  final String name;
  final String image;
  final String bestFor;
  final double distanceKm;
  final int etaMinutes;
  final int estimatedFare;

  FareEstimate({
    required this.vehicleTypeId,
    required this.name,
    required this.image,
    required this.bestFor,
    required this.distanceKm,
    required this.etaMinutes,
    required this.estimatedFare,
  });

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    return FareEstimate(
      vehicleTypeId: json['vehicleTypeId'],
      name: json['name'],
      image: json['image'],
      bestFor: json['bestFor'],
      distanceKm: (json['distanceKm'] as num).toDouble(),
      etaMinutes: json['etaMinutes'],
      estimatedFare: json['estimatedFare'],
    );
  }
}
