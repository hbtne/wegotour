class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final Map<String, dynamic> requirements;
  final Map<String, dynamic> scoring;
  final String badgeId;
  final bool autoApprove;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.requirements,
    required this.scoring,
    required this.badgeId,
    required this.autoApprove,
  });

  factory EventModel.fromMap(String id, Map<String, dynamic> m) {
    return EventModel(
      id: id,
      title: m['title'] ?? '',
      description: m['description'] ?? '',
      startAt: (m['startAt'] as dynamic) is int
          ? DateTime.fromMillisecondsSinceEpoch(m['startAt'])
          : (m['startAt'] as dynamic).toDate(),
      endAt: (m['endAt'] as dynamic) is int
          ? DateTime.fromMillisecondsSinceEpoch(m['endAt'])
          : (m['endAt'] as dynamic).toDate(),
      requirements: Map<String, dynamic>.from(m['requirements'] ?? {}),
      scoring: Map<String, dynamic>.from(m['scoring'] ?? {}),
      badgeId: m['badgeId'] ?? '',
      autoApprove: m['autoApprove'] ?? true,
    );
  }
}
