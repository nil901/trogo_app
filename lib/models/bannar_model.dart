// models/banner_model.dart
class BannerCategory {
  final String id;
  final String name;
  
  BannerCategory({
    required this.id,
    required this.name,
  });
  
  factory BannerCategory.fromJson(Map<String, dynamic> json) {
    return BannerCategory(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class Banners {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String image;
  
  Banners({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.image,
  });
  
  factory Banners.fromJson(Map<String, dynamic> json) {
    return Banners(
      id: json['_id'] ?? '',
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      image: json['image'] ?? '',
    );
  }
}