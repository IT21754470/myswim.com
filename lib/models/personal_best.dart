class PersonalBest {
  final String strokeType;
  final double distance;
  final double time;
  final double pace;
  final DateTime achievedDate;
  final String sessionId;
  final int poolLength;

  PersonalBest({
    required this.strokeType,
    required this.distance,
    required this.time,
    required this.pace,
    required this.achievedDate,
    required this.sessionId,
    required this.poolLength,
  });

  String get formattedTime {
    final minutes = time ~/ 60;
    final seconds = time % 60;
    return '${minutes}:${seconds.toStringAsFixed(2)}';
  }

  String get formattedPace {
    return '${pace.toStringAsFixed(2)}s/100m';
  }

  @override
  String toString() {
    return 'PersonalBest(stroke: $strokeType, distance: $distance, time: $time, pace: $pace)';
  }
}