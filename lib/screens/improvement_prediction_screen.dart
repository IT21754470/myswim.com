import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/training_session.dart';
import '../services/improvement_prediction_service.dart';
import '../services/training_session_service.dart';
import '../widgets/enhanced_daily_prediction_card.dart';
import '../widgets/mini_chart_painter.dart';
import '../utils/stroke_utils.dart';

class ImprovementPredictionScreen extends StatefulWidget {
  const ImprovementPredictionScreen({super.key});

  @override
  State<ImprovementPredictionScreen> createState() => _ImprovementPredictionScreenState();
}

class _ImprovementPredictionScreenState extends State<ImprovementPredictionScreen> 
    with SingleTickerProviderStateMixin {
  
  bool _isLoading = false;
  bool _isConnectionTesting = false;
  bool _backendConnected = false;
  PredictionResponse? _predictionResponse;
  List<TrainingSession> _trainingHistory = [];
  int _daysToPredict = 7;
  String? _errorMessage;
  
  late TabController _tabController;
  final ImprovementPredictionService _predictionService = ImprovementPredictionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _predictionService.initialize();
    _testBackendConnection();
    _loadTrainingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🏥 Test backend connection
  Future<void> _testBackendConnection() async {
    setState(() {
      _isConnectionTesting = true;
    });

    try {
      final isConnected = await _predictionService.testBackendConnection();
      setState(() {
        _backendConnected = isConnected;
        _isConnectionTesting = false;
      });
      
      print('🏥 Backend connection: ${isConnected ? 'SUCCESS' : 'FAILED'}');
    } catch (e) {
      setState(() {
        _backendConnected = false;
        _isConnectionTesting = false;
      });
      print('❌ Connection test error: $e');
    }
  }

  Future<void> _loadTrainingData() async {
    print('🔄 Loading training data...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await TrainingSessionService.getUserTrainingSessions();
      final userProfile = await TrainingSessionService.getUserProfile();
      
      // ✅ Validate and fix unrealistic training data
      final formattedSessions = sessions.map((session) {
        return TrainingSession(
          swimmerId: 1,
          poolLength: session.poolLength,
          date: session.date,
          strokeType: session.strokeType,
          trainingDistance: session.trainingDistance,
          sessionDuration: session.sessionDuration,
          pacePer100m: _validatePace(session.pacePer100m, session.trainingDistance, session.actualTime),
          laps: session.laps,
          avgHeartRate: session.avgHeartRate,
          restInterval: session.restInterval,
          baseTime: session.baseTime,
          actualTime: _validateActualTime(session.actualTime, session.trainingDistance),
          gender: userProfile?['gender'] ?? 'Male',
          intensity: session.intensity ?? _estimateIntensity(session),
        );
      }).toList();

      print('📊 Loaded ${formattedSessions.length} training sessions');

      setState(() {
        _trainingHistory = formattedSessions;
      });

      // ✅ Only get predictions if user has training data
      if (_trainingHistory.isNotEmpty) {
        await _getPrediction();
      } else {
        setState(() {
          _predictionResponse = null;
          _errorMessage = null;
        });
      }
      
    } catch (e) {
      print('❌ Error loading training data: $e');
      setState(() {
        _trainingHistory = [];
        _predictionResponse = null;
        _errorMessage = 'Error loading training data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ Validate and fix unrealistic pace data
  double _validatePace(double pace, double distance, double actualTime) {
    // If pace is unrealistic (less than 30 seconds per 100m), recalculate
    if (pace < 30.0) {
      return (actualTime / distance) * 100;
    }
    return pace;
  }

  // ✅ Validate and fix unrealistic actual times
  double _validateActualTime(double actualTime, double distance) {
    // Minimum realistic pace: 30 seconds per 100m
    double minTime = (distance / 100) * 30;
    // Maximum realistic pace for beginners: 300 seconds per 100m
    double maxTime = (distance / 100) * 300;
    
    if (actualTime < minTime) {
      print('⚠️ Unrealistic actual time detected: ${actualTime}s. Adjusting to realistic value.');
      return minTime * (0.8 + (0.4 * (actualTime / minTime))); // Scale to realistic range
    }
    
    if (actualTime > maxTime) {
      return maxTime;
    }
    
    return actualTime;
  }

  // ✅ Estimate intensity from session data
  double _estimateIntensity(TrainingSession session) {
    if (session.avgHeartRate != null && session.avgHeartRate! > 0) {
      // Estimate based on heart rate (rough approximation)
      if (session.avgHeartRate! < 120) return 3.0;
      if (session.avgHeartRate! < 140) return 5.0;
      if (session.avgHeartRate! < 160) return 7.0;
      return 9.0;
    }
    
    // Estimate based on pace
    double pace = session.pacePer100m;
    if (pace < 60) return 9.0;  // Very fast
    if (pace < 90) return 7.0;  // Fast
    if (pace < 120) return 5.0; // Moderate
    if (pace < 150) return 3.0; // Easy
    return 2.0; // Very easy
  }

  Future<void> _getPrediction() async {
    print('🚀 Starting prediction request...');
    print('📊 Training history: ${_trainingHistory.length} sessions');
    print('📅 Days to predict: $_daysToPredict');
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _predictionResponse = null;
    });

    try {
      final response = await _predictionService.getPrediction(
        trainingHistory: _trainingHistory,
        daysToPredict: _daysToPredict,
      );

      print('✅ Got response: ${response.status}');
      print('🎯 Predictions available: ${response.futurePredictions?.byDate.length ?? 0} days');

      if (mounted) {
        setState(() {
          _predictionResponse = response;
          if (response.status != 'success') {
            _errorMessage = response.error ?? 'Prediction failed';
          }
        });
      }
    } catch (e) {
      print('❌ Prediction error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error getting prediction: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildEnhancedHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _trainingHistory.isEmpty
                    ? _buildNoDataState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildPredictionContent(),
          ),
        ],
      ),
    );
  }

  // ✅ Updated no data state without add session button
  Widget _buildNoDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pool_outlined,
              size: 80,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No Training Data Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A90E2),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'No training sessions are available for analysis. Please add some training data to see performance predictions.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // ✅ Only refresh button, no add session button
            ElevatedButton.icon(
              onPressed: _loadTrainingData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Fixed header with responsive layout
  Widget _buildEnhancedHeader() {
    final bool hasData = _trainingHistory.isNotEmpty;
    final bool isOnline = !_predictionService.isOfflineMode;
    
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A90E2),
            Color(0xFF357ABD),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header with better spacing
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Performance Prediction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // ✅ Network Status Indicator
              if (_isConnectionTesting)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _testBackendConnection,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isOnline && _backendConnected) 
                          ? Colors.green.withOpacity(0.2) 
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isOnline && _backendConnected) ? Colors.green : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (isOnline && _backendConnected) ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: (isOnline && _backendConnected) ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (isOnline && _backendConnected) ? 'AI' : 'Local',
                          style: TextStyle(
                            color: (isOnline && _backendConnected) ? Colors.green : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              IconButton(
                onPressed: () {
                  _testBackendConnection();
                  _loadTrainingData();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          
          // ✅ Only show period selector and stats if there's data
          if (hasData) ...[
            const SizedBox(height: 20),
            
            // Period selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildPeriodTab('7 Days', _daysToPredict == 7),
                  _buildPeriodTab('14 Days', _daysToPredict == 14),
                  _buildPeriodTab('30 Days', _daysToPredict == 30),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ✅ Fixed Quick stats with proper responsive layout
            if (_predictionResponse?.futurePredictions != null)
              _buildResponsiveQuickStats(),
          ],
        ],
      ),
    );
  }

  // ✅ Responsive quick stats that prevent overflow
 // ✅ Fixed responsive quick stats to prevent overflow
