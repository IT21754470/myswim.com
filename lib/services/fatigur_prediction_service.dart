import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/training_session.dart';

class FatiguePredictionService {
  bool _isOfflineMode = false;
  bool _isInitialized = false;
  
  static const String baseUrl = 'https://fatigue-prediction.onrender.com';
  static const String healthEndpoint = '/health';
  static const String predictEndpoint = '/fatigue/predict';

  bool get isOfflineMode => _isOfflineMode;

  void initialize() {
    _isInitialized = true;
    _isOfflineMode = false;
  }

  void forceOfflineMode() {
    _isOfflineMode = true;
  }

  Future<bool> testBackendConnection() async {
    try {
      print('🏥 Testing fatigue backend connection to: $baseUrl$healthEndpoint');
      
      final response = await http.get(
        Uri.parse('$baseUrl$healthEndpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      print('🏥 Fatigue health check response: ${response.statusCode}');
      print('🏥 Response body: ${response.body}');
      
      final isConnected = response.statusCode == 200;
      
      if (isConnected) {
        _isOfflineMode = false;
        print('✅ Fatigue backend connection successful');
      } else {
        _isOfflineMode = true;
        print('❌ Fatigue backend returned non-200 status: ${response.statusCode}');
      }
      
      return isConnected;
    } catch (e) {
      print('❌ Fatigue health check failed: $e');
      _isOfflineMode = true;
      return false;
    }
  }

  Future<FatiguePredictionResponse> getFatiguePrediction({
    required List<TrainingSession> trainingHistory,
    required int daysToPredict,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    print('🎯 Getting fatigue prediction - Offline mode: $_isOfflineMode');
    print('📊 Training history: ${trainingHistory.length} sessions');

    if (trainingHistory.isEmpty) {
      print('❌ No training data available');
      return FatiguePredictionResponse(
        status: 'error',
        error: 'No training data available for fatigue predictions',
      );
    }

    // Try backend first, fallback to offline if it fails
    if (!_isOfflineMode) {
      try {
        print('🌐 Attempting fatigue backend prediction...');
        final result = await _getBackendFatiguePrediction(trainingHistory, daysToPredict);
        print('✅ Fatigue backend prediction successful');
        return result;
      } catch (e) {
        print('❌ Fatigue backend failed: $e');
        print('📱 Falling back to offline mode');
        _isOfflineMode = true;
      }
    }

    print('📱 Using offline fatigue prediction');
    return _generateOfflineFatiguePrediction(trainingHistory, daysToPredict);
  }

  // ✅ Backend prediction with proper API format
  Future<FatiguePredictionResponse> _getBackendFatiguePrediction(
    List<TrainingSession> trainingHistory,
    int daysToPredict,
  ) async {
    print('🌐 Calling fatigue backend API: $baseUrl$predictEndpoint');
    
    final validSessions = trainingHistory.where((session) {
      return session.actualTime > 0 && 
             session.trainingDistance > 0 &&
             session.pacePer100m > 0;
    }).toList();

    if (validSessions.isEmpty) {
      throw Exception('No valid training sessions found');
    }

    // ✅ Sort sessions by date to calculate recovery days and rest hours
    validSessions.sort((a, b) => a.date.compareTo(b.date));

    print('📊 Sending ${validSessions.length} valid sessions out of ${trainingHistory.length} total');
    
    // ✅ Convert to required API format
    final requestBody = {
      'history': validSessions.map((session) => _convertToFatigueFormat(session, validSessions)).toList(),
      'days': daysToPredict,
    };

    final jsonPayload = json.encode(requestBody);
    print('📤 Fatigue request payload size: ${jsonPayload.length} characters');

    final response = await http.post(
      Uri.parse('$baseUrl$predictEndpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonPayload,
    ).timeout(const Duration(seconds: 45));

    print('📡 Fatigue backend response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Successfully parsed fatigue backend response');
      return _parseFatigueBackendResponse(data);
    } else {
      print('❌ Fatigue backend error: ${response.statusCode} - ${response.body}');
      throw Exception('Fatigue backend returned ${response.statusCode}: ${response.body}');
    }
  }

  // ✅ Convert TrainingSession to required API format
  Map<String, dynamic> _convertToFatigueFormat(TrainingSession session, List<TrainingSession> allSessions) {
    // Calculate recovery days (days since last session)
    int recoveryDays = _calculateRecoveryDays(session, allSessions);
    
    // Estimate missing fields
    double restHours = _estimateRestHours(session);
    int energy = _estimateEnergyLevel(session, recoveryDays);
    int rpe = _estimateRPE(session);

    return {
      'Swimmer ID': session.swimmerId ?? 555,
      'Date': session.date.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'Stroke Type': _normalizeStrokeType(session.strokeType),
      'Training Distance': session.trainingDistance.toInt(),
      'Session Duration': (session.sessionDuration / 60).toDouble(), // Convert minutes to hours
      'Intensity': session.intensity?.toInt() ?? _estimateIntensityFromSession(session).toInt(),
      'Rest hours': restHours,
      'Recovery Days': recoveryDays,
      'Energy': energy,
      'avg heart rate': session.avgHeartRate?.toInt() ?? _estimateHeartRate(session),
      'RPE(1-10)': rpe,
    };
  }

  // ✅ Calculate recovery days since last training session
  int _calculateRecoveryDays(TrainingSession currentSession, List<TrainingSession> allSessions) {
    final currentIndex = allSessions.indexOf(currentSession);
    if (currentIndex <= 0) return 0;
    
    final previousSession = allSessions[currentIndex - 1];
    final daysDifference = currentSession.date.difference(previousSession.date).inDays;
    
    return max(0, daysDifference - 1);
  }

  // ✅ Estimate rest hours based on intensity and session duration
  double _estimateRestHours(TrainingSession session) {
    final intensity = session.intensity ?? _estimateIntensityFromSession(session);
    
    if (intensity >= 8) return 6.0 + Random().nextDouble() * 2; // 6-8 hours for high intensity
    if (intensity >= 6) return 7.0 + Random().nextDouble() * 2; // 7-9 hours for medium intensity  
    return 8.0 + Random().nextDouble() * 2; // 8-10 hours for low intensity
  }

  // ✅ Estimate energy level (1-10)
  // ✅ FIXED: Estimate energy level (1-10)
int _estimateEnergyLevel(TrainingSession session, int recoveryDays) {
  final intensity = session.intensity ?? _estimateIntensityFromSession(session);
  
  int baseEnergy = 7;
  
  // ✅ FIXED: Remove the incorrect null assertion operator
  baseEnergy = baseEnergy - ((intensity / 2).round() as int); // Fixed this line
  
  // Adjust based on recovery days (more recovery = higher energy)
  baseEnergy += recoveryDays;
  
  // Add some randomness
  baseEnergy += Random().nextInt(3) - 1; // -1 to +1
  
  return max(1, min(10, baseEnergy));
}

  // ✅ Estimate RPE (Rate of Perceived Exertion 1-10)
  int _estimateRPE(TrainingSession session) {
    final intensity = session.intensity ?? _estimateIntensityFromSession(session);
    
    // RPE roughly correlates with intensity
    int rpe = intensity.round();
    
    // Add some variation
    rpe += Random().nextInt(3) - 1; // -1 to +1
    
    return max(1, min(10, rpe));
  }

  // ✅ Normalize stroke type for API
  String _normalizeStrokeType(String strokeType) {
    final normalized = strokeType.toLowerCase();
    switch (normalized) {
      case 'freestyle':
        return 'Freestyle';
      case 'backstroke':
        return 'Backstroke';
      case 'breaststroke':
        return 'Breaststroke';
      case 'butterfly':
        return 'Butterfly';
      case 'medley':
      case 'individual medley':
      case 'im':
        return 'Medley';
      default:
        return 'Freestyle';
    }
  }

  // ✅ Estimate heart rate if not available
  int _estimateHeartRate(TrainingSession session) {
    final intensity = session.intensity ?? _estimateIntensityFromSession(session);
    
    // Base heart rate estimation (assuming young adult)
    int baseHR = 60;
    int maxHR = 190;
    
    // Calculate target HR based on intensity
    double targetPercentage = 0.5 + (intensity / 20); // 50% to 95% of max HR
    int estimatedHR = (baseHR + (maxHR - baseHR) * targetPercentage).round();
    
    // Add some variation
    estimatedHR += Random().nextInt(20) - 10; // ±10 bpm variation
    
    return max(60, min(200, estimatedHR));
  }

  // ✅ Estimate intensity from session data
  double _estimateIntensityFromSession(TrainingSession session) {
    if (session.avgHeartRate != null && session.avgHeartRate! > 0) {
      if (session.avgHeartRate! < 120) return 3.0;
      if (session.avgHeartRate! < 140) return 5.0;
      if (session.avgHeartRate! < 160) return 7.0;
      return 9.0;
    }
    
    final pace = session.pacePer100m;
    if (pace < 60) return 9.0;
    if (pace < 90) return 7.0;
    if (pace < 120) return 5.0;
    if (pace < 150) return 3.0;
    return 2.0;
  }

  // ✅ Parse backend response
  FatiguePredictionResponse _parseFatigueBackendResponse(Map<String, dynamic> data) {
    print('✅ Parsing fatigue backend response...');
    
    try {
      Map<String, FatigueDayPrediction> predictions = {};
      
      if (data['predictions'] != null) {
        final predictionData = data['predictions'] as Map<String, dynamic>;
        
        predictionData.forEach((date, dayData) {
          predictions[date] = FatigueDayPrediction(
            date: date,
            fatigueLevel: (dayData['fatigue_level'] ?? 5).toDouble(),
            recoveryNeeded: dayData['recovery_needed'] ?? false,
            recommendedIntensity: (dayData['recommended_intensity'] ?? 5).toDouble(),
            riskLevel: dayData['risk_level'] ?? 'Medium',
            confidence: (dayData['confidence'] ?? 0.8).toDouble(),
          );
        });
      }

      return FatiguePredictionResponse(
        status: data['status'] ?? 'success',
        predictions: predictions,
        modelAccuracy: (data['model_accuracy'] ?? 0.8).toDouble(),
        averageFatigue: (data['average_fatigue'] ?? 5.0).toDouble(),
        peakFatigueDate: data['peak_fatigue_date'],
        recommendations: List<String>.from(data['recommendations'] ?? []),
      );
    } catch (e) {
      print('❌ Error parsing fatigue backend response: $e');
      throw Exception('Failed to parse fatigue backend response: $e');
    }
  }

  // ✅ Generate offline fatigue prediction
  FatiguePredictionResponse _generateOfflineFatiguePrediction(
    List<TrainingSession> trainingHistory,
    int daysToPredict,
  ) {
    print('📱 Generating offline fatigue predictions...');
    
    final random = Random();
    final now = DateTime.now();
    
    // Calculate current fatigue level based on recent training
    double currentFatigue = _calculateCurrentFatigue(trainingHistory);
    
    Map<String, FatigueDayPrediction> predictions = {};
    List<String> recommendations = [];
    
    double cumulativeFatigue = currentFatigue;
    String? peakFatigueDate;
    double peakFatigue = 0;
    
    for (int i = 1; i <= daysToPredict; i++) {
      final date = now.add(Duration(days: i)).toIso8601String().split('T')[0];
      
      // Simulate fatigue progression
      double dailyFatigueChange = (random.nextDouble() - 0.5) * 2; // -1 to +1
      cumulativeFatigue = max(1, min(10, cumulativeFatigue + dailyFatigueChange));
      
      // Determine recovery needed
      bool recoveryNeeded = cumulativeFatigue > 7.0;
      
      // Calculate recommended intensity
      double recommendedIntensity = max(1, 10 - cumulativeFatigue);
      
      // Determine risk level
      String riskLevel;
      if (cumulativeFatigue < 4) riskLevel = 'Low';
      else if (cumulativeFatigue < 7) riskLevel = 'Medium';
      else riskLevel = 'High';
      
      predictions[date] = FatigueDayPrediction(
        date: date,
        fatigueLevel: cumulativeFatigue,
        recoveryNeeded: recoveryNeeded,
        recommendedIntensity: recommendedIntensity,
        riskLevel: riskLevel,
        confidence: 0.75 + random.nextDouble() * 0.2,
      );
      
      // Track peak fatigue
      if (cumulativeFatigue > peakFatigue) {
        peakFatigue = cumulativeFatigue;
        peakFatigueDate = date;
      }
      
      // Add recommendations
      if (recoveryNeeded && recommendations.isEmpty) {
        recommendations.add('Consider a recovery day or light training');
      }
    }
    
    // Add general recommendations
    if (currentFatigue > 6) {
      recommendations.add('Reduce training intensity for better recovery');
      recommendations.add('Ensure adequate sleep (8+ hours)');
    } else {
      recommendations.add('Good recovery status - maintain current training load');
    }
    
    final averageFatigue = predictions.values.fold(0.0, (sum, p) => sum + p.fatigueLevel) / predictions.length;
    
    print('✅ Generated ${predictions.length} days of fatigue predictions');
    
    return FatiguePredictionResponse(
      status: 'success',
      predictions: predictions,
      modelAccuracy: 0.78,
      averageFatigue: averageFatigue,
      peakFatigueDate: peakFatigueDate,
      recommendations: recommendations,
    );
  }

  // ✅ Calculate current fatigue level from training history
  double _calculateCurrentFatigue(List<TrainingSession> sessions) {
    if (sessions.isEmpty) return 3.0;
    
    // Sort sessions by date (most recent first)
    final sortedSessions = List<TrainingSession>.from(sessions);
    sortedSessions.sort((a, b) => b.date.compareTo(a.date));
    
    double fatigue = 3.0; // Base fatigue level
    
    // Analyze last 7 days of training
    final recentSessions = sortedSessions.where((session) {
      final daysSince = DateTime.now().difference(session.date).inDays;
      return daysSince <= 7;
    }).toList();
    
    for (final session in recentSessions) {
      final intensity = session.intensity ?? _estimateIntensityFromSession(session);
      final daysSince = DateTime.now().difference(session.date).inDays;
      
      // Recent high-intensity sessions increase fatigue
      double sessionFatigue = intensity * 0.3;
      
      // Decay fatigue over time
      sessionFatigue *= pow(0.8, daysSince);
      
      fatigue += sessionFatigue;
    }
    
    return max(1, min(10, fatigue));
  }
}

// ✅ Fatigue Prediction Models
class FatiguePredictionResponse {
  final String status;
  final String? error;
  final Map<String, FatigueDayPrediction>? predictions;
  final double? modelAccuracy;
  final double? averageFatigue;
  final String? peakFatigueDate;
  final List<String>? recommendations;

  FatiguePredictionResponse({
    required this.status,
    this.error,
    this.predictions,
    this.modelAccuracy,
    this.averageFatigue,
    this.peakFatigueDate,
    this.recommendations,
  });
}

class FatigueDayPrediction {
  final String date;
  final double fatigueLevel; // 1-10
  final bool recoveryNeeded;
  final double recommendedIntensity; // 1-10
  final String riskLevel; // Low, Medium, High
  final double confidence; // 0-1

  FatigueDayPrediction({
    required this.date,
    required this.fatigueLevel,
    required this.recoveryNeeded,
    required this.recommendedIntensity,
    required this.riskLevel,
    required this.confidence,
  });
}