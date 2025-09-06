import 'package:flutter/material.dart';

class StrokeUtils {
  static const Map<String, IconData> _strokeIcons = {
    'Freestyle': Icons.waves,
    'Backstroke': Icons.water,
    'Breaststroke': Icons.pool,
    'Butterfly': Icons.flight,
    'Individual Medley': Icons.compare_arrows,
    'Mixed': Icons.shuffle,
  };

  static const Map<String, Color> _strokeColors = {
    'Freestyle': Color(0xFF4A90E2),
    'Backstroke': Color(0xFF50C878),
    'Breaststroke': Color(0xFFFF6B6B),
    'Butterfly': Color(0xFFFFD700),
    'Individual Medley': Color(0xFF9370DB),
    'Mixed': Color(0xFF20B2AA),
  };

  static const Map<String, String> _strokeDescriptions = {
    'Freestyle': 'Front crawl stroke with alternating arm movements',
    'Backstroke': 'Swimming on the back with alternating arm strokes',
    'Breaststroke': 'Frog-like stroke with simultaneous arm and leg movements',
    'Butterfly': 'Dolphin-like stroke with simultaneous arm movements',
    'Individual Medley': 'Combination of all four strokes in sequence',
    'Mixed': 'Various stroke types in one session',
  };

  /// Get the icon for a specific stroke type
  static IconData getStrokeIcon(String strokeType) {
    return _strokeIcons[strokeType] ?? Icons.pool;
  }

  /// Get the color for a specific stroke type
  static Color getStrokeColor(String strokeType) {
    return _strokeColors[strokeType] ?? const Color(0xFF4A90E2);
  }

  /// Get the description for a specific stroke type
  static String getStrokeDescription(String strokeType) {
    return _strokeDescriptions[strokeType] ?? 'Swimming stroke';
  }

  /// Get all available stroke types
  static List<String> getAllStrokes() {
    return _strokeIcons.keys.toList();
  }

  /// Get main competitive strokes (excluding Mixed and IM)
  static List<String> getCompetitiveStrokes() {
    return ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly'];
  }

  /// Check if a stroke type is valid
  static bool isValidStroke(String strokeType) {
    return _strokeIcons.containsKey(strokeType);
  }

  /// Get stroke efficiency rating based on time and distance
  static String getEfficiencyRating(double timeSeconds, double distanceMeters) {
    final pacePerMeter = timeSeconds / distanceMeters;
    
    if (pacePerMeter < 1.0) return 'Excellent';
    if (pacePerMeter < 1.5) return 'Good';
    if (pacePerMeter < 2.0) return 'Average';
    if (pacePerMeter < 2.5) return 'Below Average';
    return 'Needs Improvement';
  }

  /// Calculate pace per 100 meters
  static double calculatePacePer100m(double timeSeconds, double distanceMeters) {
    if (distanceMeters <= 0) return 0.0;
    return (timeSeconds / distanceMeters) * 100;
  }

  /// Format time in mm:ss.SSS format
  static String formatTime(double seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (minutes > 0) {
      return '${minutes}:${remainingSeconds.toStringAsFixed(2).padLeft(5, '0')}';
    } else {
      return '${remainingSeconds.toStringAsFixed(2)}s';
    }
  }

  /// Parse time string back to seconds
  static double parseTimeToSeconds(String timeString) {
    try {
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        final minutes = double.parse(parts[0]);
        final seconds = double.parse(parts[1]);
        return minutes * 60 + seconds;
      } else {
        return double.parse(timeString.replaceAll('s', ''));
      }
    } catch (e) {
      return 0.0;
    }
  }

  /// Get stroke technique tips
  static List<String> getStrokeTips(String strokeType) {
    final tips = {
      'Freestyle': [
        'Keep your head in a neutral position',
        'Rotate your body to reduce drag',
        'Use a high elbow catch',
        'Maintain a steady kick rhythm',
      ],
      'Backstroke': [
        'Keep your head still and eyes looking up',
        'Rotate your shoulders for maximum reach',
        'Use a straight arm recovery',
        'Maintain consistent kick tempo',
      ],
      'Breaststroke': [
        'Pull, breathe, kick, glide sequence',
        'Keep your head aligned with your spine',
        'Use a powerful whip kick',
        'Maximize your glide phase',
      ],
      'Butterfly': [
        'Use an undulating body motion',
        'Keep your arms synchronized',
        'Two kicks per arm cycle',
        'Time your breathing carefully',
      ],
    };
    
    return tips[strokeType] ?? ['Focus on technique and consistency'];
  }

  /// Calculate stroke rating based on performance metrics
  static int calculateStrokeRating(String strokeType, double timeSeconds, double distanceMeters) {
    final pacePer100m = calculatePacePer100m(timeSeconds, distanceMeters);
    
    // Different rating scales for different strokes (approximate competitive times)
    final Map<String, List<double>> strokeStandards = {
      'Freestyle': [60, 70, 80, 90, 100], // Times for 100m (Elite to Beginner)
      'Backstroke': [65, 75, 85, 95, 105],
      'Breaststroke': [70, 80, 90, 100, 110],
      'Butterfly': [65, 75, 85, 95, 105],
    };
    
    final standards = strokeStandards[strokeType] ?? [70, 80, 90, 100, 110];
    
    for (int i = 0; i < standards.length; i++) {
      if (pacePer100m <= standards[i]) {
        return 5 - i; // 5 stars for elite, 1 star for beginner
      }
    }
    
    return 1; // Minimum 1 star
  }

  /// Get recommended training focus based on stroke and performance
  static List<String> getTrainingRecommendations(String strokeType, double currentPace) {
    final baseRecommendations = {
      'Freestyle': [
        'Work on streamline position',
        'Practice bilateral breathing',
        'Focus on catch-up drills',
      ],
      'Backstroke': [
        'Practice straight arm backstroke drill',
        'Work on body rotation',
        'Focus on flip turn technique',
      ],
      'Breaststroke': [
        'Practice pull-buoy sets',
        'Work on timing drills',
        'Focus on kick technique',
      ],
      'Butterfly': [
        'Practice single-arm butterfly',
        'Work on dolphin kick sets',
        'Focus on body undulation',
      ],
    };
    
    List<String> recommendations = baseRecommendations[strokeType] ?? 
        ['Focus on general technique improvement'];
    
    // Add pace-specific recommendations
    if (currentPace > 90) {
      recommendations.add('Focus on building endurance with longer sets');
    } else if (currentPace > 70) {
      recommendations.add('Work on speed development with sprint sets');
    } else {
      recommendations.add('Maintain technique while increasing race pace');
    }
    
    return recommendations;
  }
}