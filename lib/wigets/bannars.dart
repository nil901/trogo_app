// lib/wigets/bannars.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

// Category Model
class BannerCategory {
  final String id;
  final String name;
  final String createdAt;
  final String updatedAt;
  
  BannerCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory BannerCategory.fromJson(Map<String, dynamic> json) {
    return BannerCategory(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
  
  // Clean name without HTML tags
  String get cleanName {
    return _cleanText(name);
  }
}

// MyBanner Model
class MyBanner {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String image;
  final String createdAt;
  final String updatedAt;
  
  MyBanner({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory MyBanner.fromJson(Map<String, dynamic> json) {
    return MyBanner(
      id: json['_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
  
  // Clean text without HTML tags
  String get cleanTitle => _cleanText(title);
  String get cleanSubtitle => _cleanText(subtitle);
}

// Helper function to clean HTML tags
String _cleanText(String text) {
  if (text.isEmpty) return '';
  String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
  cleaned = cleaned
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
  return cleaned.trim();
}

// API Service
class BannerApiService {
  // Get auth token
  String? get _authToken {
    return AppPreference().getString(PreferencesKey.authToken);
  }
  
  // Get headers with authorization
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null && _authToken!.isNotEmpty) 
        'Authorization': 'Bearer $_authToken',
    };
  }
  
  // 1. सभी categories fetch करें
  Future<List<BannerCategory>> getAllCategories() async {
    try {
      print("🔵=== Fetching all categories ===");
      final response = await http.get(
        Uri.parse('${baseUrl}admin/banners/category/public'),
        headers: _headers,
      );
      
      print("🔵 Categories Response Status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['categories'] != null) {
          final categoriesList = data['categories'] as List;
          print("🔵 Categories found: ${categoriesList.length}");
          return categoriesList
              .map((json) => BannerCategory.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print("🔵 Error fetching categories: $e");
      return [];
    }
  }
  
  // 2. Specific category के banners fetch करें
  Future<List<MyBanner>> getBannersByCategory(String categoryId) async {
    try {
      print("🟡=== Fetching banners for category: $categoryId ===");
      final response = await http.get(
        Uri.parse('${baseUrl}admin/banners/public?categoryId=$categoryId'),
        headers: _headers,
      );
      
      print("🟡 Banners Response Status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['banners'] != null) {
          final bannersList = data['banners'] as List;
          print("🟡 Banners found: ${bannersList.length}");
          return bannersList
              .map((json) => MyBanner.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print("🟡 Error fetching banners: $e");
      return [];
    }
  }
}

// ========== PROVIDERS ==========

// Categories list provider
final bannerCategoryProvider = StateProvider<List<BannerCategory>>((ref) => []);

// Selected category ID provider (सोपे - फक्त ID)
final selectedCategoryIdProvider = StateProvider<String?>((ref) => null);

// Fetch all categories
final fetchAllCategoriesProvider = FutureProvider.autoDispose((ref) async {
  print("🔵🔵🔵 fetchAllCategoriesProvider started");
  final apiService = BannerApiService();
  final categories = await apiService.getAllCategories();
  print("🔵🔵🔵 Categories fetched: ${categories.length}");
  
  ref.read(bannerCategoryProvider.notifier).state = categories;
  
  // Auto-select first category
  if (categories.isNotEmpty) {
    ref.read(selectedCategoryIdProvider.notifier).state = categories.first.id;
  }
  
  return categories;
});

// Fetch banners for specific category (FAMILY PROVIDER - योग्य)
final fetchCategoryBannersProvider = FutureProvider.autoDispose.family<List<MyBanner>, String>((ref, categoryId) async {
  print("🔴🔴🔴 Fetching banners for category ID: $categoryId");
  
  if (categoryId.isEmpty) return [];
  
  final apiService = BannerApiService();
  final banners = await apiService.getBannersByCategory(categoryId);
  print("🔴🔴🔴 Banners fetched: ${banners.length}");
  
  return banners;
});

// Category Banners Page
class CategoryBannersPage extends ConsumerWidget {
  final String categoryId;
  final String categoryName;
  
  const CategoryBannersPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(fetchCategoryBannersProvider(categoryId));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: bannersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.refresh(fetchCategoryBannersProvider(categoryId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (banners) {
          if (banners.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No banners found in this category',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return _buildBannerGridItem(banner);
            },
          );
        },
      ),
    );
  }

  Widget _buildBannerGridItem(MyBanner banner) {
    return GestureDetector(
      onTap: () {
        print("Banner clicked: ${banner.cleanTitle}");
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: banner.image.isNotEmpty
                    ? Image.network(
                        banner.image,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.cleanTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banner.cleanSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}