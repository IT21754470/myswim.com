import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/training_session.dart';

class ImprovementPredictionService {
  bool _isOfflineMode = false;
  bool _isInitialized = false;
  
  // ✅ FIXED: Correct base URL structure
  static const String baseUrl = 'https://fatigue-prediction.onrender.com';
  static const String healthEndpoint = '/health';
  static const String predictEndpoint = '/improvement/predict';

  bool get isOfflineMode => _isOfflineMode;

  void initialize() {
    _isInitialized = true;
    _isOfflineMode = false;
  }

  void forceOfflineMode() {
    _isOfflineMode = true;
  }

  // ✅ FIXED: Proper health check URL
  Future<bool> testBackendConnection() async {
    try {
      print('🏥 Testing backend connection to: $baseUrl$healthEndpoint');
      
      final response = await http.get(
        Uri.parse('$baseUrl$healthEndpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      print('🏥 Health check response: ${response.statusCode}');
      print('🏥 Response body: ${response.body}');
      
      final isConnected = response.statusCode == 200;
      
      if (isConnected) {
        _isOfflineMode = false;
        print('✅ Backend connection successful');
      } else {
        _isOfflineMode = true;
        print('❌ Backend returned non-200 status: ${response.statusCode}');
      }
      
      return isConnected;
    } catch (e) {
      print('❌ Health check failed: $e');
      _isOfflineMode = true;
      return false;
    }
  }

  Future<PredictionResponse> getPrediction({
    required List<TrainingSession> trainingHistory,
    required int daysToPredict,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    print('🎯 Getting prediction - Offline mode: $_isOfflineMode');
    print('📊 Training history: ${trainingHistory.length} sessions');

    if (trainingHistory.isEmpty) {
      print('❌ No training data available');
      return PredictionResponse(
        status: 'error',
        error: 'No training data available for predictions',
      );
    }

    // Try backend first, fallback to offline if it fails
    if (!_isOfflineMode) {
      try {
        print('🌐 Attempting backend prediction...');
        final result = await _getBackendPrediction(trainingHistory, daysToPredict);
        print('✅ Backend prediction successful');
        return result;
      } catch (e) {
        print('❌ Backend failed: $e');
        print('📱 Falling back to offline mode');
        _isOfflineMode = true;
      }
    }

    print('📱 Using offline prediction');
    return _generateOfflinePrediction(trainingHistory, daysToPredict);
  }

  // ✅ FIXED: Correct API endpoint URL
  Future<PredictionResponse> _getBackendPrediction(
    List<TrainingSession> trainingHistory,
    int daysToPredict,
  ) async {
    print('🌐 Calling backend API: $baseUrl$predictEndpoint');
    
    final validSessions = trainingHistory.where((session) {
      return session.actualTime > 0 && 
             session.trainingDistance > 0 &&
             session.pacePer100m > 0;
    }).toList();

    if (validSessions.isEmpty) {
      throw Exception('No valid training sessions found');
    }

    print('📊 Sending ${validSessions.length} valid sessions out of ${trainingHistory.length} total');
    
    // ✅ FIXED: Try multiple payload structures
    final requestBody = {
      'training_data': validSessions.map((session) => {
        'swimmer_id': session.swimmerId ?? 1,
        'pool_length': session.poolLength ?? 25,
        'date': session.date.toIso8601String(),
        'stroke_type': session.strokeType ?? 'Freestyle',
        'training_distance': session.trainingDistance,
        'session_duration': session.sessionDuration,
        'pace_per_100m': session.pacePer100m,
        'laps': session.laps ?? (session.trainingDistance / (session.poolLength ?? 25)).round(),
        'avg_heart_rate': session.avgHeartRate ?? 0,
        'rest_interval': session.restInterval ?? 0,
        'base_time': session.baseTime ?? session.actualTime,
        'actual_time': session.actualTime,
        'gender': session.gender ?? 'Male',
        'intensity': session.intensity ?? _estimateIntensityFromSession(session),
      }).toList(),
      'training_history': validSessions.map((session) => {
        'swimmer_id': session.swimmerId ?? 1,
        'pool_length': session.poolLength ?? 25,
        'date': session.date.toIso8601String(),
        'stroke_type': session.strokeType ?? 'Freestyle',
        'training_distance': session.trainingDistance,
        'session_duration': session.sessionDuration,
        'pace_per_100m': session.pacePer100m,
        'laps': session.laps ?? (session.trainingDistance / (session.poolLength ?? 25)).round(),
        'avg_heart_rate': session.avgHeartRate ?? 0,
        'rest_interval': session.restInterval ?? 0,
        'base_time': session.baseTime ?? session.actualTime,
        'actual_time': session.actualTime,
        'gender': session.gender ?? 'Male',
        'intensity': session.intensity ?? _estimateIntensityFromSession(session),
      }).toList(),
      'days_to_predict': daysToPredict,
      'prediction_days': daysToPredict,
    };

    final jsonPayload = json.encode(requestBody);
    print('📤 Request payload size: ${jsonPayload.length} characters');

    final response = await http.post(
      Uri.parse('$baseUrl$predictEndpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonPayload,
    ).timeout(const Duration(seconds: 45));

    print('📡 Backend response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Successfully parsed backend response');
      return _parseBackendResponse(data);
    } else {
      print('❌ Backend error: ${response.statusCode} - ${response.body}');
      throw Exception('Backend returned ${response.statusCode}: ${response.body}');
    }
  }

  // ✅ ADD THIS MISSING METHOD
  double _estimateIntensityFromSession(TrainingSession session) {
    // Use heart rate if available
    if (session.avgHeartRate != null && session.avgHeartRate! > 0) {
      if (session.avgHeartRate! < 120) return 3.0;
      if (session.avgHeartRate! < 140) return 5.0;
      if (session.avgHeartRate! < 160) return 7.0;
      return 9.0;
    }
    
    // Estimate based on pace (faster pace = higher intensity)
    final pace = session.pacePer100m;
    if (pace < 60) return 9.0;   // Very fast
    if (pace < 90) return 7.0;   // Fast
    if (pace < 120) return 5.0;  // Moderate
    if (pace < 150) return 3.0;  // Easy
    return 2.0; // Very easy
  }

  // ✅ IMPROVED: Better response parsing with error handling
  PredictionResponse _parseBackendResponse(Map<String, dynamic> data) {
    print('✅ Parsing backend response...');
    
    try {
      Map<String, List<DailyPrediction>> futurePredictions = {};
      
      if (data['future_predictions'] != null) {
        final predictions = data['future_predictions'] as Map<String, dynamic>;
        
        predictions.forEach((date, predictionsList) {
          List<DailyPrediction> dailyPreds = [];
          
          if (predictionsList is List) {
            for (var pred in predictionsList) {
              try {
                dailyPreds.add(DailyPrediction(
                  strokeType: pred['stroke_type'] ?? 'Freestyle',
                  predictedTime: (pred['predicted_time'] ?? 0).toDouble(),
                  improvement: (pred['improvement'] ?? 0).toDouble(),
                  confidence: (pred['confidence'] ?? 0.8).toDouble(),
                  intensity: pred['intensity']?.toDouble() ?? 5.0,
                ));
              } catch (e) {
                print('⚠️ Error parsing prediction: $e');
                continue;
              }
            }
          }
          
          if (dailyPreds.isNotEmpty) {
            futurePredictions[date] = dailyPreds;
          }
        });
      }

      Map<String, SwimmerSummary> swimmerSummaries = {};
      if (data['swimmer_summaries'] != null) {
        final summaries = data['swimmer_summaries'] as Map<String, dynamic>;
        
        summaries.forEach((swimmerId, summary) {
          try {
            swimmerSummaries[swimmerId] = SwimmerSummary(
              averageImprovement: (summary['average_improvement'] ?? 0).toDouble(),
              predictionCount: summary['prediction_count'] ?? 0,
              trend: summary['trend'] ?? 'stable',
              averageIntensity: summary['average_intensity']?.toDouble() ?? 5.0,
            );
          } catch (e) {
            print('⚠️ Error parsing swimmer summary: $e');
          }
        });
      }

      return PredictionResponse(
        status: data['status'] ?? 'success',
        futurePredictions: FuturePredictions(
          byDate: futurePredictions,
          modelAccuracy: (data['model_accuracy'] ?? 0.8).toDouble(),
        ),
        swimmerSummaries: swimmerSummaries,
        modelInfo: ModelInfo(
          version: data['model_version'] ?? '1.0.0',
          lastTrained: DateTime.tryParse(data['last_trained'] ?? '') ?? DateTime.now(),
        ),
      );
    } catch (e) {
      print('❌ Error parsing backend response: $e');
      throw Exception('Failed to parse backend response: $e');
    }
  }

  // ✅ IMPROVED: Better offline predictions
  PredictionResponse _generateOfflinePrediction(
    List<TrainingSession> trainingHistory,
    int daysToPredict,
  ) {
    print('📱 Generating offline predictions...');
    
    final random = Random();
    final now = DateTime.now();
    
    double accuracy = _calculateAccuracy(trainingHistory);
    
    // Get user's actual strokes from history
    final strokeCounts = <String, int>{};
    for (final session in trainingHistory) {
      strokeCounts[session.strokeType] = (strokeCounts[session.strokeType] ?? 0) + 1;
    }
    
    final userStrokes = strokeCounts.keys.toList();
    if (userStrokes.isEmpty) {
      userStrokes.addAll(['Freestyle']);
    }
    
    Map<String, List<DailyPrediction>> futurePredictions = {};
    
    for (int i = 1; i <= daysToPredict; i++) {
      final date = now.add(Duration(days: i)).toIso8601String().split('T')[0];
      List<DailyPrediction> predictions = [];
      
      for (String stroke in userStrokes.take(3)) {
        final baseTime = _getAverageTimeForStroke(trainingHistory, stroke);
        final improvement = _calculateRealisticImprovement(trainingHistory, stroke, i);
        final intensity = _getAverageIntensityForStroke(trainingHistory, stroke);
        
        predictions.add(DailyPrediction(
          strokeType: stroke,
          predictedTime: max(30.0, baseTime + improvement),
          improvement: -improvement,
          confidence: accuracy * (0.85 + random.nextDouble() * 0.1),
          intensity: max(1.0, min(10.0, intensity + (random.nextDouble() - 0.5))),
        ));
      }
      
      futurePredictions[date] = predictions;
    }

    Map<String, SwimmerSummary> swimmerSummaries = {
      '1': SwimmerSummary(
        averageImprovement: _calculateAverageImprovement(trainingHistory),
        predictionCount: futurePredictions.values.expand((x) => x).length,
        trend: _calculateTrend(trainingHistory),
        averageIntensity: _calculateAverageIntensity(trainingHistory),
      ),
    };

    print('✅ Generated ${futurePredictions.length} days of predictions');

    return PredictionResponse(
      status: 'success',
      futurePredictions: FuturePredictions(
        byDate: futurePredictions,
        modelAccuracy: accuracy,
      ),
      swimmerSummaries: swimmerSummaries,
      modelInfo: ModelInfo(
        version: '1.0.0-offline',
        lastTrained: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
  }

  // ✅ ADD ALL MISSING HELPER METHODS
  double _calculateRealisticImprovement(List<TrainingSession> sessions, String stroke, int dayOffset) {
    final strokeSessions = sessions.where((s) => s.strokeType == stroke).toList();
    if (strokeSessions.isEmpty) return Random().nextDouble() * 2 - 1;
    
    strokeSessions.sort((a, b) => a.date.compareTo(b.date));
    
    double trendFactor = 0;
    if (strokeSessions.length > 1) {
      final recent = strokeSessions.skip(max(0, strokeSessions.length - 5)).toList();
      for (int i = 1; i < recent.length; i++) {
        trendFactor += recent[i-1].actualTime - recent[i].actualTime;
      }
      trendFactor /= (recent.length - 1);
    }
    
    final baseTrend = trendFactor * (1.0 - (dayOffset * 0.05));
    final randomVariation = (Random().nextDouble() - 0.5) * 1.5;
    
    return -(baseTrend + randomVariation);
  }

  double _getAverageIntensityForStroke(List<TrainingSession> sessions, String stroke) {
    final strokeSessions = sessions.where((s) => s.strokeType == stroke);
    if (strokeSessions.isEmpty) return 5.0;
    
    double totalIntensity = 0;
    int count = 0;
    
    for (final session in strokeSessions) {
      double intensity = session.intensity ?? _estimateIntensityFromSession(session);
      totalIntensity += intensity;
      count++;
    }
    
    return count > 0 ? totalIntensity / count : 5.0;
  }

  double _calculateAccuracy(List<TrainingSession> sessions) {
    if (sessions.isEmpty) return 0.75;
    
    double consistency = 0.0;
    if (sessions.length > 1) {
      List<double> times = sessions.map((s) => s.actualTime).toList();
      double mean = times.reduce((a, b) => a + b) / times.length;
      double variance = times.map((t) => pow(t - mean, 2)).reduce((a, b) => a + b) / times.length;
      double stdDev = sqrt(variance);
      consistency = max(0, 1 - (stdDev / mean));
    }
    
    return min(0.95, max(0.6, 0.75 + consistency * 0.2));
  }

  double _getAverageTimeForStroke(List<TrainingSession> sessions, String stroke) {
    var strokeSessions = sessions.where((s) => s.strokeType == stroke);
    if (strokeSessions.isEmpty) return 120.0;
    
    return strokeSessions.map((s) => s.actualTime).reduce((a, b) => a + b) / strokeSessions.length;
  }

  double _calculateAverageImprovement(List<TrainingSession> sessions) {
    if (sessions.length < 2) return 0.5;
    
    sessions.sort((a, b) => a.date.compareTo(b.date));
    
    double totalImprovement = 0;
    int count = 0;
    
    for (int i = 1; i < sessions.length; i++) {
      if (sessions[i].strokeType == sessions[i-1].strokeType) {
        totalImprovement += sessions[i-1].actualTime - sessions[i].actualTime;
        count++;
      }
    }
    
    return count > 0 ? totalImprovement / count : 0.5;
  }

  double _calculateAverageIntensity(List<TrainingSession> sessions) {
    if (sessions.isEmpty) return 5.0;
    
    double totalIntensity = 0;
    for (var session in sessions) {
      totalIntensity += session.intensity ?? _estimateIntensityFromSession(session);
    }
    
    return totalIntensity / sessions.length;
  }

  String _calculateTrend(List<TrainingSession> sessions) {
    if (sessions.length < 3) return 'stable';
    
    sessions.sort((a, b) => a.date.compareTo(b.date));
    
    int improvements = 0;
    int declines = 0;
    
    for (int i = 1; i < sessions.length; i++) {
      if (sessions[i].strokeType == sessions[i-1].strokeType) {
        if (sessions[i].actualTime < sessions[i-1].actualTime) {
          improvements++;
        } else {
          declines++;
        }
      }
    }
    
    if (improvements > declines * 1.5) return 'improving';
    if (declines > improvements * 1.5) return 'declining';
    return 'stable';
  }
}

// Models remain the same...
class PredictionResponse {
  final String status;
  final String? error;
  final FuturePredictions? futurePredictions;
  final Map<String, SwimmerSummary>? swimmerSummaries;
  final ModelInfo? modelInfo;

  PredictionResponse({
    required this.status,
    this.error,
    this.futurePredictions,
    this.swimmerSummaries,
    this.modelInfo,
  });
}

class FuturePredictions {
  final Map<String, List<DailyPrediction>> byDate;
  final double modelAccuracy;

  FuturePredictions({
    required this.byDate,
    required this.modelAccuracy,
  });
}

class DailyPrediction {
  final String strokeType;
  final double predictedTime;
  final double improvement;
  final double confidence;
  final double? intensity;

  DailyPrediction({
    required this.strokeType,
    required this.predictedTime,
    required this.improvement,
    required this.confidence,
    this.intensity,
  });
}

class SwimmerSummary {
  final double averageImprovement;
  final int predictionCount;
  final String trend;
  final double? averageIntensity;

  SwimmerSummary({
    required this.averageImprovement,
    required this.predictionCount,
    required this.trend,
    this.averageIntensity,
  });
}

class ModelInfo {
  final String version;
  final DateTime lastTrained;

  ModelInfo({
    required this.version,
    required this.lastTrained,
  });
}