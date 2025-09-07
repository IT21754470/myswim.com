import 'package:flutter/material.dart';

class RecommendationsUtils {
  // Get icon for recommendation type
  static IconData getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'stroke':
        return Icons.pool;
      case 'technique':
        return Icons.auto_fix_high;
      case 'fitness':
        return Icons.fitness_center;
      case 'recovery':
        return Icons.spa;
      case 'nutrition':
        return Icons.restaurant;
      default:
        return Icons.star;
    }
  }

  // Get color for recommendation priority
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Get color for difficulty level
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  // Get color for fatigue level
  static Color getFatigueColor(String fatigueLevel) {
    switch (fatigueLevel.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Get icon for swimming stroke
  static IconData getStrokeIcon(String? strokeType) {
    if (strokeType == null) return Icons.pool;
    
    switch (strokeType.toLowerCase()) {
      case 'freestyle':
      case 'free':
        return Icons.directions_run;
      case 'backstroke':
      case 'back':
        return Icons.swap_calls;
      case 'breaststroke':
      case 'breast':
        return Icons.waves;
      case 'butterfly':
      case 'fly':
        return Icons.flight;
      default:
        return Icons.pool;
    }
  }

  // Format stroke type for display
  static String formatStrokeType(String strokeType) {
    switch (strokeType.toLowerCase()) {
      case 'free':
        return 'Freestyle';
      case 'back':
        return 'Backstroke';
      case 'breast':
        return 'Breaststroke';
      case 'fly':
        return 'Butterfly';
      default:
        return strokeType.substring(0, 1).toUpperCase() + strokeType.substring(1).toLowerCase();
    }
  }

  // Get priority text with proper formatting
  static String formatPriority(String priority) {
    return priority.substring(0, 1).toUpperCase() + priority.substring(1).toLowerCase();
  }

  // Get difficulty text with proper formatting
  static String formatDifficulty(String difficulty) {
    return difficulty.substring(0, 1).toUpperCase() + difficulty.substring(1).toLowerCase();
  }

  // Get recommendation type display name
  static String formatRecommendationType(String type) {
    switch (type.toLowerCase()) {
      case 'stroke':
        return 'Stroke Training';
      case 'technique':
        return 'Technique Focus';
      case 'fitness':
        return 'Fitness Training';
      case 'recovery':
        return 'Recovery';
      case 'nutrition':
        return 'Nutrition';
      default:
        return type.substring(0, 1).toUpperCase() + type.substring(1).toLowerCase();
    }
  }

  // Get appropriate emoji for recommendation type
  static String getTypeEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'stroke':
        return '🏊‍♂️';
      case 'technique':
        return '⚡';
      case 'fitness':
        return '💪';
      case 'recovery':
        return '🧘‍♂️';
      case 'nutrition':
        return '🥗';
      default:
        return '⭐';
    }
  }

  // Get fatigue level description
  static String getFatigueDescription(String fatigueLevel) {
    switch (fatigueLevel.toUpperCase()) {
      case 'HIGH':
        return 'Your body needs recovery. Focus on light training and rest.';
      case 'MEDIUM':
        return 'Balanced training load. You can handle moderate intensity.';
      case 'LOW':
        return 'Fresh and ready! Time for challenging workouts.';
      default:
        return 'Training status unknown. Listen to your body.';
    }
  }

  // Get confidence level text
  static String getConfidenceLevel(double confidence) {
    if (confidence >= 0.8) return 'Very High';
    if (confidence >= 0.6) return 'High';
    if (confidence >= 0.4) return 'Medium';
    if (confidence >= 0.2) return 'Low';
    return 'Very Low';
  }

  // Get confidence color
  static Color getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.lightGreen;
    if (confidence >= 0.4) return Colors.orange;
    if (confidence >= 0.2) return Colors.deepOrange;
    return Colors.red;
  }

  // Format duration for display
  static String formatDuration(String duration) {
    // Clean up duration text
    return duration.replaceAll('minutes', 'min').replaceAll('minute', 'min');
  }

  // Get gradient colors for cards based on type
  static List<Color> getTypeGradient(String type) {
    switch (type.toLowerCase()) {
      case 'stroke':
        return [const Color(0xFF4A90E2), const Color(0xFF357ABD)];
      case 'technique':
        return [const Color(0xFF9B59B6), const Color(0xFF8E44AD)];
      case 'fitness':
        return [const Color(0xFFE74C3C), const Color(0xFFC0392B)];
      case 'recovery':
        return [const Color(0xFF2ECC71), const Color(0xFF27AE60)];
      case 'nutrition':
        return [const Color(0xFFF39C12), const Color(0xFFE67E22)];
      default:
        return [const Color(0xFF34495E), const Color(0xFF2C3E50)];
    }
  }

  // Sort recommendations by priority and type
  static List<T> sortRecommendations<T>(List<T> recommendations, T Function(T) getRecommendation) {
    recommendations.sort((a, b) {
      final recA = getRecommendation(a);
      final recB = getRecommendation(b);
      
      // Priority comparison
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final priorityA = priorityOrder[(recA as dynamic).priority.toString().split('.').last] ?? 3;
      final priorityB = priorityOrder[(recB as dynamic).priority.toString().split('.').last] ?? 3;
      
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      
      // Type comparison (stroke first, then technique, etc.)
      final typeOrder = {'stroke': 0, 'technique': 1, 'fitness': 2, 'recovery': 3, 'nutrition': 4};
      final typeA = typeOrder[(recA as dynamic).type.toString().split('.').last] ?? 5;
      final typeB = typeOrder[(recB as dynamic).type.toString().split('.').last] ?? 5;
      
      return typeA.compareTo(typeB);
    });
    
    return recommendations;
  }

  // Filter recommendations by criteria
  static List<T> filterRecommendations<T>(
    List<T> recommendations,
    T Function(T) getRecommendation, {
    String? type,
    String? difficulty,
    String? priority,
    String? strokeType,
  }) {
    return recommendations.where((item) {
      final rec = getRecommendation(item);
      
      if (type != null && (rec as dynamic).type.toString().split('.').last != type) {
        return false;
      }
      if (difficulty != null && (rec as dynamic).difficulty.toString().split('.').last != difficulty) {
        return false;
      }
      if (priority != null && (rec as dynamic).priority.toString().split('.').last != priority) {
        return false;
      }
      if (strokeType != null && (rec as dynamic).strokeType != strokeType) {
        return false;
      }
      
      return true;
    }).toList();
  }

  // Get summary statistics
  static Map<String, dynamic> getRecommendationStats(List<dynamic> recommendations) {
    final stats = <String, dynamic>{
      'total': recommendations.length,
      'byType': <String, int>{},
      'byPriority': <String, int>{},
      'byDifficulty': <String, int>{},
      'averageConfidence': 0.0,
    };
    
    double totalConfidence = 0;
    
    for (final rec in recommendations) {
      // Count by type
      final type = (rec as dynamic).type.toString().split('.').last;
      stats['byType'][type] = (stats['byType'][type] ?? 0) + 1;
      
      // Count by priority
      final priority = (rec as dynamic).priority.toString().split('.').last;
      stats['byPriority'][priority] = (stats['byPriority'][priority] ?? 0) + 1;
      
      // Count by difficulty
      final difficulty = (rec as dynamic).difficulty.toString().split('.').last;
      stats['byDifficulty'][difficulty] = (stats['byDifficulty'][difficulty] ?? 0) + 1;
      
      // Sum confidence
      totalConfidence += (rec as dynamic).confidence ?? 0.0;
    }
    
    if (recommendations.isNotEmpty) {
      stats['averageConfidence'] = totalConfidence / recommendations.length;
    }
    
    return stats;
  }

  // Generate weekly schedule from recommendations
  static List<Map<String, dynamic>> generateWeeklySchedule(List<dynamic> recommendations) {
    final schedule = <Map<String, dynamic>>[];
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Distribute recommendations across the week
    final highPriority = recommendations.where((r) => 
        (r as dynamic).priority.toString().split('.').last == 'high').toList();
    final mediumPriority = recommendations.where((r) => 
        (r as dynamic).priority.toString().split('.').last == 'medium').toList();
    final lowPriority = recommendations.where((r) => 
        (r as dynamic).priority.toString().split('.').last == 'low').toList();
    
    int dayIndex = 0;
    
    // Add high priority items first
    for (final rec in highPriority) {
      if (dayIndex < days.length) {
        schedule.add({
          'day': days[dayIndex],
          'recommendation': rec,
          'priority': 'high',
        });
        dayIndex += 2; // Skip a day for recovery
      }
    }
    
    // Fill in with medium priority
    dayIndex = 1; // Start with Tuesday
    for (final rec in mediumPriority) {
      while (dayIndex < days.length) {
        final dayTaken = schedule.any((s) => s['day'] == days[dayIndex]);
        if (!dayTaken) {
          schedule.add({
            'day': days[dayIndex],
            'recommendation': rec,
            'priority': 'medium',
          });
          break;
        }
        dayIndex++;
      }
      dayIndex++;
    }
    
    return schedule;
  }
}