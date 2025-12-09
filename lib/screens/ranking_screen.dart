// import 'dart:ffi';

import 'package:flutter/material.dart';
import '../util/places.dart';

const primary = Color(0xFF2E582B);

class RankingScreen extends StatefulWidget {
  final List<Place> source;

  const RankingScreen({super.key, required this.source});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String selectedTab = "Ngày";

  /// Lấy field tương ứng với tab
  String get checkinField {
    switch (selectedTab) {
      case "Tháng":
        return "checkinCountMonth";
      case "Năm":
        return "checkinCountYear";
      default:
        return "checkinCount";
    }
  }

  String get reviewField {
    switch (selectedTab) {
      case "Tháng":
        return "reviewCountMonth";
      case "Năm":
        return "reviewCountYear";
      default:
        return "reviewCount";
    }
  }

  String get ratingField {
    switch (selectedTab) {
      case "Tháng":
        return "ratingMonth";
      case "Năm":
        return "ratingYear";
      default:
        return "rating";
    }
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.source;

    // Sort 2 bảng
    final checkinSorted = List<Place>.from(places)
      ..sort((a, b) {
        final aCheckin = _getFieldValue(a, checkinField);
        final bCheckin = _getFieldValue(b, checkinField);
        return bCheckin.compareTo(aCheckin);
      });

    final ratingSorted = List<Place>.from(places)
      ..sort((a, b) {
        final aRating = _getFieldValue(a, ratingField);
        final aReviews = _getFieldValue(a, reviewField);
        final bRating = _getFieldValue(b, ratingField);
        final bReviews = _getFieldValue(b, reviewField);
        final aScore = aRating * aReviews;
        final bScore = bRating * bReviews;
        return bScore.compareTo(aScore);
      });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "BẢNG XẾP HẠNG",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primary,
                    ),
                  ),
                  const Icon(Icons.search, color: primary),
                ],
              ),

              const SizedBox(height: 10),

              // 🔹 Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ["Ngày", "Tháng", "Năm"].map((tab) {
                  final bool isSelected = selectedTab == tab;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => selectedTab = tab),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE4E6AA)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tab,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? primary : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // 🔹 Bảng xếp hạng
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      "Checkin nhiều nhất 🏆",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...checkinSorted.take(3).map((p) => _buildCheckinRow(p)),

                    const SizedBox(height: 20),

                    const Text(
                      "Đánh giá cao và nhiều nhất 🏆",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...ratingSorted.take(3).map((p) => _buildRatingRow(p)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lấy giá trị field động theo tên
  num _getFieldValue(Place p, String field) {
    switch (field) {
      case 'checkinCount':
        return p.checkinCount ?? 0;
      case 'reviewCount':
        return p.reviewCount ?? 0;
      case 'rating':
        return num.tryParse(p.rating) ?? 5;
      case 'checkinCountMonth':
        return p.checkinCountMonth ?? 0;
      case 'reviewCountMonth':
        return p.reviewCountMonth ?? 0;
      case 'ratingMonth':
        return num.tryParse(p.ratingMonth!) ?? 4.9;
      case 'checkinCountYear':
        return p.checkinCountYear ?? 0;
      case 'reviewCountYear':
        return p.reviewCountYear ?? 0;
      case 'ratingYear':
        return num.tryParse(p.ratingYear!) ?? 4.9;
      default:
        return 0;
    }
  }

  Widget _buildCheckinRow(Place p) {
    final checkin = _getFieldValue(p, checkinField);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text("$checkin bài viết",
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildRatingRow(Place p) {
    final rating = _getFieldValue(p, ratingField);
    final reviewCount = _getFieldValue(p, reviewField);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text("$rating", style: const TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text("$reviewCount đánh giá",
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}
