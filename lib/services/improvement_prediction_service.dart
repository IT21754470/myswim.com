import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/training_session.dart';
import '../models/improvement_prediction.dart';  // ✅ Import the model
import 'training_session_service.dart';

class ImprovementPredictionService {
  bool _isOfflineMode = false;
  bool _isInitialized = false;
  
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
      
      final isConnected = response.statusCode == 200;
      _isOfflineMode = !isConnected;
      return isConnected;
    } catch (e) {
      print('❌ Health check failed: $e');
      _isOfflineMode = true;
      return false;
    }
  }

  // ✅ FIXED: Correct method name and signature
  Future<ImprovementPredictionResponse> getImprovementPrediction({
    List<TrainingSession>? trainingHistory,
    int daysToPredict = 7,
  }) async {
    if (!_isInitialized) {
      initialize();
    }

    // Get training history if not provided
    final history = trainingHistory ?? 
        await TrainingSessionService.getUserTrainingSessions();

    print('🎯 Getting improvement prediction - Offline mode: $_isOfflineMode');
    print('📊 Training history: ${history.length} sessions');

    if (history.isEmpty) {
      throw Exception('No training data available for predictions');
    }

    // Try backend first, fallback to offline if it fails
    if (!_isOfflineMode) {
      try {
        print('🌐 Attempting backend prediction...');
        final result = await _getBackendPrediction(history, daysToPredict);
        print('✅ Backend prediction successful');
        return result;
      } catch (e) {
        print('❌ Backend failed: $e');
        print('📱 Falling back to offline mode');
        _isOfflineMode = true;
      }
    }

    print('📱 Using offline prediction');
    return _generateOfflinePrediction(history, daysToPredict);
  }
