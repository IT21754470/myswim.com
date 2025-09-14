// lib/models/swim_history_store.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainingSession {
  final DateTime createdAt;
  final DateTime sessionDate;
  final String distance;
  final String stroke;
  final String? swimmerId;
  final String? swimmerName;
  final String? competition;
  final String? bestTimeText;
  final DateTime? bestTimeDate;
  final double? waterTemp;
  final double? humidity;
  final String? predictedTime;
  final String? confidence;
  final bool isPrediction;

  TrainingSession({
    required this.createdAt,
    required this.sessionDate,
    required this.distance,
    required this.stroke,
    this.swimmerId,
    this.swimmerName,
    this.competition,
    this.bestTimeText,
    this.bestTimeDate,
    this.waterTemp,
    this.humidity,
    this.predictedTime,
    this.confidence,
    required this.isPrediction,
  });

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt.toIso8601String(),
    'sessionDate': sessionDate.toIso8601String(),
    'distance': distance,
    'stroke': stroke,
    'swimmerId': swimmerId,
    'swimmerName': swimmerName,
    'competition': competition,
    'bestTimeText': bestTimeText,
    'bestTimeDate': bestTimeDate?.toIso8601String(),
    'waterTemp': waterTemp,
    'humidity': humidity,
    'predictedTime': predictedTime,
    'confidence': confidence,
    'isPrediction': isPrediction,
  };

  factory TrainingSession.fromJson(Map<String, dynamic> j) => TrainingSession(
    createdAt: DateTime.parse(j['createdAt'] as String),
    sessionDate: DateTime.parse(j['sessionDate'] as String),
    distance: j['distance'] as String,
    stroke: j['stroke'] as String,
    swimmerId: j['swimmerId'] as String?,
    swimmerName: j['swimmerName'] as String?,
    competition: j['competition'] as String?,
    bestTimeText: j['bestTimeText'] as String?,
    bestTimeDate: j['bestTimeDate'] == null ? null : DateTime.parse(j['bestTimeDate'] as String),
    waterTemp: (j['waterTemp'] as num?)?.toDouble(),
    humidity: (j['humidity'] as num?)?.toDouble(),
    predictedTime: j['predictedTime'] as String?,
    confidence: j['confidence'] as String?,
    isPrediction: j['isPrediction'] as bool,
  );
}

class SwimHistoryStore extends ChangeNotifier {
  static final SwimHistoryStore _instance = SwimHistoryStore._internal();
  factory SwimHistoryStore() => _instance;
  SwimHistoryStore._internal();

  static const _kPrefsKey = 'swim_history_v1';

  final List<TrainingSession> _items = [];
  List<TrainingSession> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPrefsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    _items
      ..clear()
      ..addAll(decoded.map((e) => TrainingSession.fromJson(e as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kPrefsKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(TrainingSession s) async {
    _items.add(s);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }
}
