class PassengerSummary {
  final int totalRides;
  final int completedRides;
  final int cancelledRides;

  PassengerSummary({
    required this.totalRides,
    required this.completedRides,
    required this.cancelledRides,
  });

  factory PassengerSummary.fromJson(Map<String, dynamic> json) {
    return PassengerSummary(
      totalRides: json['totalRides'] ?? 0,
      completedRides: json['completedRides'] ?? 0,
      cancelledRides: json['cancelledRides'] ?? 0,
    );
  }
}
