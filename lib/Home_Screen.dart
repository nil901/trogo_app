import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
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
@override
void initState() {
  super.initState();
 

  Future.microtask(() {

    vehicletypesApi(ref, "passenger");
  });
}

  @override
  Widget build(BuildContext context) {
    final vihicle = ref.read(vihicletypeProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 🔍 SEARCH BAR
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: (){
                       Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => RideHomePage(
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
                          Text("Where to?", style: TextStyle(color: Colors.grey)),
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

                // PAYMENT CARD
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xffF6C667),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Finalize payment:",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "₹170.71",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Pay →",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.notifications_none),
                        ),
                      ],
                    ),
                  ),
                ),

                // SUGGESTIONS
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => RideHomePage(
                              currentLocation: widget.selectedLocation,
                            ),
                      ),
                    );
                  },
                  child: sectionTitle("Suggestions", showSeeAll: true),
                ),

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
                        child: SuggestionItem(
                          title: "${data.name}",
                          imagePath: "${data.image}",
                        ),
                      );
                    },
                    itemCount: vihicle.length,
                    shrinkWrap: true,
                    // physics: const NeverScrollableScrollPhysics(),
                  ),
                ),

                const SizedBox(height: 24),

                // RIDE WITH US
                sectionTitle("Ride with us"),
                AllBannersWidget(),
                const SizedBox(height: 24),
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 16),
                //   child: ClipRRect(
                //     borderRadius: BorderRadius.circular(20),
                //     child: Image.asset(
                //       "assets/images/sedan.png",
                //       width: double.infinity,
                //       height: 130,
                //       fit: BoxFit.cover,
                //     ),
                //   ),
                // ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Ways to plan with Trogo",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                AllBannersWidget(),

                const SizedBox(height: 24),

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

Widget planCard({
  required String image,
  required String title,
  required String subtitle,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            image,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
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
