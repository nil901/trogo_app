// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/models/vehicle_type_model.dart';
import 'package:trogo_app/rider_book_screen.dart';
import 'package:trogo_app/wigets/around_you_cars_loactions.dart';
import 'package:trogo_app/wigets/bannars.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final SelectedLocation selectedLocation;
  const HomeScreen({super.key, required this.selectedLocation});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Vehicle types fetch करो
      vehicletypesApi(ref, "passenger");
      
      // Categories fetch करो (यामुळे auto-select पण होईल)
      ref.refresh(fetchAllCategoriesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Categories fetch status watch करा
    final categoriesAsync = ref.watch(fetchAllCategoriesProvider);
    
    // Categories list
    final categories = ref.watch(bannerCategoryProvider);
    
    // Selected category ID
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    
    // Vehicle types
    final vihicle = ref.watch(vihicletypeProvider);
    
    print("🏠 HomeScreen build - Categories: ${categories.length}, Selected ID: $selectedCategoryId");

    return categoriesAsync.when(
      loading: () => const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.refresh(fetchAllCategoriesProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (_) {
        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // SEARCH BAR
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RideHomePage(
                                currentLocation: widget.selectedLocation,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey),
                              SizedBox(width: 10),
                              Text(
                                "Where to?",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // LOCATION 1
                    locationTile(
                      title: "Select Citywalk Mall",
                      sub: "Saket District Center,\nPushp Vihar, New Delhi",
                    ),

                    const Divider(),

                    // LOCATION 2
                    locationTile(
                      title: "5, Kullar Farms Rd",
                      sub: "Manglapuri Village,\nNew Delhi",
                    ),

                    // Categories List - Clickable categories
                    if (categories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected = selectedCategoryId == category.id;
                              
                              return GestureDetector(
                                onTap: () {
                                  // Category click handler - फक्त ID store करा
                                  ref.read(selectedCategoryIdProvider.notifier).state = category.id;
                                  print("✅ Category clicked: ${category.cleanName} (${category.id})");
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: isSelected ? Colors.blue : Colors.transparent,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _cleanText(category.name),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    // Suggestions
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideHomePage(
                              currentLocation: widget.selectedLocation,
                            ),
                          ),
                        );
                      },
                      child: sectionTitle("Suggestions", showSeeAll: true),
                    ),

                    // Vehicle Types
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final data = vihicle[index];
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RideHomePage(
                                      currentLocation: widget.selectedLocation,
                                    ),
                                  ),
                                );
                              },
                              child: SuggestionItem(
                                title: "${data.name}",
                                imagePath: "${data.image}",
                              ),
                            ),
                          );
                        },
                        itemCount: vihicle.length,
                        shrinkWrap: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Selected Category Banners - एकदाच call
                    if (selectedCategoryId != null) ...[
                      // Category Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getCategoryName(categories, selectedCategoryId),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final category = categories.firstWhere(
                                  (c) => c.id == selectedCategoryId,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryBannersPage(
                                      categoryId: selectedCategoryId,
                                      categoryName: category.cleanName,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                      ),
                      
                      // Banners - फक्त एकदा
                      _buildBannersSection(selectedCategoryId),
                      
                      const SizedBox(height: 24),
                    ],

                    // AROUND YOU
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Text(
                        "Around you",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    AroundYouCarsMap(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to get category name from ID
  String _getCategoryName(List<BannerCategory> categories, String? id) {
    if (id == null) return '';
    try {
      return categories.firstWhere((c) => c.id == id).cleanName;
    } catch (e) {
      return '';
    }
  }

  // Banners section - एकदाच define
  Widget _buildBannersSection(String categoryId) {
    return Consumer(
      builder: (context, ref, child) {
        final bannersAsync = ref.watch(fetchCategoryBannersProvider(categoryId));
        
        return bannersAsync.when(
          loading: () => Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text('Error: $error'),
                ],
              ),
            ),
          ),
          data: (banners) {
            if (banners.isEmpty) {
              return Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text('No banners available'),
                ),
              );
            }
            
            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: banners.length > 5 ? 5 : banners.length,
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildBannerCard(banner),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // Banner card widget
  Widget _buildBannerCard(MyBanner banner) {
    return GestureDetector(
      onTap: () {
        print("Banner clicked: ${banner.cleanTitle}");
      },
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: banner.image.isNotEmpty
                    ? Image.network(
                        banner.image,
                        width: double.infinity,
                        fit: BoxFit.cover,
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
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image, size: 40, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
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

  // HTML टॅग काढण्यासाठी
  String _cleanText(String text) {
    if (text.isEmpty) return '';
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    return cleaned.trim();
  }
}

//
// COMPONENTS
//

Widget locationTile({required String title, required String sub}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                sub,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget sectionTitle(String title, {bool showSeeAll = false}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (showSeeAll)
          const Text("See all", style: TextStyle(color: Colors.black)),
      ],
    ),
  );
}

class SuggestionItem extends StatelessWidget {
  final String title;
  final String imagePath;

  const SuggestionItem({
    super.key,
    required this.title,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Image.network(
              imagePath,
              height: 28,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.image_not_supported,
                  size: 28,
                  color: Colors.grey,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}