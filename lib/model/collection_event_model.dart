import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionEvent {
  final String id;
  final String title;
  final String description;
  final List<String> keywords; // Keywords cho Vision API validation
  final DateTime startAt;
  final DateTime endAt;
  final String category;
  final bool processed;
  final String createdBy;
  final DateTime createdAt;
  final BadgeInfo badge;

  CollectionEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.keywords,
    required this.startAt,
    required this.endAt,
    this.category = 'collection',
    this.processed = false,
    required this.createdBy,
    required this.createdAt,
    required this.badge,
  });

  // Check xem event có đang active không
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startAt) && now.isBefore(endAt) && !processed;
  }

  bool get hasEnded {
    return DateTime.now().isAfter(endAt);
  }

  factory CollectionEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CollectionEvent(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      keywords: List<String>.from(data['keywords'] ?? []),
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp).toDate(),
      category: data['category'] ?? 'collection',
      processed: data['processed'] ?? false,
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      badge: BadgeInfo.fromMap(data['badge'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'keywords': keywords,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'category': category,
      'processed': processed,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'badge': badge.toMap(),
    };
  }
}

class BadgeInfo {
  final String id;
  final String name;
  final String icon;
  final String description;

  BadgeInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });

  factory BadgeInfo.fromMap(Map<String, dynamic> map) {
    return BadgeInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
    };
  }
}

// Model cho submission của user
class EventSubmission {
  final String id;
  final String eventId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String imageUrl;
  final String caption;
  final List<String> detectedLabels; // Labels từ Vision API
  final bool isValid; // Có match keywords không?
  final int likes;
  final int comments;
  final int shares;
  final int score; // Tổng điểm = likes + comments*2 + shares*3
  final DateTime createdAt;

  EventSubmission({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.imageUrl,
    required this.caption,
    required this.detectedLabels,
    required this.isValid,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.score = 0,
    required this.createdAt,
  });

  // Calculate score từ interactions
  int calculateScore() {
    return (likes * 1) + (comments * 2) + (shares * 3);
  }

  factory EventSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventSubmission(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'] ?? '',
      detectedLabels: List<String>.from(data['detectedLabels'] ?? []),
      isValid: data['isValid'] ?? false,
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      score: data['score'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'imageUrl': imageUrl,
      'caption': caption,
      'detectedLabels': detectedLabels,
      'isValid': isValid,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'score': score,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// Model cho leaderboard entry
class LeaderboardEntry {
  final String userId;
  final String userName;
  final String userAvatar;
  final int totalScore;
  final int submissionCount;
  final List<String> submissionIds;
  final DateTime updatedAt;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.totalScore,
    required this.submissionCount,
    required this.submissionIds,
    required this.updatedAt,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      userId: doc.id,
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      totalScore: data['totalScore'] ?? 0,
      submissionCount: data['submissionCount'] ?? 0,
      submissionIds: List<String>.from(data['submissionIds'] ?? []),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'userAvatar': userAvatar,
      'totalScore': totalScore,
      'submissionCount': submissionCount,
      'submissionIds': submissionIds,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}