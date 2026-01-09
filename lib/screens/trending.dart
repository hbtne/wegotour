import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stour/assets/icons/rankings_svg.dart';
import 'package:stour/screens/ranking_screen.dart';
import 'package:stour/util/places.dart';
import 'package:stour/widgets/search_card.dart';
import 'package:stour/widgets/trending_place.dart';

class Trending extends StatefulWidget {
  final List<Place> source;
  final String collectionName;
  const Trending({super.key, required this.source, required this.collectionName});

  @override
  State<Trending> createState() => _TrendingState();
}

class _TrendingState extends State<Trending> {
  String? selectedCity;
  String? selectedDistrict;
  double minRating = 0.0;
  double maxPrice = 10000000.0;

  List<String> getUniqueCities() {
    return widget.source
        .map((e) => e.city)
        .toSet()
        .toList();
  }

  List<String> getDistrictsForSelectedCity() {
    return widget.source
        .where((e) => e.city == selectedCity)
        .map((e) => e.district)
        .toSet()
        .toList();
  }

  List<Place> getFilteredPlaces() {
    return widget.source.where((place) {
      final ratingCount = place.ratingCountYear ?? 0;
      final rating = ratingCount == 0 || place.ratingSumYear == 0
          ? 0.0
          : (place.ratingSumYear ?? 3) / ratingCount;
      final price = place.price.toDouble();

      return (selectedCity == null || place.city == selectedCity) &&
          (selectedDistrict == null || place.district == selectedDistrict) &&
          rating >= minRating &&
          price <= maxPrice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlaces = getFilteredPlaces();

    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Colors.white,
        title: const Text(
          "Địa Điểm",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3B6332),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: SvgPicture.string(rankingsSVG, height: 30, width: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RankingScreen(collectionName: widget.collectionName,)),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: ListView(
          children: <Widget>[
            const SearchCard(),

            DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Chọn tỉnh/thành"),
              value: selectedCity,
              items: getUniqueCities()
                  .map((city) => DropdownMenuItem(
                value: city,
                child: Text(city),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCity = value;
                  selectedDistrict = null;
                });
              },
            ),

            if (selectedCity != null)
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text("Chọn quận/huyện"),
                value: selectedDistrict,
                items: getDistrictsForSelectedCity()
                    .map((district) => DropdownMenuItem(
                  value: district,
                  child: Text(district),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDistrict = value;
                  });
                },
              ),

            const SizedBox(height: 10),
            Text("Đánh giá từ ${minRating.toStringAsFixed(1)} trở lên"),
            Slider(
              min: 0.0,
              max: 5.0,
              divisions: 10,
              label: minRating.toStringAsFixed(1),
              value: minRating,
              onChanged: (value) {
                setState(() {
                  minRating = value;
                });
              },
            ),

            const SizedBox(height: 10),
            Text("Giá tối đa: ${maxPrice.toInt()}"),
            Slider(
              min: 0.0,
              max: 10000000.0,
              divisions: 10000,
              label: maxPrice.toStringAsFixed(0),
              value: maxPrice,
              onChanged: (value) {
                setState(() {
                  maxPrice = value;
                });
              },
            ),

            const SizedBox(height: 10.0),

            ListView.builder(
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredPlaces.length,
              itemBuilder: (BuildContext context, int index) {
                final place = filteredPlaces[index];
                return TrendingPlace(place: place);
              },
            ),

            const SizedBox(height: 10.0),
          ],
        ),
      ),
    );
  }
}
