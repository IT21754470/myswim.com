import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingSession {
  final int swimmerId;
  final int poolLength;
  final DateTime date;
  final String strokeType;
  final double trainingDistance;
  final double sessionDuration;
  final double pacePer100m;
  final int laps;
  final double? avgHeartRate;
  final double? restInterval;
  final double? baseTime;
  final double actualTime;
  final String gender;
  final String? id; // Firestore document ID
  final DateTime? createdAt;
  
  var intensity;

  TrainingSession({
    required this.swimmerId,
    required this.poolLength,
    required this.date,
    required this.strokeType,
    required this.trainingDistance,
    required this.sessionDuration,
    required this.pacePer100m,
    required this.laps,
    this.avgHeartRate,
    this.restInterval,
    this.baseTime,
    required this.actualTime,
    required this.gender,
    this.id,
    this.createdAt,
    this.intensity,
  });
factory TrainingSession.fromFirestore(Map<String, dynamic> data, String documentId) {
  print('🔄 Parsing Firestore data: $data'); // Debug print
  
  return TrainingSession(
    id: documentId,
    swimmerId: data['swimmerId'] ?? 1,
    poolLength: data['poolLength'] ?? 25,
    date: _parseDate(data['date']),
    strokeType: data['strokeType'] ?? 'Freestyle',
    trainingDistance: (data['trainingDistance'] ?? 0).toDouble(),
    sessionDuration: (data['sessionDuration'] ?? 0).toDouble(),
    pacePer100m: (data['pacePer100m'] ?? 0).toDouble(),
    laps: data['laps'] ?? 0,
    avgHeartRate: data['avgHeartRate']?.toDouble(),
    restInterval: data['restInterval']?.toDouble(),
    baseTime: data['baseTime']?.toDouble(),
    actualTime: (data['actualTime'] ?? 0).toDouble(),
    gender: data['gender'] ?? 'Male',
    createdAt: _parseDate(data['createdAt']),
  );
}

// Helper method to safely parse dates
static DateTime _parseDate(dynamic dateValue) {
  if (dateValue == null) return DateTime.now();
  
  if (dateValue is String) {
    try {
      return DateTime.parse(dateValue);
    } catch (e) {
      print('❌ Error parsing date string: $dateValue');
      return DateTime.now();
    }
  }
  
  if (dateValue is Timestamp) {
    return dateValue.toDate();
  }
  
  return DateTime.now();
}
  // Convert TrainingSession to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'swimmerId': swimmerId,
      'poolLength': poolLength,
      'date': date.toIso8601String(),
      'strokeType': strokeType,
      'trainingDistance': trainingDistance,
      'sessionDuration': sessionDuration,
      'pacePer100m': pacePer100m,
      'laps': laps,
      'avgHeartRate': avgHeartRate,
      'restInterval': restInterval,
      'baseTime': baseTime,
      'actualTime': actualTime,
      'gender': gender,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  // Create a copy with modified fields
  TrainingSession copyWith({
    int? swimmerId,
    int? poolLength,
    DateTime? date,
    String? strokeType,
    double? trainingDistance,
    double? sessionDuration,
    double? pacePer100m,
    int? laps,
    double? avgHeartRate,
    double? restInterval,
    double? baseTime,
    double? actualTime,
    String? gender,
    String? id,
    DateTime? createdAt,
  }) {
    return TrainingSession(
      swimmerId: swimmerId ?? this.swimmerId,
      poolLength: poolLength ?? this.poolLength,
      date: date ?? this.date,
      strokeType: strokeType ?? this.strokeType,
      trainingDistance: trainingDistance ?? this.trainingDistance,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      pacePer100m: pacePer100m ?? this.pacePer100m,
      laps: laps ?? this.laps,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      restInterval: restInterval ?? this.restInterval,
      baseTime: baseTime ?? this.baseTime,
      actualTime: actualTime ?? this.actualTime,
      gender: gender ?? this.gender,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Calculate pace per 100m from actual time and distance
  double calculatePacePer100m() {
    if (trainingDistance <= 0) return 0.0;
    return (actualTime / trainingDistance) * 100;
  }

  // Calculate calories burned (rough estimation)
  double calculateCaloriesBurned() {
    // Basic formula: MET value * weight(kg) * time(hours)
    // Swimming MET values: Freestyle ~8, Backstroke ~8, Breaststroke ~10, Butterfly ~11
    final metValues = {
      'Freestyle': 8.0,
      'Backstroke': 8.0,
      'Breaststroke': 10.0,
      'Butterfly': 11.0,
    };
    
    final met = metValues[strokeType] ?? 8.0;
    const averageWeight = 70.0; // kg - you could make this dynamic based on user profile
    final timeInHours = sessionDuration / 60.0;
    
    return met * averageWeight * timeInHours;
  }

  // Get performance rating (1-5 stars)
  int getPerformanceRating() {
    // This is a simple rating based on pace - you can make it more sophisticated
    if (pacePer100m <= 60) return 5;
    if (pacePer100m <= 75) return 4;
    if (pacePer100m <= 90) return 3;
    if (pacePer100m <= 105) return 2;
    return 1;
  }

  // Check if this is a personal best for the stroke type
  bool isPotentialPersonalBest(List<TrainingSession> previousSessions) {
    final sameLengthSessions = previousSessions.where((session) => 
        session.strokeType == strokeType && 
        session.trainingDistance == trainingDistance &&
        session.poolLength == poolLength
    );
    
    if (sameLengthSessions.isEmpty) return false;
    
    final bestPreviousTime = sameLengthSessions
        .map((s) => s.actualTime)
        .reduce((a, b) => a < b ? a : b);
    
    return actualTime < bestPreviousTime;
  }

  // Get training intensity level
  String getIntensityLevel() {
    if (avgHeartRate == null) return 'Unknown';
    
    // Basic heart rate zones (you could make this more sophisticated with age/gender)
    if (avgHeartRate! < 120) return 'Low';
    if (avgHeartRate! < 140) return 'Moderate';
    if (avgHeartRate! < 160) return 'High';
    return 'Very High';
  }

  @override
  String toString() {
    return 'TrainingSession(strokeType: $strokeType, distance: ${trainingDistance}m, time: ${actualTime}s, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrainingSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Extension methods for lists of training sessions
extension TrainingSessionListExtensions on List<TrainingSession> {
  // Get sessions for a specific stroke
  List<TrainingSession> forStroke(String strokeType) {
    return where((session) => session.strokeType == strokeType).toList();
  }

  // Get sessions within a date range
  List<TrainingSession> inDateRange(DateTime start, DateTime end) {
    return where((session) => 
        session.date.isAfter(start.subtract(const Duration(days: 1))) &&
        session.date.isBefore(end.add(const Duration(days: 1)))
    ).toList();
  }

  // Get best time for a specific stroke and distance
  TrainingSession? bestTimeFor(String strokeType, double distance) {
    final filtered = where((session) => 
        session.strokeType == strokeType && 
        session.trainingDistance == distance
    );
    
    if (filtered.isEmpty) return null;
    
    return filtered.reduce((a, b) => a.actualTime < b.actualTime ? a : b);
  }

  // Calculate average improvement over time
  double averageImprovement() {
    if (length < 2) return 0.0;
    
    final sorted = [...this]..sort((a, b) => a.date.compareTo(b.date));
    
    double totalImprovement = 0.0;
    int count = 0;
    
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].strokeType == sorted[i-1].strokeType &&
          sorted[i].trainingDistance == sorted[i-1].trainingDistance) {
        totalImprovement += sorted[i-1].actualTime - sorted[i].actualTime;
        count++;
      }
    }
    
    return count > 0 ? totalImprovement / count : 0.0;
  }

  // Get total distance swum
  double totalDistance() {
    return fold(0.0, (sum, session) => sum + session.trainingDistance);
  }

  // Get total time spent training
  double totalTrainingTime() {
    return fold(0.0, (sum, session) => sum + session.sessionDuration);
  }
}