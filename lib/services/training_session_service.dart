// ignore_for_file: unused_import, avoid_print, use_rethrow_when_possible, avoid_types_as_parameter_names

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swimming_app/models/user_profile.dart';
import '../models/training_session.dart';
import '../services/profile_service.dart'; // ✅ Import your ProfileService

class TrainingSessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names
  static const String _trainingSessions = 'training_sessions';

  /// Get all training sessions for the current user
  static Future<List<TrainingSession>> getUserTrainingSessions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      print('🔍 Fetching training sessions for user: ${user.uid}');

      // ✅ Remove orderBy to avoid index requirement for now
      final querySnapshot = await _firestore
          .collection(_trainingSessions)
          .where('userId', isEqualTo: user.uid)
          .get();

      print('✅ Found ${querySnapshot.docs.length} training sessions');
      
      if (querySnapshot.docs.isNotEmpty) {
        print('📄 First document data: ${querySnapshot.docs.first.data()}');
      }

      // ✅ Convert documents and sort manually
      final sessions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        print('🔄 Converting document ${doc.id}: $data');
        return TrainingSession.fromFirestore(data, doc.id);
      }).toList();

      // ✅ Sort by date manually (newest first)
      sessions.sort((a, b) => b.date.compareTo(a.date));
      
      return sessions;

    } catch (e) {
      print('❌ Error fetching training sessions: $e');
      return await _tryAlternativeQueries();
    }
  }
  /// ✅ Use your ProfileService instead of custom method
 static Future<Map<String, dynamic>?> getUserProfile() async {
  try {
    print('🔍 Getting user profile via ProfileService...');
    final profile = await ProfileService.getUserProfile();
    
    if (profile != null) {
      print('✅ Profile found: ${profile.name}, sessions: ${profile.totalSessions}');
      return {
        'gender': profile.gender ?? 'Male',
        'name': profile.name ?? 'Swimmer',
        'age': profile.age,
        'weight': profile.weight,
        'favoriteStyle': profile.favoriteStyle,
        'totalSessions': profile.totalSessions,
        'totalDistance': profile.totalDistance,
        'totalHours': profile.totalHours,
      };
    } else {
      print('❌ No profile found');
      return {
        'gender': 'Male',
        'name': 'Swimmer',
        'totalSessions': 0,
        'totalDistance': 0.0,
        'totalHours': 0,
      };
    }
  } catch (e) {
    print('❌ Error getting user profile: $e');
    return {
      'gender': 'Male',
      'name': 'Swimmer',
      'totalSessions': 0,
      'totalDistance': 0.0,
      'totalHours': 0,
    };
  }
}
  /// Fallback method to try different query approaches
  static Future<List<TrainingSession>> _tryAlternativeQueries() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Try with 'uid' field instead of 'userId'
      var querySnapshot = await _firestore
          .collection(_trainingSessions)
          .where('uid', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print('✅ Found sessions using uid field');
        return querySnapshot.docs.map((doc) {
          return TrainingSession.fromFirestore(doc.data(), doc.id);
        }).toList();
      }

      // Try different collection name
      querySnapshot = await _firestore
          .collection('trainingSessions')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print('✅ Found sessions in trainingSessions collection');
        return querySnapshot.docs.map((doc) {
          return TrainingSession.fromFirestore(doc.data(), doc.id);
        }).toList();
      }

      print('ℹ️ No training sessions found with alternative queries');
      return [];

    } catch (e) {
      print('❌ Error in alternative queries: $e');
      return [];
    }
  }

  /// Get training sessions within a date range
  static Future<List<TrainingSession>> getSessionsInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final querySnapshot = await _firestore
          .collection(_trainingSessions)
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return TrainingSession.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Error fetching sessions in date range: $e');
      return [];
    }
  }

  /// Get sessions for a specific stroke type
  static Future<List<TrainingSession>> getSessionsForStroke(String strokeType) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final querySnapshot = await _firestore
          .collection(_trainingSessions)
          .where('userId', isEqualTo: user.uid)
          .where('strokeType', isEqualTo: strokeType)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return TrainingSession.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Error fetching sessions for stroke: $e');
      return [];
    }
  }

  /// Save a new training session
  static Future<String> saveTrainingSession(TrainingSession session) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final sessionData = session.toFirestore();
      sessionData['userId'] = user.uid;
      sessionData['createdAt'] = FieldValue.serverTimestamp();
      sessionData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore
          .collection(_trainingSessions)
          .add(sessionData);

      print('✅ Training session saved with ID: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      print('❌ Error saving training session: $e');
      throw e;
    }
  }

  /// Update an existing training session
  static Future<void> updateTrainingSession(TrainingSession session) async {
    try {
      if (session.id == null) {
        throw Exception('Cannot update session without ID');
      }

      final sessionData = session.toFirestore();
      sessionData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_trainingSessions)
          .doc(session.id)
          .update(sessionData);

      print('✅ Training session updated: ${session.id}');

    } catch (e) {
      print('❌ Error updating training session: $e');
      throw e;
    }
  }

  /// Delete a training session
  static Future<void> deleteTrainingSession(String sessionId) async {
    try {
      await _firestore
          .collection(_trainingSessions)
          .doc(sessionId)
          .delete();

      print('✅ Training session deleted: $sessionId');

    } catch (e) {
      print('❌ Error deleting training session: $e');
      throw e;
    }
  }

  /// Get user profile
  
  /// Get training statistics
  static Future<Map<String, dynamic>> getTrainingStats() async {
    try {
      final sessions = await getUserTrainingSessions();
      
      if (sessions.isEmpty) {
        return {
          'totalSessions': 0,
          'totalDistance': 0.0,
          'totalTime': 0.0,
          'averageTime': 0.0,
          'bestTime': 0.0,
          'favoriteStroke': 'Freestyle',
          'averagePace': 0.0,
          'totalCalories': 0.0,
          'improvementRate': 0.0,
        };
      }

      final totalSessions = sessions.length;
      final totalDistance = sessions.totalDistance();
      final totalTime = sessions.totalTrainingTime();
      final averageTime = sessions.fold<double>(0, (sum, s) => sum + s.actualTime) / sessions.length;
      final bestTime = sessions.map((s) => s.actualTime).reduce((a, b) => a < b ? a : b);
      
      // Find favorite stroke
      final strokeCounts = <String, int>{};
      for (final session in sessions) {
        strokeCounts[session.strokeType] = (strokeCounts[session.strokeType] ?? 0) + 1;
      }
      final favoriteStroke = strokeCounts.entries.isNotEmpty
          ? strokeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : 'Freestyle';

      final averagePace = sessions.fold<double>(0, (sum, s) => sum + s.pacePer100m) / sessions.length;
      final totalCalories = sessions.fold<double>(0, (sum, s) => sum + s.calculateCaloriesBurned());
      final improvementRate = sessions.averageImprovement();

      return {
        'totalSessions': totalSessions,
        'totalDistance': totalDistance,
        'totalTime': totalTime,
        'averageTime': averageTime,
        'bestTime': bestTime,
        'favoriteStroke': favoriteStroke,
        'averagePace': averagePace,
        'totalCalories': totalCalories,
        'improvementRate': improvementRate,
      };

    } catch (e) {
      print('❌ Error getting training stats: $e');
      return {
        'totalSessions': 0,
        'totalDistance': 0.0,
        'totalTime': 0.0,
        'averageTime': 0.0,
        'bestTime': 0.0,
        'favoriteStroke': 'Freestyle',
        'averagePace': 0.0,
        'totalCalories': 0.0,
        'improvementRate': 0.0,
      };
    }
  }

  /// Get recent sessions (last 30 days)
  static Future<List<TrainingSession>> getRecentSessions({int days = 30}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    return await getSessionsInDateRange(startDate, endDate);
  }

  /// Get personal bests for each stroke
  static Future<Map<String, TrainingSession>> getPersonalBests() async {
    try {
      final sessions = await getUserTrainingSessions();
      final personalBests = <String, TrainingSession>{};

      for (final stroke in ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly']) {
        final strokeSessions = sessions.forStroke(stroke);
        if (strokeSessions.isNotEmpty) {
          personalBests[stroke] = strokeSessions.reduce((a, b) => 
              a.actualTime < b.actualTime ? a : b);
        }
      }

      return personalBests;

    } catch (e) {
      print('❌ Error getting personal bests: $e');
      return {};
    }
  }

  /// Count total sessions for current user
  static Future<int> getSessionCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final querySnapshot = await _firestore
          .collection(_trainingSessions)
          .where('userId', isEqualTo: user.uid)
          .get();

      return querySnapshot.docs.length;

    } catch (e) {
      print('❌ Error getting session count: $e');
      return 0;
    }
  }

  /// Get sessions grouped by month
  static Future<Map<String, List<TrainingSession>>> getSessionsByMonth() async {
    try {
      final sessions = await getUserTrainingSessions();
      final sessionsByMonth = <String, List<TrainingSession>>{};

      for (final session in sessions) {
        final monthKey = '${session.date.year}-${session.date.month.toString().padLeft(2, '0')}';
        sessionsByMonth[monthKey] ??= [];
        sessionsByMonth[monthKey]!.add(session);
      }

      return sessionsByMonth;

    } catch (e) {
      print('❌ Error getting sessions by month: $e');
      return {};
    }
  }
}