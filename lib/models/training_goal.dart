// lib/models/training_goal.dart
class TrainingGoal {
  final String id;
  final String userId;
  final String title;
  final String description;
  final GoalType type;
  final double targetValue;
  final double currentValue;
  final DateTime startDate;
  final DateTime targetDate;
  final bool isCompleted;
  
  TrainingGoal({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.targetDate,
    required this.isCompleted,
  });
  
  double get progress => (currentValue / targetValue * 100).clamp(0, 100);
  
  int get daysRemaining => targetDate.difference(DateTime.now()).inDays;
}

enum GoalType {
  totalDistance,    // Swim X km this month
  sessionCount,     // Complete X sessions
  pace,            // Improve pace to X s/100m
  consistency,     // Train X days per week
  personalRecord,  // Beat PR in specific stroke
}