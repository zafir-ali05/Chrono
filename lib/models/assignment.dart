class Assignment {
  final String id;
  final String groupId;
  final String className;
  final String name;
  final DateTime dueDate;
  final DateTime createdAt;
  final String creatorId;

  Assignment({
    required this.id,
    required this.groupId,
    required this.className,
    required this.name,
    required this.dueDate,
    required this.createdAt,
    required this.creatorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'className': className,
      'name': name,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'creatorId': creatorId,
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'],
      groupId: map['groupId'],
      className: map['className'],
      name: map['name'],
      dueDate: DateTime.parse(map['dueDate']),
      createdAt: DateTime.parse(map['createdAt']),
      creatorId: map['creatorId'],
    );
  }
}
