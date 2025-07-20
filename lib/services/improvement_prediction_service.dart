import 'dart:convert';
import 'dart:math';
import '../models/training_session.dart';

class ImprovementPredictionService {
  bool _isOfflineMode = false;
  bool _isInitialized = false;

  void initialize() {
    _isInitialized = true;
  }

  void forceOfflineMode() {
    _isOfflineMode = true;
  }

  Future<PredictionResponse> getPrediction({
    required List<TrainingSession> trainingHistory,
    required int daysToPredict,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 2));

      // For now, use offline prediction
      return _generateOfflinePrediction(trainingHistory, daysToPredict);
    } catch (e) {
      // Fallback to offline mode
      return _generateOfflinePrediction(trainingHistory, daysToPredict);
    }
  }

  PredictionResponse _generateOfflinePrediction(
    List<TrainingSession> trainingHistory,
    int daysToPredict,
  ) {
    final random = Random();
    final now = DateTime.now();
    
    // Calculate base accuracy from training data consistency
    double accuracy = _calculateAccuracy(trainingHistory);
    
    // Generate future predictions
    Map<String, List<DailyPrediction>> futurePredictions = {};
    
    for (int i = 1; i <= daysToPredict; i++) {
      final date = now.add(Duration(days: i)).toIso8601String().split('T')[0];
      
      List<DailyPrediction> predictions = [];
      
      // Generate predictions for different stroke types
      for (String stroke in ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly']) {
        final baseTime = _getAverageTimeForStroke(trainingHistory, stroke);
        final improvement = (random.nextDouble() * 4) - 2; // -2 to +2 seconds
        
        predictions.add(DailyPrediction(
          strokeType: stroke,
          predictedTime: baseTime + improvement,
          improvement: -improvement, // Negative improvement means faster time
          confidence: accuracy * (0.8 + random.nextDouble() * 0.2),
        ));
      }
      
      futurePredictions[date] = predictions;
    }

    // Generate swimmer summaries
    Map<String, SwimmerSummary> swimmerSummaries = {
      '1': SwimmerSummary(
        averageImprovement: _calculateAverageImprovement(trainingHistory),
        predictionCount: daysToPredict * 4,
        trend: _calculateTrend(trainingHistory),
      ),
    };

    return PredictionResponse(
      status: 'success',
      futurePredictions: FuturePredictions(
        byDate: futurePredictions,
        modelAccuracy: accuracy,
      ),
      swimmerSummaries: swimmerSummaries,
      modelInfo: ModelInfo(
        version: '1.0.0',
        lastTrained: DateTime.now().subtract(const Duration(days: 7)),
      ),
    );
  }

  double _calculateAccuracy(List<TrainingSession> sessions) {
    if (sessions.isEmpty) return 0.75;
    
    // Simple accuracy calculation based on data consistency
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
    if (strokeSessions.isEmpty) return 120.0; // Default time
    
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

  DailyPrediction({
    required this.strokeType,
    required this.predictedTime,
    required this.improvement,
    required this.confidence,
  });
}

class SwimmerSummary {
  final double averageImprovement;
  final int predictionCount;
  final String trend;

  SwimmerSummary({
    required this.averageImprovement,
    required this.predictionCount,
    required this.trend,
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