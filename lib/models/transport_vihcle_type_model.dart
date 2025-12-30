class TransportVehicle {
  final String id;
  final String name;
  final String category;
  final String image;

  TransportVehicle({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
  });

  factory TransportVehicle.fromJson(Map<String, dynamic> json) {
    return TransportVehicle(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      image: json['image'] ?? '',
    );
  }
}
