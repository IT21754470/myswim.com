// lib/services/recommendations_service.dart
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/training_session.dart';
import '../services/training_session_service.dart';
import 'api_service.dart';

class RecommendationsService {
  bool _isOfflineMode = true;
  String _lastError = '';

  bool get isOfflineMode => _isOfflineMode;
  String get lastError => _lastError;

  Future<List<SwimmingRecommendation>> getUserRecommendations() async {
    print('📋 Generating intelligent recommendations...');
    _lastError = '';
    
    try {
      final sessions = await TrainingSessionService.getUserTrainingSessions();
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        print('👤 No user logged in');
        return _getGuestRecommendations();
      }

      if (sessions.isEmpty) {
        print('🆕 No sessions found - new user setup');
        return _getNewUserRecommendations();
      }

      print('📊 Analyzing ${sessions.length} sessions...');
      
      // Try API first with user's actual data
      final apiRecommendations = await _tryGetApiRecommendations(sessions, user.uid);
      if (apiRecommendations != null && apiRecommendations.isNotEmpty) {
        print('✅ Using AI-powered recommendations');
        _isOfflineMode = false;
        return apiRecommendations;
      }

      // Generate smart local recommendations based on user data
      print('🧠 Generating smart local recommendations');
      _isOfflineMode = true;
      return _generateIntelligentRecommendations(sessions);
      
    } catch (e) {
      print('❌ Error: $e');
      _isOfflineMode = true;
      _lastError = e.toString();
      return _getEmergencyRecommendations();
    }
  }

 Map<String, dynamic> _analyzeUserData(List<TrainingSession> sessions) {
  final now = DateTime.now();
  final last30Days = sessions.where((s) => 
      now.difference(s.date).inDays <= 30).toList();
  final last7Days = sessions.where((s) => 
      now.difference(s.date).inDays <= 7).toList();
  
  // Analyze stroke distribution
  final strokeCounts = <String, int>{};
  final strokeDistances = <String, double>{};
  final sessionDurations = <double>[];
  final paceTimes = <String, List<double>>{};
  
  print('🔍 Analyzing ${last30Days.length} sessions from last 30 days');
  
  for (final session in last30Days) {
    // Count stroke occurrences
    strokeCounts[session.strokeType] = (strokeCounts[session.strokeType] ?? 0) + 1;
    
    // Sum distances by stroke type
    strokeDistances[session.strokeType] = 
        (strokeDistances[session.strokeType] ?? 0) + session.trainingDistance;
    
    // ✅ FIX: Convert session duration to minutes if it's in hours
    double durationInMinutes = session.sessionDuration;
    if (session.sessionDuration < 10) {
      // Likely in hours, convert to minutes
      durationInMinutes = session.sessionDuration * 60;
    }
    sessionDurations.add(durationInMinutes);
    
    // Collect pace data for performance analysis
    paceTimes.putIfAbsent(session.strokeType, () => []).add(session.pacePer100m);
    
    print('📈 Session: ${session.strokeType}, Distance: ${session.trainingDistance}m, Duration: ${durationInMinutes.toStringAsFixed(1)}min, Pace: ${session.pacePer100m}s/100m');
  }
  
  // Find primary and secondary strokes
  final sortedStrokes = strokeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  // Calculate training frequency
  final weeklyFrequency = last7Days.length;
  final monthlyFrequency = last30Days.length;
  
  // Determine fatigue level based on frequency and intensity
  String fatigueLevel = 'MEDIUM';
  final recentIntenseSessions = last7Days.where((s) {
    double duration = s.sessionDuration < 10 ? s.sessionDuration * 60 : s.sessionDuration;
    return duration > 45 || s.trainingDistance > 1000;
  }).length;
  
  if (weeklyFrequency > 5 || recentIntenseSessions > 3) {
    fatigueLevel = 'HIGH';
  } else if (weeklyFrequency < 2) {
    fatigueLevel = 'LOW';
  }
  
  // Calculate averages
  final avgDuration = sessionDurations.isEmpty ? 30.0 : 
      sessionDurations.reduce((a, b) => a + b) / sessionDurations.length;
  
  final avgDistance = last30Days.isEmpty ? 500.0 :
      last30Days.map((s) => s.trainingDistance).reduce((a, b) => a + b) / last30Days.length;
  
  // Analyze performance trends
  final performanceTrend = _analyzePerformanceTrend(last30Days);
  
  // Determine improvement potential
  double improvementPotential = 0.3;
  if (monthlyFrequency > 15 && performanceTrend == 'improving') {
    improvementPotential = 0.5;
  } else if (monthlyFrequency < 5 || performanceTrend == 'declining') {
    improvementPotential = 0.2;
  } else if (performanceTrend == 'stable') {
    improvementPotential = 0.4;
  }
  
  // Find training gaps
  final allStrokes = ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly'];
  final missingStrokes = allStrokes
      .where((stroke) => !strokeCounts.containsKey(stroke))
      .toList();
  
  // Calculate days since last session
  final daysSinceLastSession = sessions.isEmpty ? 0 : 
      now.difference(sessions.first.date).inDays;
  
  // Analyze stroke balance
  final primaryStrokePercentage = sortedStrokes.isNotEmpty && monthlyFrequency > 0 ? 
      (strokeCounts[sortedStrokes.first.key]! / monthlyFrequency * 100) : 0.0;
  
  final analysis = {
    'primaryStroke': sortedStrokes.isNotEmpty ? sortedStrokes.first.key : 'Freestyle',
    'secondaryStroke': sortedStrokes.length > 1 ? sortedStrokes[1].key : null,
    'weeklyFrequency': weeklyFrequency,
    'monthlyFrequency': monthlyFrequency,
    'fatigueLevel': fatigueLevel,
    'avgDuration': avgDuration,
    'avgDistance': avgDistance,
    'improvementPotential': improvementPotential,
    'missingStrokes': missingStrokes,
    'daysSinceLastSession': daysSinceLastSession,
    'totalDistance': strokeDistances.values.fold(0.0, (a, b) => a + b),
    'strokeVariety': strokeCounts.length,
    'strokeCounts': strokeCounts,
    'strokeDistances': strokeDistances,
    'performanceTrend': performanceTrend,
    'primaryStrokePercentage': primaryStrokePercentage,
    'paceTimes': paceTimes,
    'recentIntenseSessions': recentIntenseSessions,
  };
  
  print('📊 Analysis Summary:');
  print('   Primary Stroke: ${analysis['primaryStroke']}');
  print('   Weekly Frequency: $weeklyFrequency sessions');
  print('   Monthly Frequency: $monthlyFrequency sessions');
  print('   Avg Duration: ${avgDuration.toStringAsFixed(1)} minutes');
  print('   Avg Distance: ${avgDistance.toStringAsFixed(0)}m');
  print('   Fatigue Level: $fatigueLevel');
  print('   Performance Trend: $performanceTrend');
  
  return analysis;
}

  String _analyzePerformanceTrend(List<TrainingSession> sessions) {
    if (sessions.length < 3) return 'insufficient_data';
    
    // Sort sessions by date
    final sortedSessions = [...sessions]..sort((a, b) => a.date.compareTo(b.date));
    
    // Calculate average pace for first half vs second half
    final midpoint = sortedSessions.length ~/ 2;
    final firstHalf = sortedSessions.take(midpoint);
    final secondHalf = sortedSessions.skip(midpoint);
    
    final firstHalfAvgPace = firstHalf.isEmpty ? 0.0 :
        firstHalf.map((s) => s.pacePer100m).reduce((a, b) => a + b) / firstHalf.length;
    
    final secondHalfAvgPace = secondHalf.isEmpty ? 0.0 :
        secondHalf.map((s) => s.pacePer100m).reduce((a, b) => a + b) / secondHalf.length;
    
    final improvement = firstHalfAvgPace - secondHalfAvgPace;
    
    if (improvement > 2.0) return 'improving';
    if (improvement < -2.0) return 'declining';
    return 'stable';
  }

  Future<List<SwimmingRecommendation>?> _tryGetApiRecommendations(
    List<TrainingSession> sessions, String userId) async {
  
  try {
    // Check API health first
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      print('⚠️  API is not healthy, skipping API call');
      return null;
    }
    
    final analysis = _analyzeUserData(sessions);
    
    // Get API recommendation for their most practiced stroke
    if (analysis['primaryStroke'] != null) {
      final apiResponse = await ApiService.getPrediction(
        swimmerId: userId,
        strokeType: _normalizeStrokeType(analysis['primaryStroke']),
        predictedImprovement: analysis['improvementPotential'],
        fatigueLevel: analysis['fatigueLevel'],
      );
      
      if (apiResponse != null && apiResponse.isNotEmpty) {
        final recommendations = <SwimmingRecommendation>[];
        
        // Add AI recommendation
        final apiRec = _convertApiToRecommendation(apiResponse, analysis);
        recommendations.add(apiRec);
        
        // Add smart local recommendations based on gaps
        recommendations.addAll(_generateComplementaryRecommendations(analysis));
        
        print('✅ Generated ${recommendations.length} recommendations (including API)');
        return recommendations;
      }
    }
    
    print('⚠️  No valid API response');
    return null;
  } catch (e) {
    print('🔄 API call failed: $e');
    _lastError = 'API unavailable: ${e.toString()}';
    return null;
  }
}

  List<SwimmingRecommendation> _generateIntelligentRecommendations(
      List<TrainingSession> sessions) {
    
    final analysis = _analyzeUserData(sessions);
    final recommendations = <SwimmingRecommendation>[];
    
    // 1. Primary stroke improvement based on performance trend
    if (analysis['primaryStroke'] != null) {
      recommendations.add(_createDataDrivenStrokeRecommendation(analysis));
    }
    
    // 2. Address training gaps
    if ((analysis['missingStrokes'] as List).isNotEmpty) {
      recommendations.add(_createStrokeDiversityRecommendation(analysis));
    }
    
    // 3. Performance-based recommendations
    switch (analysis['performanceTrend']) {
      case 'improving':
        recommendations.add(_createProgressMaintenanceRecommendation(analysis));
        break;
      case 'declining':
        recommendations.add(_createPerformanceBoostRecommendation(analysis));
        break;
      case 'stable':
        recommendations.add(_createBreakthroughRecommendation(analysis));
        break;
    }
    
    // 4. Frequency-based recommendations
    if (analysis['weeklyFrequency'] < 3) {
      recommendations.add(_createFrequencyBoostRecommendation(analysis));
    } else if (analysis['weeklyFrequency'] > 5) {
      recommendations.add(_createRecoveryRecommendation(analysis));
    }
    
    // 5. Distance and duration optimization
    if (analysis['avgDistance'] < 500) {
      recommendations.add(_createEnduranceBuildingRecommendation(analysis));
    } else if (analysis['avgDistance'] > 2000) {
      recommendations.add(_createEfficiencyRecommendation(analysis));
    }
    
    // 6. Motivation recommendation if gap detected
    if (analysis['daysSinceLastSession'] > 3) {
      recommendations.add(_createMotivationRecommendation(analysis));
    }
    
    // 7. Stroke balance recommendation
    if (analysis['primaryStrokePercentage'] > 70) {
      recommendations.add(_createBalanceRecommendation(analysis));
    }
    
    return recommendations.take(4).toList(); // Return top 4 recommendations
  }

  // Enhanced recommendation creators using real data
  SwimmingRecommendation _createDataDrivenStrokeRecommendation(
      Map<String, dynamic> analysis) {
    final stroke = analysis['primaryStroke'];
    final fatigueLevel = analysis['fatigueLevel'];
    final frequency = analysis['weeklyFrequency'];
    final strokeCount = (analysis['strokeCounts'] as Map<String, int>)[stroke] ?? 1;
    final avgDistance = analysis['avgDistance'];
    final trend = analysis['performanceTrend'];
    
    String focusArea = '';
    switch (trend) {
      case 'improving':
        focusArea = 'Keep the momentum with progressive challenges';
        break;
      case 'declining':
        focusArea = 'Focus on technique to reverse the decline';
        break;
      default:
        focusArea = 'Add variety to break through plateaus';
    }
    
    return SwimmingRecommendation(
      title: 'Master Your $stroke',
      description: 'You\'ve practiced $stroke $strokeCount times recently (${avgDistance.round()}m avg). $focusArea.',
      type: 'Data-Driven',
      strokeType: stroke,
      priority: 'High',
      duration: '${_getOptimalDuration(analysis)} minutes',
      difficulty: _getDifficultyFromFrequency(frequency),
      instructions: _getStrokeSpecificInstructions(stroke, fatigueLevel, trend),
      fatigueLevel: fatigueLevel,
      confidence: 92,
    );
  }

  SwimmingRecommendation _createProgressMaintenanceRecommendation(
      Map<String, dynamic> analysis) {
    return SwimmingRecommendation(
      title: 'Maintain Your Progress',
      description: 'Your performance is improving! Let\'s keep this positive trend going.',
      type: 'Progress',
      priority: 'High',
      duration: '${analysis['avgDuration'].round() + 5} minutes',
      difficulty: 'Intermediate',
      instructions: [
        'Continue your current training pattern',
        'Gradually increase intensity by 5%',
        'Add one challenging set per session',
        'Track your progress closely'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 90,
    );
  }

  SwimmingRecommendation _createPerformanceBoostRecommendation(
      Map<String, dynamic> analysis) {
    return SwimmingRecommendation(
      title: 'Boost Your Performance',
      description: 'Let\'s reverse the recent decline and get you back on track.',
      type: 'Recovery',
      priority: 'High',
      duration: '${analysis['avgDuration'].round()} minutes',
      difficulty: 'Easy',
      instructions: [
        'Focus on technique over speed',
        'Reduce intensity for 2 weeks',
        'Emphasize proper form and breathing',
        'Get adequate rest between sessions'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 88,
    );
  }

  SwimmingRecommendation _createBreakthroughRecommendation(
      Map<String, dynamic> analysis) {
    return SwimmingRecommendation(
      title: 'Break Through Plateaus',
      description: 'Your performance is stable. Time for new challenges to spark improvement.',
      type: 'Challenge',
      priority: 'Medium',
      duration: '${analysis['avgDuration'].round() + 10} minutes',
      difficulty: 'Advanced',
      instructions: [
        'Try new training sets and intervals',
        'Cross-train with different strokes',
        'Add sprint intervals to build power',
        'Challenge yourself with longer distances'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 85,
    );
  }

  SwimmingRecommendation _createBalanceRecommendation(
      Map<String, dynamic> analysis) {
    final primaryStroke = analysis['primaryStroke'];
    final percentage = analysis['primaryStrokePercentage'].round();
    
    return SwimmingRecommendation(
      title: 'Balance Your Training',
      description: '$primaryStroke makes up $percentage% of your training. Let\'s add variety for complete development.',
      type: 'Balance',
      priority: 'Medium',
      duration: '40 minutes',
      difficulty: 'Intermediate',
      instructions: [
        'Dedicate 25% of session to other strokes',
        'Try individual medley sets',
        'Focus on weakest stroke development',
        'Maintain strength in $primaryStroke'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 87,
    );
  }

  // Enhanced stroke-specific instructions with performance trend
  List<String> _getStrokeSpecificInstructions(String stroke, String fatigueLevel, String trend) {
    final baseInstructions = {
      'Freestyle': [
        'Focus on high elbow catch',
        'Practice bilateral breathing',
        'Work on body rotation',
        'Maintain steady kick'
      ],
      'Backstroke': [
        'Keep head still and looking up',
        'Focus on opposite arm timing',
        'Work on consistent kick',
        'Practice proper hand entry'
      ],
      'Breaststroke': [
        'Focus on timing: pull, breathe, kick, glide',
        'Work on undulating body motion',
        'Practice efficient kick',
        'Minimize drag during glide'
      ],
      'Butterfly': [
        'Focus on undulating body motion',
        'Work on two-beat kick timing',
        'Practice efficient arm recovery',
        'Breathe every 2-3 strokes'
      ],
    };
    
    final instructions = baseInstructions[stroke] ?? baseInstructions['Freestyle']!;
    
    List<String> trendInstructions = [];
    switch (trend) {
      case 'improving':
        trendInstructions = ['Build on recent improvements', 'Gradually increase challenge'];
        break;
      case 'declining':
        trendInstructions = ['Return to basics', 'Focus on form over speed'];
        break;
      default:
        trendInstructions = ['Add new challenges', 'Break routine patterns'];
    }
    
    if (fatigueLevel == 'HIGH') {
      return ['Easy warm-up'] + instructions + ['Focus on relaxation'] + trendInstructions;
    }
    
    return ['Proper warm-up'] + instructions + trendInstructions + ['Cool down thoroughly'];
  }

  // Keep all your existing helper methods...
  int _getOptimalDuration(Map<String, dynamic> analysis) {
    final avg = analysis['avgDuration'] as double;
    final fatigue = analysis['fatigueLevel'] as String;
    
    if (fatigue == 'HIGH') return (avg * 0.8).round();
    if (fatigue == 'LOW') return (avg * 1.2).round();
    return avg.round();
  }

  String _getDifficultyFromFrequency(int frequency) {
    if (frequency <= 1) return 'Beginner';
    if (frequency <= 3) return 'Intermediate';
    return 'Advanced';
  }

  String _normalizeStrokeType(String stroke) {
    switch (stroke.toLowerCase()) {
      case 'freestyle':
        return 'free';
      case 'backstroke':
        return 'back';
      case 'breaststroke':
        return 'breast';
      case 'butterfly':
        return 'fly';
      default:
        return 'free';
    }
  }

  String _formatStrokeType(String stroke) {
    switch (stroke.toLowerCase()) {
      case 'free':
        return 'Freestyle';
      case 'back':
        return 'Backstroke';
      case 'breast':
        return 'Breaststroke';
      case 'fly':
        return 'Butterfly';
      default:
        return stroke;
    }
  }

  SwimmingRecommendation _convertApiToRecommendation(
      Map<String, dynamic> apiData, Map<String, dynamic> analysis) {
    final strokeType = apiData['stroke_type'] ?? 'freestyle';
    final fatigueLevel = apiData['fatigue_level'] ?? 'MEDIUM';
    final confidence = ((apiData['confidence'] ?? 0.5) * 100).round();
    final fullRecommendation = apiData['full_recommendation'] ?? '';
    
    return SwimmingRecommendation(
      title: '${_formatStrokeType(strokeType)} - AI Optimized',
      description: 'AI recommendation based on your ${analysis['monthlyFrequency']} sessions this month and ${analysis['primaryStroke']} focus.',
      type: 'AI-Powered',
      strokeType: strokeType,
      priority: fatigueLevel == 'HIGH' ? 'Low' : 'High',
      duration: '${_getOptimalDuration(analysis)} minutes',
      difficulty: _getDifficultyFromFrequency(analysis['weeklyFrequency']),
      instructions: _parseInstructions(fullRecommendation),
      fatigueLevel: fatigueLevel,
      confidence: confidence,
    );
  }

  List<SwimmingRecommendation> _generateComplementaryRecommendations(
      Map<String, dynamic> analysis) {
    
    final recommendations = <SwimmingRecommendation>[];
    
    if (analysis['strokeVariety'] < 3) {
      recommendations.add(_createStrokeDiversityRecommendation(analysis));
    }
    
    if (analysis['fatigueLevel'] == 'HIGH') {
      recommendations.add(_createRecoveryRecommendation(analysis));
    } else {
      recommendations.add(_createTechniqueRefinementRecommendation(analysis));
    }
    
    return recommendations.take(2).toList();
  }

  List<String> _parseInstructions(String recommendation) {
    if (recommendation.isEmpty) {
      return [
        'Warm up with 200m easy swimming',
        'Focus on technique and form',
        'Maintain steady pace throughout',
        'Cool down with easy swimming'
      ];
    }
    
    final instructions = <String>['Warm up with 200m easy swimming'];
    final cleanRec = recommendation.replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = cleanRec.split(RegExp(r'[.!]\s*'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim())
        .toList();
    
    for (final part in parts) {
      if (part.isNotEmpty && part.length > 3) {
        instructions.add(part);
      }
    }
    
    instructions.add('Cool down with easy swimming');
    return instructions;
  }

  // Keep all your other existing methods (getNewUserRecommendations, getGuestRecommendations, etc.)
  // I'll add the missing ones that are referenced:

  SwimmingRecommendation _createStrokeDiversityRecommendation(
      Map<String, dynamic> analysis) {
    final missingStrokes = analysis['missingStrokes'] as List<String>;
    final targetStroke = missingStrokes.isNotEmpty ? missingStrokes.first : 'Backstroke';
    
    return SwimmingRecommendation(
      title: 'Try $targetStroke',
      description: 'Add variety to your training with $targetStroke technique.',
      type: 'Skill-Building',
      strokeType: targetStroke,
      priority: 'Medium',
      duration: '35 minutes',
      difficulty: 'Beginner',
      instructions: [
        'Start with basic $targetStroke technique',
        'Practice 4 x 25m with plenty of rest',
        'Focus on body position and timing',
        'Don\'t worry about speed yet'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 85,
    );
  }

  SwimmingRecommendation _createFrequencyBoostRecommendation(
      Map<String, dynamic> analysis) {
    final currentFreq = analysis['weeklyFrequency'];
    
    return SwimmingRecommendation(
      title: 'Boost Training Frequency',
      description: 'You\'re swimming $currentFreq times per week. Let\'s add one more session.',
      type: 'Consistency',
      priority: 'High',
      duration: '30 minutes',
      difficulty: 'Easy',
      instructions: [
        'Add one short, easy session this week',
        'Focus on enjoying the water',
        'Keep it light and fun',
        'Gradually build the habit'
      ],
      fatigueLevel: 'LOW',
      confidence: 88,
    );
  }

  SwimmingRecommendation _createRecoveryRecommendation(
      Map<String, dynamic> analysis) {
    return SwimmingRecommendation(
      title: 'Active Recovery',
      description: 'You\'ve been training hard! Time for a gentle recovery swim.',
      type: 'Recovery',
      priority: 'High',
      duration: '25 minutes',
      difficulty: 'Easy',
      instructions: [
        'Very easy pace throughout',
        'Focus on relaxation and flow',
        'Include gentle stretching',
        'Listen to your body'
      ],
      fatigueLevel: 'HIGH',
      confidence: 95,
    );
  }

  SwimmingRecommendation _createEnduranceBuildingRecommendation(
      Map<String, dynamic> analysis) {
    final avgDistance = analysis['avgDistance'].round();
    
    return SwimmingRecommendation(
      title: 'Build Endurance',
      description: 'Your average distance is ${avgDistance}m. Let\'s increase stamina.',
      type: 'Endurance',
      priority: 'Medium',
      duration: '${analysis['avgDuration'].round() + 10} minutes',
      difficulty: 'Intermediate',
      instructions: [
        'Warm up for 5 minutes',
        'Gradually increase distance by 10%',
        'Focus on consistent pace',
        'Cool down with easy swimming'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 80,
    );
  }

  SwimmingRecommendation _createEfficiencyRecommendation(
      Map<String, dynamic> analysis) {
    return SwimmingRecommendation(
      title: 'Swim Efficiently',
      description: 'Focus on quality over quantity in your training.',
      type: 'Efficiency',
      priority: 'Medium',
      duration: '35 minutes',
      difficulty: 'Intermediate',
      instructions: [
        'Shorter, more intense intervals',
        'Focus on technique during rest',
        'Quality over quantity mindset',
        'Track your stroke count'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 83,
    );
  }

  SwimmingRecommendation _createMotivationRecommendation(
      Map<String, dynamic> analysis) {
    final daysSince = analysis['daysSinceLastSession'];
    
    return SwimmingRecommendation(
      title: 'Welcome Back!',
      description: 'It\'s been $daysSince days. Let\'s ease back in.',
      type: 'Motivation',
      priority: 'High',
      duration: '25 minutes',
      difficulty: 'Easy',
      instructions: [
        'Start with gentle warm-up',
        'Swim your favorite stroke',
        'Focus on feeling good in the water',
        'Remember why you love swimming'
      ],
      fatigueLevel: 'LOW',
      confidence: 95,
    );
  }

  SwimmingRecommendation _createTechniqueRefinementRecommendation(
      Map<String, dynamic> analysis) {
    return SwimmingRecommendation(
      title: 'Perfect Your Technique',
      description: 'Polish your technique for better efficiency.',
      type: 'Technique',
      priority: 'High',
      duration: '45 minutes',
      difficulty: 'Advanced',
      instructions: [
        'Video yourself swimming if possible',
        'Practice drill sets for each stroke',
        'Focus on distance per stroke',
        'Work on timing and rhythm'
      ],
      fatigueLevel: analysis['fatigueLevel'],
      confidence: 90,
    );
  }

  List<SwimmingRecommendation> _getNewUserRecommendations() {
    return [
      SwimmingRecommendation(
        title: 'Welcome to Swimming!',
        description: 'Let\'s start your swimming journey with the basics.',
        type: 'Getting Started',
        priority: 'High',
        duration: '30 minutes',
        difficulty: 'Beginner',
        instructions: [
          'Get comfortable in the water',
          'Practice floating and breathing',
          'Learn basic freestyle movements',
          'Focus on relaxation and fun'
        ],
        fatigueLevel: 'LOW',
        confidence: 95,
      ),
    ];
  }

  List<SwimmingRecommendation> _getGuestRecommendations() {
    return [
      SwimmingRecommendation(
        title: 'General Swim Workout',
        description: 'A balanced session suitable for most swimmers.',
        type: 'General',
        priority: 'Medium',
        duration: '40 minutes',
        difficulty: 'Intermediate',
        instructions: [
          'Warm up with easy swimming',
          'Practice your preferred stroke',
          'Include some variety if comfortable',
          'Cool down and stretch'
        ],
        fatigueLevel: 'MEDIUM',
        confidence: 75,
      ),
    ];
  }

  List<SwimmingRecommendation> _getEmergencyRecommendations() {
    return [
      SwimmingRecommendation(
        title: 'Safe Swimming Session',
        description: 'A simple, safe workout when systems are unavailable.',
        type: 'Backup',
        priority: 'Medium',
        duration: '30 minutes',
        difficulty: 'Easy',
        instructions: [
          'Warm up gently',
          'Swim at comfortable pace',
          'Listen to your body',
          'Stay hydrated'
        ],
        fatigueLevel: 'MEDIUM',
        confidence: 70,
      ),
    ];
  }
}

class SwimmingRecommendation {
  final String title;
  final String description;
  final String type;
  final String? strokeType;
  final String priority;
  final String duration;
  final String difficulty;
  final List<String> instructions;
  final String fatigueLevel;
  final int confidence;

  SwimmingRecommendation({
    required this.title,
    required this.description,
    required this.type,
    this.strokeType,
    required this.priority,
    required this.duration,
    required this.difficulty,
    required this.instructions,
    required this.fatigueLevel,
    required this.confidence,
  });
}