// ✅ COMPLETELY FIXED: Responsive quick stats with proper constraints
Widget _buildResponsiveQuickStats() {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Calculate available width per stat (4 stats total)
      double availableWidth = constraints.maxWidth;
      double statWidth = (availableWidth - 24) / 4; // 24 for spacing (3 gaps of 8px)
      
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: statWidth,
                child: _buildQuickStat('Peak', _getPeakDay(), Icons.star, Colors.amber),
              ),
              SizedBox(
                width: statWidth,
                child: _buildQuickStat('Potential', '+${_getAverageImprovement().toStringAsFixed(1)}s', Icons.rocket_launch, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: statWidth,
                child: _buildQuickStat('Intensity', '${_getAverageIntensity().toStringAsFixed(1)}/10', Icons.fitness_center, Colors.red),
              ),
              SizedBox(
                width: statWidth,
                child: _buildQuickStat('Confidence', '${(_predictionResponse!.futurePredictions!.modelAccuracy * 100).toInt()}%', Icons.psychology, Colors.purple),
              ),
            ],
          ),
        ],
      );
    },
  );
}

// ✅ FIXED: Constrained quick stat widget
Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 7,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}
  Widget _buildPeriodTab(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          int days = int.parse(text.split(' ')[0]);
          if (days != _daysToPredict) {
            setState(() {
              _daysToPredict = days;
            });
            _getPrediction();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF4A90E2) : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // (Removed duplicate _buildQuickStat function to resolve naming conflict)

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
          SizedBox(height: 16),
          Text('Analyzing your swimming data...'),
          SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Prediction Analysis',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getErrorMessage(),
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                _predictionService.forceOfflineMode();
                await _getPrediction();
              },
              icon: const Icon(Icons.offline_bolt),
              label: const Text('Use Offline Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _testBackendConnection();
                _loadTrainingData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionContent() {
    return Column(
      children: [
        // Tab Navigation
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4A90E2),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF4A90E2),
            tabs: const [
              Tab(text: 'Predictions'),
              Tab(text: 'Insights'),
              Tab(text: 'Recommendations'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPredictionsTab(),
              _buildInsightsTab(),
              _buildRecommendationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsTab() {
    if (_predictionResponse?.futurePredictions == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No predictions available yet'),
          ],
        ),
      );
    }

    final futurePredictions = _predictionResponse!.futurePredictions!;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Model Accuracy Card
        _buildModelAccuracyCard(futurePredictions.modelAccuracy),
        
        const SizedBox(height: 20),
        
        // Daily Predictions
        ...futurePredictions.byDate.entries.map((entry) => 
          _buildDailyPredictionCard(entry.key, entry.value)
        ).toList(),
      ],
    );
  }

  Widget _buildDailyPredictionCard(String date, List<DailyPrediction> predictions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, 
                     color: const Color(0xFF4A90E2), size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ],
            ),
          ),
          
          // Predictions List
          ...predictions.map((prediction) => _buildPredictionItem(prediction)).toList(),
        ],
      ),
    );
  }

  // ✅ Fixed prediction item layout
  Widget _buildPredictionItem(DailyPrediction prediction) {
    final improvementColor = prediction.improvement > 0 ? Colors.green : Colors.red;
    final intensityColor = _getIntensityColor(prediction.intensity ?? 5.0);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Stroke Icon
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStrokeIcon(prediction.strokeType),
              color: const Color(0xFF4A90E2),
              size: 20,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Stroke Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prediction.strokeType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${_formatTime(prediction.predictedTime)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (prediction.intensity != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.fitness_center, size: 12, color: intensityColor),
                      const SizedBox(width: 2),
                      Text(
                        '${prediction.intensity!.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: intensityColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Improvement
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: improvementColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${prediction.improvement > 0 ? '+' : ''}${prediction.improvement.toStringAsFixed(1)}s',
              style: TextStyle(
                color: improvementColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Format time properly for display
  String _formatTime(double timeInSeconds) {
    if (timeInSeconds < 60) {
      return '${timeInSeconds.toStringAsFixed(1)}s';
    } else {
      int minutes = (timeInSeconds / 60).floor();
      double seconds = timeInSeconds % 60;
      return '${minutes}:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
    }
  }

  Widget _buildModelAccuracyCard(double accuracy) {
    final percentage = (accuracy * 100).toStringAsFixed(1);
    final color = accuracy > 0.8 ? Colors.green : accuracy > 0.6 ? Colors.orange : Colors.red;
    final isOnline = !_predictionService.isOfflineMode;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_circle, color: color, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Prediction Accuracy',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on your training patterns',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      accuracy > 0.8 ? 'Excellent' : accuracy > 0.6 ? 'Good' : 'Fair',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          if (!isOnline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Using local analysis. Connect to internet for AI-powered predictions.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    if (_predictionResponse?.swimmerSummaries == null) {
      return const Center(
        child: Text('No insights available'),
      );
    }

    final summaries = _predictionResponse!.swimmerSummaries!;
    final modelInfo = _predictionResponse!.modelInfo;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...summaries.entries.map((entry) => 
          _buildSwimmerSummaryCard(entry.key, entry.value)
        ).toList(),
        
        const SizedBox(height: 16),
        
        if (modelInfo != null)
          _buildModelInfoCard(modelInfo),
      ],
    );
  }

  Widget _buildSwimmerSummaryCard(String swimmerId, SwimmerSummary summary) {
    final trendColor = summary.trend.contains('improving') ? Colors.green :
                       summary.trend.contains('declining') ? Colors.red : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF4A90E2)),
              const SizedBox(width: 8),
              const Text(
                'Performance Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildSummaryRow('Average Improvement', '${summary.averageImprovement.toStringAsFixed(2)}s per session', Colors.green),
          const SizedBox(height: 12),
          
          _buildSummaryRow('Total Predictions', '${summary.predictionCount} sessions', Colors.blue),
          const SizedBox(height: 12),
          
          if (summary.averageIntensity != null) ...[
            _buildSummaryRow('Average Intensity', '${summary.averageIntensity!.toStringAsFixed(1)}/10', _getIntensityColor(summary.averageIntensity!)),
            const SizedBox(height: 12),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Performance Trend'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  summary.trend,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildModelInfoCard(ModelInfo modelInfo) {
    final isOnline = !_predictionService.isOfflineMode;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.offline_bolt,
                color: isOnline ? Colors.blue : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'Model Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.blue : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSummaryRow('Version', modelInfo.version, Colors.grey[700]!),
          const SizedBox(height: 12),
          
          _buildSummaryRow('Last Updated', DateFormat('MMM dd, yyyy').format(modelInfo.lastTrained), Colors.grey[700]!),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mode'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOnline ? 'Cloud AI' : 'Local Analysis',
                  style: TextStyle(
                    color: isOnline ? Colors.blue : Colors.orange,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Recommendations',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Personalized training recommendations based on your performance predictions will be available soon!',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Coming Soon:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Intensity-based training plans\n'
                    '• Stroke-specific improvement tips\n'
                    '• Recovery recommendations\n'
                    '• Competition preparation guides',
                    style: TextStyle(color: Colors.blue[600]),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Date unavailable';
    }
    
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getErrorMessage() {
    if (_errorMessage?.contains('sklearn') == true) {
      return 'Our prediction server is updating. We\'ll use smart local analysis instead!';
    } else if (_errorMessage?.contains('timeout') == true) {
      return 'Connection timeout. Let\'s analyze your data locally.';
    } else if (_errorMessage?.contains('connection') == true) {
      return 'Unable to connect to prediction server. Using offline analysis.';
    } else {
      return 'Switching to offline prediction mode...';
    }
  }

  String _getPeakDay() {
    if (_predictionResponse?.futurePredictions?.byDate.isNotEmpty == true) {
      double maxImprovement = 0;
      String peakDate = '';
      
      _predictionResponse!.futurePredictions!.byDate.forEach((date, predictions) {
        double totalImprovement = predictions.fold(0, (sum, p) => sum + p.improvement);
        if (totalImprovement > maxImprovement) {
          maxImprovement = totalImprovement;
          peakDate = date;
        }
      });
      
      try {
        final date = DateTime.parse(peakDate);
        return DateFormat('MMM d').format(date);
      } catch (e) {
        return 'TBD';
      }
    }
    return 'TBD';
  }

  double _getAverageImprovement() {
    if (_predictionResponse?.futurePredictions?.byDate.isNotEmpty == true) {
      double totalImprovement = 0;
      int count = 0;
      
      _predictionResponse!.futurePredictions!.byDate.values.forEach((predictions) {
        predictions.forEach((prediction) {
          totalImprovement += prediction.improvement.abs();
          count++;
        });
      });
      
      return count > 0 ? totalImprovement / count : 0;
    }
    return 0;
  }

  double _getAverageIntensity() {
    if (_predictionResponse?.futurePredictions?.byDate.isNotEmpty == true) {
      double totalIntensity = 0;
      int count = 0;
      
      _predictionResponse!.futurePredictions!.byDate.values.forEach((predictions) {
        predictions.forEach((prediction) {
          if (prediction.intensity != null) {
            totalIntensity += prediction.intensity!;
            count++;
          }
        });
      });
      
      return count > 0 ? totalIntensity / count : 5.0;
    }
    return 5.0;
  }

  Color _getIntensityColor(double intensity) {
    if (intensity >= 8.0) {
      return Colors.red;
    } else if (intensity >= 6.0) {
      return Colors.orange;
    } else if (intensity >= 4.0) {
      return Colors.yellow[700]!;
    } else {
      return Colors.green;
    }
  }

  IconData _getStrokeIcon(String strokeType) {
    switch (strokeType.toLowerCase()) {
      case 'freestyle':
        return Icons.directions_run;
      case 'backstroke':
        return Icons.swap_calls;
      case 'breaststroke':
        return Icons.waves;
      case 'butterfly':
        return Icons.flight;
      case 'medley':
        return Icons.all_inclusive;
      default:
        return Icons.pool;
    }
  }
}