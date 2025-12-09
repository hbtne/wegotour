
class Group {
  final String id;
  final String name;
  final String description;
  final String avatarUrl;
  final String lastMessage;
  final DateTime lastTime;
  final bool unread;
  final List<Map<String, dynamic>> members;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
    required this.members,

  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'lastMessage': lastMessage,
      'lastTime': lastTime,
      'unread': unread,
      'members': members,
      'createdAt': DateTime.now(),
    };
  }

  factory Group.fromMap(String id, Map<String, dynamic> data) {
    return Group(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      lastMessage: data['lastMessage'],
      lastTime: data['lastTime'],
      unread: data['unread'],
      members: List<Map<String, dynamic>>.from(data['members'] ?? []),
    );
  }
}
