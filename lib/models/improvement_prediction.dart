import 'package:flutter/material.dart';

class ImprovementPrediction {
  final int swimmerId;
  final String stroke;
  final double improvement;
  final String description;
  final List<String> reasons;
  final List<String> topFactors;

  ImprovementPrediction({
    required this.swimmerId,
    required this.stroke,
    required this.improvement,
    required this.description,
    this.reasons = const [],
    this.topFactors = const [],
  });

  factory ImprovementPrediction.fromJson(Map<String, dynamic> json) {
    print('📦 Parsing prediction: $json'); // Debug log
    
    return ImprovementPrediction(
      swimmerId: json['swimmer_id'] ?? 0,
      stroke: json['stroke'] ?? 'Unknown',
      improvement: (json['improvement'] ?? 0).toDouble(),
      description: json['description'] ?? 'no change',
      reasons: json['reasons'] != null 
          ? List<String>.from(json['reasons'])
          : [],
      topFactors: json['top_factors'] != null
          ? List<String>.from(json['top_factors'])
          : [],
    );
  }

  // Helper to get color based on improvement
  Color get improvementColor {
    if (improvement > 0.1) return Colors.green;
    if (improvement < -0.1) return Colors.red;
    return Colors.orange;
  }

  // Helper to get icon based on improvement
  IconData get improvementIcon {
    if (improvement > 0.1) return Icons.trending_up;
    if (improvement < -0.1) return Icons.trending_down;
    return Icons.trending_flat;
  }
}