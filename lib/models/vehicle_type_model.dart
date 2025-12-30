class VehicleType {
  final dynamic? id;
  final dynamic? name;
  final dynamic? seatCapacity;
  final dynamic? image;
  final dynamic? bestFor;
  final dynamic? category;
  final dynamic? pricingType;
  final dynamic? baseFare;
  final dynamic? rate;
  final bool? isActive;
  // final DateTime? createdAt;
  // final DateTime? updatedAt;
  final dynamic? v;

  VehicleType({
    this.id,
    this.name,
    this.seatCapacity,
    this.image,
    this.bestFor,
    this.category,
    this.pricingType,
    this.baseFare,
    this.rate,
    this.isActive,
    // this.createdAt,
    // this.updatedAt,
    this.v,
  });

  factory VehicleType.fromJson(Map<dynamic, dynamic> json) {
    return VehicleType(
      id: json['_id'],
      name: json['name'],
      seatCapacity: json['seatCapacity'],
      image: json['image'],
      bestFor: json['bestFor'],
      category: json['category'],
      pricingType: json['pricingType'],
      baseFare: json['baseFare'],
      rate: json['rate'],
      isActive: json['isActive'],
      // createdAt: json['createdAt'] != null
      //     ? DateTime.parse(json['createdAt'])
      //     : null,
      // updatedAt: json['updatedAt'] != null
      //     ? DateTime.parse(json['updatedAt'])
      //     : null,
      v: json['__v'],
    );
  }

  Map<dynamic, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'seatCapacity': seatCapacity,
      'image': image,
      'bestFor': bestFor,
      'category': category,
      'pricingType': pricingType,
      'baseFare': baseFare,
      'rate': rate,
      'isActive': isActive,
      // 'createdAt': createdAt?.toIso8601dynamic(),
      // 'updatedAt': updatedAt?.toIso8601dynamic(),
      '__v': v,
    };
  }
}
