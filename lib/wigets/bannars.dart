import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

class Banner {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String image;
  
  Banner({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.image,
  });
  
  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: json['_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
    );
  }
}

class ApiService {
  static const String baseUrl = "https://trogo-app-backend.onrender.com";
  static const String token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY5MmE5YTY5YTVmNmE1YjZjM2RhNmViMiIsInR5cGUiOiJhZG1pbiIsImlhdCI6MTc2NjQ2MjUyMywiZXhwIjoxNzY3MDY3MzIzfQ.Hxl4GIzrge0EMGPE6GU4dNqB6cHAMv_mNwjzc5aOoKw";
  
  // सभी categories के banners fetch करें
  Future<List<Banner>> getAllBanners() async {
    try {
      print("=== Starting getAllBanners() ===");
      
      // 1. सभी categories fetch करें
      final categoriesResponse = await http.get(
        Uri.parse('$baseUrl/api/admin/banners/category'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (categoriesResponse.statusCode != 200) {
        print("Categories Error: ${categoriesResponse.statusCode}");
        return [];
      }
      
      final categoriesData = json.decode(categoriesResponse.body);
      final categoriesList = categoriesData['categories'] as List;
      
      if (categoriesList.isEmpty) {
        print("No categories found");
        return [];
      }
      
      print("Total categories: ${categoriesList.length}");
      
      // 2. हर category के banners fetch करें
      List<Banner> allBanners = [];
      
      for (var category in categoriesList) {
        final categoryId = category['_id'];
        final categoryName = category['name'];
        
        print("\nFetching banners for category: $categoryName (ID: $categoryId)");
        
        try {
          final bannersResponse = await http.get(
            Uri.parse('$baseUrl/api/admin/banners?categoryId=$categoryId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          
          if (bannersResponse.statusCode == 200) {
            final bannersData = json.decode(bannersResponse.body);
            final bannersList = bannersData['banners'] as List;
            
            print("Found ${bannersList.length} banners in this category");
            
            for (var bannerJson in bannersList) {
              allBanners.add(Banner.fromJson(bannerJson));
            }
          } else {
            print("Failed to fetch banners for category $categoryId: ${bannersResponse.statusCode}");
          }
          
          // थोड़ा delay (optional)
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          print("Error fetching banners for category $categoryId: $e");
        }
      }
      
      print("\n=== Total banners fetched: ${allBanners.length} ===");
      return allBanners;
      
    } catch (e) {
      print("Error in getAllBanners: $e");
      return [];
    }
  }
  
  // Type safe version with parallel fetching
  Future<List<Banner>> getBannersWithContent() async {
    try {
      // 1. सभी categories fetch करें
      final categoriesResponse = await http.get(
        Uri.parse('$baseUrl/api/admin/banners/category'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (categoriesResponse.statusCode != 200) return [];
      
      final categoriesData = json.decode(categoriesResponse.body);
      final categoriesList = categoriesData['categories'] as List;
      
      if (categoriesList.isEmpty) return [];
      
      // 2. Parallel में सभी categories के banners fetch करें
      List<Future<List<Banner>>> bannerFutures = [];
      
      for (var category in categoriesList) {
        final categoryId = category['_id'];
        
        // Type को स्पष्ट रूप से define करें
        Future<List<Banner>> bannerFuture = http.get(
          Uri.parse('$baseUrl/api/admin/banners?categoryId=$categoryId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).then((http.Response response) {
          if (response.statusCode == 200) {
            final bannersData = json.decode(response.body);
            final bannersList = bannersData['banners'] as List;
            return bannersList.map<Banner>((json) => Banner.fromJson(json)).toList();
          }
          return <Banner>[]; // Empty list with explicit type
        }).catchError((e) {
          return <Banner>[]; // Empty list with explicit type
        });
        
        bannerFutures.add(bannerFuture);
      }
      
      // 3. सभी results combine करें
      final List<List<Banner>> allResults = await Future.wait(bannerFutures);
      List<Banner> allBanners = [];
      
      for (var bannerList in allResults) {
        allBanners.addAll(bannerList);
      }
      
      return allBanners;
      
    } catch (e) {
      print("Error in getBannersWithContent: $e");
      return [];
    }
  }
  
  // Even simpler version
  Future<List<Banner>> getAllBannersSimple() async {
    try {
      // 1. Get categories
      final categoriesResponse = await http.get(
        Uri.parse('$baseUrl/api/admin/banners/category'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (categoriesResponse.statusCode != 200) return [];
      
      final categoriesData = json.decode(categoriesResponse.body);
      final categoriesList = categoriesData['categories'] as List;
      
      // 2. Get banners for each category
      List<Banner> allBanners = [];
      
      for (var category in categoriesList) {
        final categoryId = category['_id'];
        
        final bannersResponse = await http.get(
          Uri.parse('$baseUrl/api/admin/banners?categoryId=$categoryId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        if (bannersResponse.statusCode == 200) {
          final bannersData = json.decode(bannersResponse.body);
          final bannersList = bannersData['banners'] as List;
          
          for (var bannerJson in bannersList) {
            allBanners.add(Banner.fromJson(bannerJson));
          }
        }
      }
      
      return allBanners;
      
    } catch (e) {
      print("Error: $e");
      return [];
    }
  }
}

// Provider for all banners
final allBannersProvider = StateProvider<List<Banner>>((ref) => []);

// Future provider
final fetchAllBannersProvider = FutureProvider.autoDispose((ref) async {
  final apiService = ApiService();
  final banners = await apiService.getAllBannersSimple();
  ref.read(allBannersProvider.notifier).state = banners;
  return banners;
});

// Main Widget
class AllBannersWidget extends ConsumerWidget {
  const AllBannersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(allBannersProvider);
    final bannerFuture = ref.watch(fetchAllBannersProvider);
    
    return bannerFuture.when(
      loading: () => _buildLoading(),
      error: (error, stackTrace) => _buildError(error.toString(), ref),
      data: (_) => _buildBanners(banners),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 170,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: List.generate(3, (index) => 
          Padding(
            padding: EdgeInsets.only(right: index < 2 ? 12 : 0),
            child: _buildShimmerCard(),
          )
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _buildError(String error, WidgetRef ref) {
    return Container(
      height: 170,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            const Text(
              'Failed to load banners',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => ref.refresh(fetchAllBannersProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanners(List<Banner> banners) {
    if (banners.isEmpty) {
      return SizedBox(
        height: 170,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported_outlined, 
                  size: 50, color: Colors.grey[400]),
              const SizedBox(height: 10),
              const Text(
                'No banners found',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 170,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...banners.map((banner) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildBannerCard(banner),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBannerCard(Banner banner) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            child: Center(
              child: banner.image.isNotEmpty
                  ? Image.network(
                      banner.image,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 40,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Image failed',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        );
                      },
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 40,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'No image',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _parseHtml(banner.title),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _parseHtml(banner.subtitle),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _parseHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    
    String text = htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
    
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    
    return text.trim();
  }
}

// Alternative: Simple version like your original code
class SimpleBannersWidget extends ConsumerWidget {
  const SimpleBannersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(allBannersProvider);
    
    if (banners.isEmpty) {
      return SizedBox(
        height: 170,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildShimmer(),
            const SizedBox(width: 12),
            _buildShimmer(),
            const SizedBox(width: 12),
            _buildShimmer(),
          ],
        ),
      );
    }
    
    return SizedBox(
      height: 170,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...banners.map((banner) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: rideCard(
                title: _cleanText(banner.title),
                subtitle: _cleanText(banner.subtitle),
                image: banner.image,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget rideCard({
    required String title,
    required String subtitle,
    required String image,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, color: Colors.grey);
                      },
                    )
                  : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}