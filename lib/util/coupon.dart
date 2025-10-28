import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stour/util/question.dart';

class Coupon {
  final String id;
  final String title;
  final int discountPercent;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final List<Question> listQuestion;
  final String creatorId;

  Coupon({
    required this.id,
    required this.title,
    required this.discountPercent,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.listQuestion,
    required this.creatorId,
  });

  factory Coupon.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Coupon(
      id: doc.id,
      title: data['title'] ?? 'Không có tên',
      discountPercent: data['discountPercent'] ?? 0,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      description: data['description'] ?? '',
      listQuestion: (data['questions'] as List<dynamic>?)
          ?.map((q) => Question.fromMap(q))
          .toList() ??
          [],
      creatorId: data['creatorId'] ?? '',
    );
  }

  String get dateRangeString {
    final format = DateFormat('dd/MM/yyyy');
    return '${format.format(startDate)} - ${format.format(endDate)}';
  }

  bool get isExpired => endDate.isBefore(DateTime.now());
}