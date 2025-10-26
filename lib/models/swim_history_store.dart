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
        bestTimeDate:
            j['bestTimeDate'] == null ? null : DateTime.parse(j['bestTimeDate'] as String),
        waterTemp: (j['waterTemp'] as num?)?.toDouble(),
        humidity: (j['humidity'] as num?)?.toDouble(),
        predictedTime: j['predictedTime'] as String?,
        confidence: j['confidence'] as String?,
        isPrediction: j['isPrediction'] as bool,
      );
}

/// Per-user local history store (SharedPreferences bucket per UID).
class SwimHistoryStore extends ChangeNotifier {
  static final SwimHistoryStore _instance = SwimHistoryStore._internal();
  factory SwimHistoryStore() => _instance;
  SwimHistoryStore._internal();

  // Legacy single-bucket key (pre-migration)
  static const _kLegacyKey = 'swim_history_v1';

  // New per-user buckets
  static const _kBaseKey = 'swim_history_v1';
  static String _bucketKey(String? uid) => '${_kBaseKey}_${uid ?? 'anon'}';

  String? _activeUid;
  String? get activeUid => _activeUid;

  final List<TrainingSession> _items = [];
  List<TrainingSession> get items => List.unmodifiable(_items);

  /// Switches the active user bucket and auto-loads its history.
  /// Pass `null` for signed-out / anonymous.
  Future<void> setActiveUser(String? uid) async {
    _activeUid = uid;
    // First-time migration: if legacy bucket exists and the new per-user bucket
    // is empty, move legacy items into this user's bucket and remove legacy key.
    await _maybeMigrateLegacyInto(uid);

    await load(); // load the (possibly migrated) bucket
  }

  /// Loads the active user's bucket into memory.
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_bucketKey(_activeUid));
    _items
      ..clear();

    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.addAll(
        decoded.map((e) => TrainingSession.fromJson(e as Map<String, dynamic>)),
      );
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _bucketKey(_activeUid),
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

  /// One-time migration from legacy single bucket to the current user's bucket.
  /// If legacy exists and current bucket is empty, move it over and delete legacy.
  Future<void> _maybeMigrateLegacyInto(String? uid) async {
    final sp = await SharedPreferences.getInstance();
    final legacy = sp.getString(_kLegacyKey);
    if (legacy == null) return;

    final currentBucketKey = _bucketKey(uid);
    if (sp.getString(currentBucketKey) != null) {
      // Current bucket already has data — keep legacy as-is to avoid overwriting.
      return;
    }

    // Move legacy -> current user bucket, then delete legacy
    await sp.setString(currentBucketKey, legacy);
    await sp.remove(_kLegacyKey);
  }
}
