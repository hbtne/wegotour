import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// import 'package:stour/util/reviews.dart';
// import 'package:flutter/material.dart';
// import 'package:stour/util/reviews.dart';
import 'package:stour/model/review.dart';
import 'package:stour/util/const.dart';

class CreateReviewScreen extends StatefulWidget {
  final String locationID;
  const CreateReviewScreen({super.key, required this.locationID});
  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  int selectedStars = 5;
  TextEditingController commentController = TextEditingController();
  ReviewsServices rs = ReviewsServices();
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        userData = doc.data();
        setState(() {});
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'THÊM NHẬN XÉT',
          style: TextStyle(
            color: Color.fromARGB(255, 35, 52, 10),
          ),
        ),
        backgroundColor: Constants.lightgreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color.fromARGB(255, 35, 52, 10)), // Change the color here
          onPressed: () {
            // Handle back button logic
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đánh giá địa điểm:',
              style: TextStyle(
                  color: Color.fromARGB(255, 35, 52, 10),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                buildStarButton(1),
                buildStarButton(2),
                buildStarButton(3),
                buildStarButton(4),
                buildStarButton(5),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhận xét:',
              style: TextStyle(
                  color: Color.fromARGB(255, 35, 52, 10),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Nhập đánh giá ở đây.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.lightgreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  child: const Text(
                    'HỦY',
                    style: TextStyle(color: Color.fromARGB(255, 35, 52, 10)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final reviewId = await rs.createReview(
                        user!.uid,
                        userData?['username'] ?? 'Anonymous',
                        widget.locationID,
                        userData?['username'] ?? 'Anonymous',
                        userData?['avatar'] ?? 'https://i.imgur.com/xZ5946b.jpeg',
                        commentController.text,
                        selectedStars.toString());

                    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
                      'reviews': FieldValue.arrayUnion([reviewId])
                    });

                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.lightgreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  child: const Text(
                    'ĐĂNG BÀI',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStarButton(int stars) {
    return IconButton(
      onPressed: () {
        setState(() {
          selectedStars = stars;
        });
      },
      icon: Icon(
        stars <= selectedStars ? Icons.star : Icons.star_border,
        size: 30,
        color: Colors.amber,
      ),
    );
  }
}
