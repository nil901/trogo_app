class BookingHistory {
  final String id;
  final Passenger passenger;
  final String vehicleType;
  final String bookingType;
  final PickupLocation pickup;
  final DropLocation drop;
  final double distanceKm;
  final double estimatedFare;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<String> packageImage;
  final ScheduleDetails? schedule;
  final GoodsDetails? goods;
  final ReceiverDetails? receiver;
  final PaymentDetails? payment;

  final String? paymentBy;
  final String? paymentType;
  final double? finalFare;
  final Transporter? transporter;
  final String? type;
  final String? vehicle;

  BookingHistory({
    required this.id,
    required this.passenger,
    required this.vehicleType,
    required this.bookingType,
    required this.pickup,
    required this.drop,
    required this.distanceKm,
    required this.estimatedFare,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.packageImage,
    this.schedule,
    this.goods,
    this.receiver,
    this.payment,
    this.paymentBy,
    this.paymentType,
    this.finalFare,
    this.transporter,
    this.type,
    this.vehicle,
  });

  factory BookingHistory.fromJson(Map<String, dynamic> json) {
    return BookingHistory(
      id: json['_id'] ?? '',
      passenger: Passenger.fromJson(json['passenger'] ?? {}),
      vehicleType: json['vehicleType']?.toString() ?? '',
      bookingType: json['bookingType'] ?? '',
      pickup: PickupLocation.fromJson(json['pickup'] ?? {}),
      drop: DropLocation.fromJson(json['drop'] ?? {}),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedFare: (json['estimatedFare'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),

      packageImage: (json['packageImage'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],

      schedule: json['scheduleDate'] != null
          ? ScheduleDetails(
              date: json['scheduleDate'] ?? '',
              time: json['scheduleTime'] ?? '',
            )
          : null,

      goods: json['goods'] != null
          ? GoodsDetails.fromJson(json['goods'])
          : null,

      receiver: json['receiver'] != null
          ? ReceiverDetails.fromJson(json['receiver'])
          : null,

      payment: json['payment'] != null
          ? PaymentDetails.fromJson(json['payment'])
          : null,

      paymentBy: json['paymentBy'],
      paymentType: json['paymentType'],
      finalFare: (json['finalFare'] as num?)?.toDouble(),
      transporter: json['transporter'] != null
          ? Transporter.fromJson(json['transporter'])
          : null,

      type: json['type'],
      vehicle: json['vehicle'],
    );
  }
}
class Passenger {
  final String id;
  final String name;
  final String? profileImage;

  Passenger({
    required this.id,
    required this.name,
    this.profileImage,
  });

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      profileImage: json['profileImage'],
    );
  }
}
class PickupLocation {
  final String address;
  final Location location;

  PickupLocation({
    required this.address,
    required this.location,
  });

  factory PickupLocation.fromJson(Map<String, dynamic> json) {
    return PickupLocation(
      address: json['address'] ?? '',
      location: Location.fromJson(json['location'] ?? {}),
    );
  }
}

class DropLocation {
  final String address;
  final Location location;

  DropLocation({
    required this.address,
    required this.location,
  });

  factory DropLocation.fromJson(Map<String, dynamic> json) {
    return DropLocation(
      address: json['address'] ?? '',
      location: Location.fromJson(json['location'] ?? {}),
    );
  }
}
class Location {
  final String type;
  final List<double> coordinates;

  Location({
    required this.type,
    required this.coordinates,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List?;
    return Location(
      type: json['type'] ?? 'Point',
      coordinates:
          coords?.map((e) => (e as num).toDouble()).toList() ?? [],
    );
  }
}
class ScheduleDetails {
  final String date;
  final String time;

  ScheduleDetails({
    required this.date,
    required this.time,
  });
}
class GoodsDetails {
  final String name;
  final double weightKg;

  GoodsDetails({
    required this.name,
    required this.weightKg,
  });

  factory GoodsDetails.fromJson(Map<String, dynamic> json) {
    return GoodsDetails(
      name: json['name'] ?? '',
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
class ReceiverDetails {
  final String name;
  final String phone;

  ReceiverDetails({
    required this.name,
    required this.phone,
  });

  factory ReceiverDetails.fromJson(Map<String, dynamic> json) {
    return ReceiverDetails(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}
class PaymentDetails {
  final bool paid;

  PaymentDetails({required this.paid});

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      paid: json['paid'] ?? false,
    );
  }
}
class Transporter {
  final String id;
  final String name;
  final String mobile;
  final String? profileImage;

  Transporter({
    required this.id,
    required this.name,
    required this.mobile,
    this.profileImage,
  });

  factory Transporter.fromJson(Map<String, dynamic> json) {
    return Transporter(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      profileImage: json['profileImage'],
    );
  }
}
