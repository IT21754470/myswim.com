import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalRecord {
  final String id;
  final String userId;
  final String strokeType;
  final double distance;
  final double time;
  final double pace;
  final DateTime achievedDate;
  final String poolLength;
  final bool isCurrentRecord;

  PersonalRecord({
    required this.id,
    required this.userId,
    required this.strokeType,
    required this.distance,
    required this.time,
    required this.pace,
    required this.achievedDate,
    required this.poolLength,
    required this.isCurrentRecord,
  });

  // Convert from Firestore JSON
  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    return PersonalRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      strokeType: json['strokeType'] ?? '',
      distance: (json['distance'] ?? 0).toDouble(),
      time: (json['time'] ?? 0).toDouble(),
      pace: (json['pace'] ?? 0).toDouble(),
      achievedDate: json['achievedDate'] is Timestamp
          ? (json['achievedDate'] as Timestamp).toDate()
          : json['achievedDate'] is String
              ? DateTime.parse(json['achievedDate'])
              : DateTime.now(),
      poolLength: json['poolLength']?.toString() ?? '25',
      isCurrentRecord: json['isCurrentRecord'] ?? true,
    );
  }

  // Convert to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'strokeType': strokeType,
      'distance': distance,
      'time': time,
      'pace': pace,
      'achievedDate': Timestamp.fromDate(achievedDate),
      'poolLength': poolLength,
      'isCurrentRecord': isCurrentRecord,
    };
  }

  // copyWith method
  PersonalRecord copyWith({
    String? id,
    String? userId,
    String? strokeType,
    double? distance,
    double? time,
    double? pace,
    DateTime? achievedDate,
    String? poolLength,
    bool? isCurrentRecord,
  }) {
    return PersonalRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      strokeType: strokeType ?? this.strokeType,
      distance: distance ?? this.distance,
      time: time ?? this.time,
      pace: pace ?? this.pace,
      achievedDate: achievedDate ?? this.achievedDate,
      poolLength: poolLength ?? this.poolLength,
      isCurrentRecord: isCurrentRecord ?? this.isCurrentRecord,
    );
  }

  // Formatted time (MM:SS.ms)
  String get formattedTime {
    final minutes = time ~/ 60;
    final seconds = time % 60;
    return '${minutes}:${seconds.toStringAsFixed(2)}';
  }

  // Formatted pace
  String get formattedPace {
    return '${pace.toStringAsFixed(2)}s/100m';
  }

  @override
  String toString() {
    return 'PersonalRecord(id: $id, stroke: $strokeType, distance: $distance, time: $time, pace: $pace)';
  }
}