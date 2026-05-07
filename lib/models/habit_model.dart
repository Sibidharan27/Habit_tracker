class HabitModel {
  final String id;
  final String habitName;
  final String category;
  final int streak;
  final int level;
  final int gridX;
  final int gridY;
  final int intervalHours; // hours between completions
  final DateTime lastCompleted;

  HabitModel({
    required this.id,
    required this.habitName,
    required this.category,
    required this.streak,
    required this.level,
    required this.gridX,
    required this.gridY,
    required this.intervalHours,
    required this.lastCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'habitName': habitName,
      'category': category,
      'streak': streak,
      'level': level,
      'gridX': gridX,
      'gridY': gridY,
      'intervalHours': intervalHours,
      'lastCompleted': lastCompleted,
    };
  }

  factory HabitModel.fromMap(String id, Map<String, dynamic> d) {
    return HabitModel(
      id: id,
      habitName: d['habitName'] ?? d['category'] ?? '',
      category: d['category'] ?? '',
      streak: (d['streak'] as num?)?.toInt() ?? 0,
      level: (d['level'] as num?)?.toInt() ?? 1,
      gridX: (d['gridX'] as num?)?.toInt() ?? 0,
      gridY: (d['gridY'] as num?)?.toInt() ?? 0,
      intervalHours: (d['intervalHours'] as num?)?.toInt() ?? 24,
      lastCompleted: d['lastCompleted'] != null
          ? (d['lastCompleted'] as dynamic).toDate()
          : DateTime.now(),
    );
  }
}