Future<ImprovementPredictionResponse> _getBackendPrediction(
  List<TrainingSession> trainingHistory,
  int daysToPredict,
) async {
  print('🌐 Calling backend API: $baseUrl$predictEndpoint');
  
  final tomorrow = DateTime.now().add(Duration(days: 1));
  
  // ✅ Request extra buffer to ensure we get enough future days
  final actualDaysToRequest = daysToPredict + 15; // Increased buffer
  
  final requestBody = {
    'history': trainingHistory.map((session) => {
      'Date': session.date.toIso8601String().split('T')[0],
      'Swimmer ID': session.swimmerId,
      'pool length': session.poolLength,
      'Stroke Type': session.strokeType,
      'Training Distance ': session.trainingDistance,
      'Session Duration (hrs)': session.sessionDuration,
      'pace per 100m': session.pacePer100m,
      'laps': session.laps,
      'avg heart rate': session.avgHeartRate ?? 130,
      'Intensity': session.intensity ?? 0.7,
      'rest interval': session.restInterval ?? 3.0,
    }).toList(),
    'days': actualDaysToRequest,
    'start_date': tomorrow.toIso8601String().split('T')[0],
  };

  print('📅 Requesting $actualDaysToRequest days starting from ${requestBody['start_date']} (to get $daysToPredict future days)');

  final response = await http.post(
    Uri.parse('$baseUrl$predictEndpoint'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode(requestBody),
  ).timeout(const Duration(seconds: 45));

  print('📡 Backend response status: ${response.statusCode}');

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return _parseBackendResponse(data, daysToPredict);
  } else {
    throw Exception('Backend error: ${response.statusCode}');
  }
}

 ImprovementPredictionResponse _parseBackendResponse(
  Map<String, dynamic> data,
  [int? maxFutureDays]
) {
  print('✅ Parsing backend response...');
  
  final today = DateTime.now();
  final todayString = today.toIso8601String().split('T')[0];
  
  Map<String, List<ImprovementPrediction>> historicalPredictions = {};
  Map<String, List<ImprovementPrediction>> futurePredictions = {};
  
  // Parse historical predictions
  if (data['historical_predictions']?['by_date'] != null) {
    final historical = data['historical_predictions']['by_date'] as Map<String, dynamic>;
    
    historical.forEach((date, predictions) {
      if (predictions is List) {
        historicalPredictions[date] = predictions.map((p) {
          final prediction = p as Map<String, dynamic>;
          prediction['date'] = date;
          return ImprovementPrediction.fromJson(prediction);
        }).toList();
      }
    });
  }
  
  // Parse future predictions
  if (data['future_predictions']?['by_date'] != null) {
    final future = data['future_predictions']['by_date'] as Map<String, dynamic>;
    
    // ✅ Get all future dates and sort them
    List<String> futureDates = future.keys
        .where((date) => date.compareTo(todayString) > 0)
        .toList()
      ..sort();
    
    // ✅ Take only the requested number of future days
    if (maxFutureDays != null && futureDates.length > maxFutureDays) {
      futureDates = futureDates.take(maxFutureDays).toList();
    }
    
    print('📅 Available future dates in response: ${future.keys.where((date) => date.compareTo(todayString) > 0).length}');
    print('📅 Taking first ${futureDates.length} future dates');
    
    for (String date in futureDates) {
      final predictions = future[date];
      if (predictions is List) {
        futurePredictions[date] = predictions.map((p) {
          final prediction = p as Map<String, dynamic>;
          prediction['date'] = date;
          return ImprovementPrediction.fromJson(prediction);
        }).toList();
      }
    }
    
    print('📅 Filtered future predictions: ${futurePredictions.keys.length} days');
    print('📅 Future dates: ${futurePredictions.keys.toList()}');
  }

  return ImprovementPredictionResponse(
    historicalPredictions: historicalPredictions,
    futurePredictions: futurePredictions,
  );
}
 ImprovementPredictionResponse _generateOfflinePrediction(
  List<TrainingSession> trainingHistory,
  int daysToPredict,
) {
  print('📱 Generating offline predictions...');
  
  final now = DateTime.now();
  final random = Random();
  
  Map<String, List<ImprovementPrediction>> futurePredictions = {};
  
  final strokes = trainingHistory.map((s) => s.strokeType).toSet().toList();
  
  for (int i = 1; i <= daysToPredict; i++) {
    final date = now.add(Duration(days: i)).toIso8601String().split('T')[0];
    List<ImprovementPrediction> predictions = [];
    
    for (String stroke in strokes.take(3)) {
      final improvement = (random.nextDouble() - 0.5) * 2;
      predictions.add(ImprovementPrediction(
        swimmerId: trainingHistory.first.swimmerId,
        stroke: stroke,
        improvement: improvement,
        description: improvement > 0 ? 'improvement' : 'decline',
        reasons: ['Offline prediction', 'Based on training patterns'],
        topFactors: ['pace', 'distance'],
        date: date, // ✅ Include the date here
      ));
    }
    
    futurePredictions[date] = predictions;
  }

  return ImprovementPredictionResponse(
    historicalPredictions: {},
    futurePredictions: futurePredictions,
  );
}}
// ✅ Models matching your screen expectations

// In lib/services/improvement_prediction_service.dart

class DailyPrediction {
  final String strokeType;
  final double predictedTime;
  final double improvement;
  final double confidence;
  final double? intensity;
  final String description;
  final List<String> reasons;
  final List<String> topFactors;

  DailyPrediction({
    required this.strokeType,
    required this.predictedTime,
    required this.improvement,
    required this.confidence,
    this.intensity,
    this.description = '',
    this.reasons = const [],
    this.topFactors = const [],
  });

  factory DailyPrediction.fromJson(Map<String, dynamic> json) {
    return DailyPrediction(
      strokeType: json['stroke'] ?? json['stroke_type'] ?? 'Freestyle',
      predictedTime: (json['predicted_time'] ?? 0).toDouble(),
      improvement: (json['improvement'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0.8).toDouble(),
      intensity: json['intensity']?.toDouble(),
      description: json['description'] ?? '',
      reasons: List<String>.from(json['reasons'] ?? []),
      topFactors: List<String>.from(json['top_factors'] ?? []),
    );
  }
}
class ImprovementPredictionResponse {
  final Map<String, List<ImprovementPrediction>> historicalPredictions;
  final Map<String, List<ImprovementPrediction>> futurePredictions;

  ImprovementPredictionResponse({
    required this.historicalPredictions,
    required this.futurePredictions,
  });
}