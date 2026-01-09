import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../util/places.dart';

class RankingScreen extends StatefulWidget {
  final String collectionName;
  const RankingScreen({super.key, required this.collectionName});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String selectedTab = "Ngày";
  final Color primary = const Color(0xFF2E582B);

  /// ===== Field theo tab =====
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

  Map<String, String> get ratingField {
    switch (selectedTab) {
      case "Tháng":
        return {'sum': 'ratingSumMonth', 'count': 'ratingCountMonth'};
      case "Năm":
        return {'sum': 'ratingSumYear', 'count': 'ratingCountYear'};
      default:
        return {'sum': 'ratingSum', 'count': 'ratingCount'};
    }
  }

  /// ===== Business logic =====
  num _getAverageRating(Place p) {
    final sum = _getFieldValue(p, ratingField['sum']!);
    final count = _getFieldValue(p, ratingField['count']!);
    if (count == 0) return 3; // mặc định rating
    return sum / count;
  }

  num _getFieldValue(Place p, String field) {
    switch (field) {
      case 'checkinCount':
        return p.checkinCount ?? 0;
      case 'checkinCountMonth':
        return p.checkinCountMonth ?? 0;
      case 'checkinCountYear':
        return p.checkinCountYear ?? 0;
      case 'reviewCount':
        return p.reviewCount ?? 0;
      case 'reviewCountMonth':
        return p.reviewCountMonth ?? 0;
      case 'reviewCountYear':
        return p.reviewCountYear ?? 0;
      case 'ratingSum':
        return p.ratingSum ?? 0;
      case 'ratingCount':
        return p.ratingCount ?? 0;
      case 'ratingSumMonth':
        return p.ratingSumMonth ?? 0;
      case 'ratingCountMonth':
        return p.ratingCountMonth ?? 0;
      case 'ratingSumYear':
        return p.ratingSumYear ?? 0;
      case 'ratingCountYear':
        return p.ratingCountYear ?? 0;
      default:
        return 0;
    }
  }

  /// ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildTabs(),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(widget.collectionName)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Chưa có dữ liệu"));
                    }

                    final places = snapshot.data!.docs.map((doc) {
                      return Place.fromDocument(doc);
                    }).toList();

                    // sắp xếp
                    final checkinSorted = List<Place>.from(places)
                      ..sort((a, b) => _getFieldValue(b, checkinField)
                          .compareTo(_getFieldValue(a, checkinField)));

                    final ratingSorted = List<Place>.from(places)
                      ..sort((a, b) {
                        final aAvg = _getAverageRating(a);
                        final bAvg = _getAverageRating(b);
                        if (aAvg == bAvg) {
                          return _getFieldValue(b, reviewField)
                              .compareTo(_getFieldValue(a, reviewField));
                        }
                        return bAvg.compareTo(aAvg);
                      });

                    return ListView(
                      children: [
                        _buildSectionTitle("Checkin nhiều nhất 🏆"),
                        ...checkinSorted.take(3).map(_buildCheckinRow),
                        const SizedBox(height: 20),
                        _buildSectionTitle("Đánh giá cao và nhiều nhất 🏆"),
                        ...ratingSorted.take(3).map(_buildRatingRow),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
        Text(
          "BẢNG XẾP HẠNG",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: primary,
          ),
        ),
        Icon(Icons.search, color: primary),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ["Ngày", "Tháng", "Năm"].map((tab) {
        final isSelected = selectedTab == tab;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            onTap: () => setState(() => selectedTab = tab),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color:
                isSelected ? const Color(0xFFE4E6AA) : Colors.transparent,
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: primary),
      ),
    );
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
    final rating = _getAverageRating(p);
    final reviewCount = _getFieldValue(p, reviewField);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
