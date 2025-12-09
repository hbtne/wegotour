class BadgeModel {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final Map<String, dynamic> criteria;

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.criteria,
  });

  factory BadgeModel.fromMap(String id, Map<String, dynamic> m) {
    return BadgeModel(
      id: id,
      title: m['title'] ?? '',
      description: m['description'] ?? '',
      iconUrl: m['iconUrl'] ?? '',
      criteria: Map<String, dynamic>.from(m['criteria'] ?? {}),
    );
  }
}