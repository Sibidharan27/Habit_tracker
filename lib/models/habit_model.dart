class HabitModel {
  final String id;
  final String category;
  final int streak;
  final int level;
  final double posX;
  final double posY;
  final DateTime lastCompleted;

  HabitModel({
    required this.id,
    required this.category,
    required this.streak,
    required this.level,
    required this.posX,
    required this.posY,
    required this.lastCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      "category": category,
      "streak": streak,
      "level": level,
      "posX": posX,
      "posY": posY,
      "lastCompleted": lastCompleted,
    };
  }
}