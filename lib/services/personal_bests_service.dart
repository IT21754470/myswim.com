import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/personal_best.dart';
import '../models/training_session.dart';

class PersonalBestsService {
  static final _firestore = FirebaseFirestore.instance;

  /// Check if the session is a new personal best
  static Future<PersonalBest?> checkForNewRecord(TrainingSession session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in for PR check');
      return null;
    }

    print('🔍 Checking for PR: ${session.strokeType} ${session.trainingDistance}m');
    print('🔍 Current session - Pace: ${session.pacePer100m}s/100m, Time: ${session.actualTime}s');

    try {
      // Get the best session for this stroke/distance combination
      final existingBest = await getBestSession(
        session.strokeType,
        session.trainingDistance,
      );

      if (existingBest == null) {
        print('🆕 First time swimming ${session.strokeType} ${session.trainingDistance}m!');
        return PersonalBest(
          strokeType: session.strokeType,
          distance: session.trainingDistance,
          time: session.actualTime,
          pace: session.pacePer100m,
          achievedDate: session.date,
          sessionId: session.id ?? '',
          poolLength: session.poolLength,
        );
      }

      // Compare paces
      if (session.pacePer100m < existingBest.pace) {
        print('🏆 NEW PR! Previous: ${existingBest.pace.toStringAsFixed(2)}s/100m, New: ${session.pacePer100m.toStringAsFixed(2)}s/100m');
        return PersonalBest(
          strokeType: session.strokeType,
          distance: session.trainingDistance,
          time: session.actualTime,
          pace: session.pacePer100m,
          achievedDate: session.date,
          sessionId: session.id ?? '',
          poolLength: session.poolLength,
        );
      } else {
        print('📊 Not a PR. Current best: ${existingBest.pace.toStringAsFixed(2)}s/100m');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error checking for PR: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get the best session for a specific stroke and distance
  static Future<PersonalBest?> getBestSession(
    String strokeType,
    double distance,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _firestore
          .collection('training_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('strokeType', isEqualTo: strokeType)
          .where('trainingDistance', isEqualTo: distance)
          .orderBy('pacePer100m', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();

      return PersonalBest(
        strokeType: data['strokeType'] ?? '',
        distance: (data['trainingDistance'] ?? 0).toDouble(),
        time: (data['actualTime'] ?? 0).toDouble(),
        pace: (data['pacePer100m'] ?? 0).toDouble(),
        achievedDate: data['date'] is Timestamp
            ? (data['date'] as Timestamp).toDate()
            : DateTime.parse(data['date']),
        sessionId: doc.id,
        poolLength: data['poolLength'] ?? 25,
      );
    } catch (e) {
      print('❌ Error getting best session: $e');
      return null;
    }
  }

  /// Get all personal bests for the current user
  static Future<List<PersonalBest>> getAllPersonalBests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return [];
    }

    try {
      print('📊 Loading all sessions for user: ${user.uid}');

      // Get all sessions
      final snapshot = await _firestore
          .collection('training_sessions')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('📊 Found ${snapshot.docs.length} total sessions');

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Group by stroke and distance, keeping only the best pace for each
      final Map<String, PersonalBest> bestByCombo = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final strokeType = data['strokeType'] ?? '';
          final distance = (data['trainingDistance'] ?? 0).toDouble();
          final pace = (data['pacePer100m'] ?? 0).toDouble();
          final time = (data['actualTime'] ?? 0).toDouble();

          if (strokeType.isEmpty || distance == 0 || pace == 0) {
            continue;
          }

          final key = '${strokeType}_$distance';

          // Keep only the best pace for each stroke/distance combo
          if (!bestByCombo.containsKey(key) || pace < bestByCombo[key]!.pace) {
            bestByCombo[key] = PersonalBest(
              strokeType: strokeType,
              distance: distance,
              time: time,
              pace: pace,
              achievedDate: data['date'] is Timestamp
                  ? (data['date'] as Timestamp).toDate()
                  : DateTime.parse(data['date']),
              sessionId: doc.id,
              poolLength: data['poolLength'] ?? 25,
            );
          }
        } catch (e) {
          print('⚠️ Error processing document ${doc.id}: $e');
        }
      }

      final personalBests = bestByCombo.values.toList();

      // Sort by date descending
      personalBests.sort((a, b) => b.achievedDate.compareTo(a.achievedDate));

      print('✅ Loaded ${personalBests.length} personal bests');
      return personalBests;
    } catch (e, stackTrace) {
      print('❌ Error loading personal bests: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get personal bests grouped by stroke type
  static Future<Map<String, List<PersonalBest>>> getPersonalBestsByStroke() async {
    final allBests = await getAllPersonalBests();
    final grouped = <String, List<PersonalBest>>{};

    print('📊 Grouping ${allBests.length} personal bests by stroke');

    for (final best in allBests) {
      grouped.putIfAbsent(best.strokeType, () => []).add(best);
    }

    // Sort records within each stroke by distance
    grouped.forEach((stroke, bestList) {
      bestList.sort((a, b) => a.distance.compareTo(b.distance));
    });

    print('📊 Grouped bests: ${grouped.keys.join(', ')}');
    for (var entry in grouped.entries) {
      print('  ${entry.key}: ${entry.value.length} bests');
    }

    return grouped;
  }

  /// Get the best pace for a specific stroke across all distances
  static Future<PersonalBest?> getBestPaceForStroke(String strokeType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _firestore
          .collection('training_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('strokeType', isEqualTo: strokeType)
          .orderBy('pacePer100m', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();

      return PersonalBest(
        strokeType: data['strokeType'] ?? '',
        distance: (data['trainingDistance'] ?? 0).toDouble(),
        time: (data['actualTime'] ?? 0).toDouble(),
        pace: (data['pacePer100m'] ?? 0).toDouble(),
        achievedDate: data['date'] is Timestamp
            ? (data['date'] as Timestamp).toDate()
            : DateTime.parse(data['date']),
        sessionId: doc.id,
        poolLength: data['poolLength'] ?? 25,
      );
    } catch (e) {
      print('❌ Error getting best pace: $e');
      return null;
    }
  }

  /// Get total count of personal bests
  static Future<int> getTotalBestsCount() async {
    try {
      final bests = await getAllPersonalBests();
      print('📊 Total personal bests count: ${bests.length}');
      return bests.length;
    } catch (e) {
      print('❌ Error getting bests count: $e');
      return 0;
    }
  }

  /// Get performance history for a specific stroke/distance combination
  static Future<List<PersonalBest>> getPerformanceHistory(
    String strokeType,
    double distance,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('training_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('strokeType', isEqualTo: strokeType)
          .where('trainingDistance', isEqualTo: distance)
          .orderBy('date', descending: true)
          .get();

      final history = snapshot.docs.map((doc) {
        final data = doc.data();
        return PersonalBest(
          strokeType: data['strokeType'] ?? '',
          distance: (data['trainingDistance'] ?? 0).toDouble(),
          time: (data['actualTime'] ?? 0).toDouble(),
          pace: (data['pacePer100m'] ?? 0).toDouble(),
          achievedDate: data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.parse(data['date']),
          sessionId: doc.id,
          poolLength: data['poolLength'] ?? 25,
        );
      }).toList();

      return history;
    } catch (e) {
      print('❌ Error loading performance history: $e');
      return [];
    }
  }

  /// Get recent personal bests (last 10)
  static Future<List<PersonalBest>> getRecentBests({int limit = 10}) async {
    final allBests = await getAllPersonalBests();
    
    // Already sorted by date descending
    return allBests.take(limit).toList();
  }

  /// Get improvement statistics
  static Future<Map<String, dynamic>> getImprovementStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      // Get all sessions from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _firestore
          .collection('training_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('date', descending: false)
          .get();

      if (snapshot.docs.length < 2) {
        return {
          'improvement': 0.0,
          'totalSessions': snapshot.docs.length,
          'message': 'Need more sessions to calculate improvement',
        };
      }

      // Calculate average pace for first half vs second half
      final sessions = snapshot.docs;
      final midPoint = sessions.length ~/ 2;
      
      double firstHalfAvgPace = 0;
      double secondHalfAvgPace = 0;
      
      for (int i = 0; i < midPoint; i++) {
        firstHalfAvgPace += (sessions[i].data()['pacePer100m'] ?? 0).toDouble();
      }
      firstHalfAvgPace /= midPoint;
      
      for (int i = midPoint; i < sessions.length; i++) {
        secondHalfAvgPace += (sessions[i].data()['pacePer100m'] ?? 0).toDouble();
      }
      secondHalfAvgPace /= (sessions.length - midPoint);
      
      final improvement = ((firstHalfAvgPace - secondHalfAvgPace) / firstHalfAvgPace) * 100;
      
      return {
        'improvement': improvement,
        'totalSessions': sessions.length,
        'firstHalfAvgPace': firstHalfAvgPace,
        'secondHalfAvgPace': secondHalfAvgPace,
        'message': improvement > 0 
            ? 'You\'ve improved by ${improvement.toStringAsFixed(1)}%!'
            : 'Keep training to see improvement!',
      };
    } catch (e) {
      print('❌ Error calculating improvement: $e');
      return {};
    }
  }
}