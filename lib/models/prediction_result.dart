class PredictionResult {
  final String swimmerId;
  final String name;
  final String strokeType;
  final String distance;
  final String predictedBestTime;
  final List<String> confidenceInterval;
  final DateTime predictionDate;
  final Map<String, dynamic> competition;
  final Map<String, dynamic> environmentalFactors;

  PredictionResult({
    required this.swimmerId,
    required this.name,
    required this.strokeType,
    required this.distance,
    required this.predictedBestTime,
    required this.confidenceInterval,
    required this.predictionDate,
    required this.competition,
    required this.environmentalFactors,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      swimmerId: json['swimmer_id'],
      name: json['name'],
      strokeType: json['stroke_type'],
      distance: json['distance'],
      predictedBestTime: json['predicted_best_time'],
      confidenceInterval: List<String>.from(json['confidence_interval']),
      predictionDate: DateTime.parse(json['prediction_date']),
      competition: json['competition'] ?? {},
      environmentalFactors: json['environmental_factors'] ?? {},
    );
  }
}
