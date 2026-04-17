class RecentDrop {
  final String id;
  final String address;
  final double lat;
  final double lng;
  final String lastUsedAt;

  RecentDrop({
    required this.id,
    required this.address,
    required this.lat,
    required this.lng,
    required this.lastUsedAt,
  });

  factory RecentDrop.fromJson(Map<String, dynamic> json) {
    final drop = json['drop'] as Map<String, dynamic>? ?? {};
    final coordinates = drop['coordinates'] as List<dynamic>? ?? [];
    
    return RecentDrop(
      id: json['_id'] ?? '',
      address: drop['address'] ?? '',
      lat: (coordinates.length > 1 ? coordinates[1] : 0.0) as double,
      lng: (coordinates.isNotEmpty ? coordinates[0] : 0.0) as double,
      lastUsedAt: json['lastUsedAt'] ?? '',
    );
  }
}
