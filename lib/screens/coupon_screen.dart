import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stour/screens/question_screen.dart';
import 'package:stour/util/coupon.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MINIGAMES', style: TextStyle(color: Color(0xFF3B6332), fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color.fromARGB(255, 35, 52, 10)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('minigames').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi khi tải dữ liệu: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data?.docs.isEmpty ?? true) {
            return Center(child: Text('Chưa có minigame nào'));
          }

          final coupons = snapshot.data!.docs
              .map((doc) => Coupon.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final coupon = coupons[index];
              // final isCreator = coupon.creatorId == _auth.currentUser?.uid;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: coupon.isExpired ? Colors.grey[200] : Color(0x50FFD166),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Mã giảm ${coupon.discountPercent}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B6332),
                            ),
                          ),
                      //     // if (isCreator)
                      //       Padding(
                      //         padding: const EdgeInsets.only(left: 8),
                      //         child: Container(
                      //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      //           decoration: BoxDecoration(
                      //             color: Constants.lightgreen,
                      //             borderRadius: BorderRadius.circular(10),
                      //           ),
                      //         ),
                      //       ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        coupon.title,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color:  Color(0xFF3B6332),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Áp dụng: ${coupon.dateRangeString}',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: coupon.isExpired ? Colors.red : Color(0xFF3B6332),
                        ),
                      ),
                      if (coupon.isExpired)
                        Text(
                          'Đã hết hạn',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                  trailing: coupon.isExpired
                      ? null
                      : const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF3B6332)),
                  onTap: coupon.isExpired
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuestionScreen(
                          listquestion: coupon.listQuestion,
                        ),
                      ),
                    );
                  },

                ),
              );
            },
          );
        },
      ),
    );
  }
}