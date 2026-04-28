// lib/models/user_profile.dart

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String gender;
  final String? profileImage;
  final Location? location;
  final DateTime createdAt;
  final String? fcmToken;
  final dynamic passwordHash;
  final dynamic logoutAt;
  final int pendingCancellationFee;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.gender,
    this.profileImage,
    this.location,
    required this.createdAt,
    this.fcmToken,
    this.passwordHash,
    this.logoutAt,
    this.pendingCancellationFee = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      profileImage: json['profileImage']?.toString(),
      location: json['location'] != null ? Location.fromJson(json['location']) : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()) 
          : DateTime.now(),
      fcmToken: json['fcmToken']?.toString(),
      passwordHash: json['passwordHash'],
      logoutAt: json['logoutAt'],
      pendingCancellationFee: json['pendingCancellationFee'] is int 
          ? json['pendingCancellationFee'] 
          : (json['pendingCancellationFee'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'gender': gender,
      'profileImage': profileImage,
      'location': location?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'fcmToken': fcmToken,
      'passwordHash': passwordHash,
      'logoutAt': logoutAt,
      'pendingCancellationFee': pendingCancellationFee,
    };
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
    // Handle coordinates that might be integers or doubles
    final coords = json['coordinates'];
    List<double> doubleCoords = [];
    
    if (coords != null && coords is List) {
      doubleCoords = coords.map((coord) {
        if (coord is int) {
          return coord.toDouble();
        } else if (coord is double) {
          return coord;
        } else if (coord is num) {
          return coord.toDouble();
        } else {
          return 0.0;
        }
      }).toList();
    }
    
    return Location(
      type: json['type']?.toString() ?? 'Point',
      coordinates: doubleCoords,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }
}