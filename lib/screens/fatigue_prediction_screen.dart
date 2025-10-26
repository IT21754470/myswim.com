import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swimming_app/services/fatigur_prediction_service.dart';
import '../models/training_session.dart';
import '../services/fatigur_prediction_service.dart';
import '../services/training_session_service.dart';

class FatiguePredictionsTab extends StatefulWidget {
  const FatiguePredictionsTab({Key? key}) : super(key: key);

  @override
  State<FatiguePredictionsTab> createState() => _FatiguePredictionsTabState();
}

class _FatiguePredictionsTabState extends State<FatiguePredictionsTab> with SingleTickerProviderStateMixin {
  final FatiguePredictionService _service = FatiguePredictionService();
  FatiguePredictionResponse? _response7Days;
  FatiguePredictionResponse? _response14Days;
  FatiguePredictionResponse? _response30Days;
  bool _isLoading = true;
  String? _errorMessage;
  
  late TabController _periodTabController;
  int _selectedPeriod = 0;

  @override
  void initState() {
    super.initState();
    _periodTabController = TabController(length: 3, vsync: this);
    _periodTabController.addListener(() {
      setState(() {
        _selectedPeriod = _periodTabController.index;
      });
    });
    _loadAllPredictions();
  }

  @override
  void dispose() {
    _periodTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPredictions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _service.initialize();
      final sessions = await TrainingSessionService.getUserTrainingSessions();
      
      if (sessions.isEmpty) {
        setState(() {
          _errorMessage = 'No training data available';
          _isLoading = false;
        });
        return;
      }

      final response7 = await _service.getFatiguePrediction(
        trainingHistory: sessions,
        daysToPredict: 7,
      );
      
      final response14 = await _service.getFatiguePrediction(
        trainingHistory: sessions,
        daysToPredict: 14,
      );
      
      final response30 = await _service.getFatiguePrediction(
        trainingHistory: sessions,
        daysToPredict: 30,
      );

      setState(() {
        _response7Days = response7;
        _response14Days = response14;
        _response30Days = response30;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  FatiguePredictionResponse? get _currentResponse {
    switch (_selectedPeriod) {
      case 0: return _response7Days;
      case 1: return _response14Days;
      case 2: return _response30Days;
      default: return _response7Days;
    }
  }

  int get _currentDays {
    switch (_selectedPeriod) {
      case 0: return 7;
      case 1: return 14;
      case 2: return 30;
      default: return 7;
    }
  }

  Map<String, FatigueDayPrediction> _getFutureDaysOnly(FatiguePredictionResponse? response, int days) {
    if (response?.predictions == null) return {};
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final filtered = Map.fromEntries(
      response!.predictions!.entries.where((entry) {
        final date = DateTime.parse(entry.key);
        return date.isAfter(today);
      })
    );
    
    final sortedDates = filtered.keys.toList()..sort();
    final nextDays = sortedDates.take(days);
    
    return Map.fromEntries(
      nextDays.map((date) => MapEntry(date, filtered[date]!))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildGradientHeader(),
          Expanded(
            child: _isLoading ? _buildLoadingState() : 
                   _errorMessage != null ? _buildErrorState() : 
                   _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader() {
    final predictions = _getFutureDaysOnly(_currentResponse, _currentDays);
    final avgFatigue = _calculateAverageFatigue(predictions);
    final peakDate = _findPeakFatigueDate(predictions);
    final riskLevel = _determineOverallRiskLevel(predictions);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFfa709a),
           Color.fromARGB(255, 244, 158, 88),
            Color.fromARGB(255, 247, 229, 151),
           
           
         
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Fatigue Prediction',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 197, 89, 26).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color.fromARGB(255, 188, 82, 40).withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off, color: const Color.fromARGB(255, 198, 103, 25), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _service.isOfflineMode ? 'Local' : 'Online',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadAllPredictions,
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _periodTabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  labelColor: Colors.pink[400],
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '7 Days'),
                    Tab(text: '14 Days'),
                    Tab(text: '30 Days'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (!_isLoading && _errorMessage == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCard(
                      icon: Icons.battery_charging_full,
                      value: avgFatigue.toStringAsFixed(1),
                      label: 'Current',
                    ),
                    _buildSummaryCard(
                      icon: Icons.warning_amber_rounded,
                      value: peakDate ?? '-',
                      label: 'Peak Day',
                    ),
                    _buildSummaryCard(
                      icon: Icons.bar_chart,
                      value: avgFatigue.toStringAsFixed(1),
                      label: 'Average',
                    ),
                    _buildSummaryCard(
                      icon: Icons.shield,
                      value: riskLevel,
                      label: 'Risk Level',
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.orange[300], size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final predictions = _getFutureDaysOnly(_currentResponse, _currentDays);

    if (predictions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No predictions for next $_currentDays days'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllPredictions,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final dates = predictions.keys.toList()..sort();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: Colors.pink[400],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.pink[400],
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'Daily Fatigue'),
                Tab(text: 'Risk Analysis'),
                Tab(text: 'Recommendations'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDailyFatigueList(dates, predictions),
                _buildRiskAnalysisTab(predictions), // ✅ Updated with chart
                _buildRecommendationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Risk Analysis Tab with Chart
  Widget _buildRiskAnalysisTab(Map<String, FatigueDayPrediction> predictions) {
    if (predictions.isEmpty) {
      return const Center(child: Text('No data for risk analysis'));
    }

    final dates = predictions.keys.toList()..sort();
    final lowRiskCount = predictions.values.where((p) => p.riskLevel.toLowerCase() == 'low').length;
    final mediumRiskCount = predictions.values.where((p) => p.riskLevel.toLowerCase() == 'medium').length;
    final highRiskCount = predictions.values.where((p) => p.riskLevel.toLowerCase() == 'high').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Fatigue Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: _buildFatigueChart(dates, predictions),
                  ),
                  const SizedBox(height: 16),
                  _buildChartLegend(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Risk Distribution
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart, color: Colors.purple[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Risk Distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildRiskBar('Low Risk', lowRiskCount, dates.length, Colors.green),
                  const SizedBox(height: 12),
                  _buildRiskBar('Medium Risk', mediumRiskCount, dates.length, Colors.orange),
                  const SizedBox(height: 12),
                  _buildRiskBar('High Risk', highRiskCount, dates.length, Colors.red),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Insights
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Key Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._generateInsights(predictions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Build Fatigue Chart
  Widget _buildFatigueChart(List<String> dates, Map<String, FatigueDayPrediction> predictions) {
    List<FlSpot> spots = [];
    
    for (int i = 0; i < dates.length; i++) {
      final prediction = predictions[dates[i]]!;
      spots.add(FlSpot(i.toDouble(), prediction.fatigueLevel));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: dates.length > 10 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dates.length) {
                  final date = DateTime.parse(dates[value.toInt()]);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (dates.length - 1).toDouble(),
        minY: 0,
        maxY: 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue[700],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                Color color;
                if (spot.y < 4) color = Colors.green;
                else if (spot.y < 7) color = Colors.orange;
                else color = Colors.red;
                
                return FlDotCirclePainter(
                  radius: 5,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue[700]!.withOpacity(0.3),
                  Colors.blue[700]!.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = DateTime.parse(dates[spot.x.toInt()]);
                return LineTooltipItem(
                  '${date.day}/${date.month}\n${spot.y.toStringAsFixed(1)}/10',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.green, 'Low (0-4)'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.orange, 'Medium (4-7)'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.red, 'High (7-10)'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildRiskBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '$count days (${(percentage * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 20,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  List<Widget> _generateInsights(Map<String, FatigueDayPrediction> predictions) {
    List<Widget> insights = [];
    final avgFatigue = _calculateAverageFatigue(predictions);
    final highRiskDays = predictions.values.where((p) => p.riskLevel.toLowerCase() == 'high').length;
    
    if (avgFatigue > 7) {
      insights.add(_buildInsightItem(
        Icons.warning,
        'High overall fatigue detected',
        'Consider reducing training load and prioritizing recovery',
        Colors.red,
      ));
    } else if (avgFatigue < 4) {
      insights.add(_buildInsightItem(
        Icons.check_circle,
        'Excellent recovery status',
        'Good time for high-intensity training or competition',
        Colors.green,
      ));
    }
    
    if (highRiskDays > 0) {
      insights.add(_buildInsightItem(
        Icons.event_busy,
        '$highRiskDays high-risk days detected',
        'Plan rest days and avoid intense sessions on these dates',
        Colors.orange,
      ));
    }
    
    insights.add(_buildInsightItem(
      Icons.trending_up,
      'Average fatigue: ${avgFatigue.toStringAsFixed(1)}/10',
      'Monitor closely and adjust training accordingly',
      Colors.blue,
    ));
    
    return insights;
  }

  Widget _buildInsightItem(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Keep all other methods the same (buildDailyFatigueList, buildDayCard, etc.)
  Widget _buildDailyFatigueList(List<String> dates, Map<String, FatigueDayPrediction> predictions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final prediction = predictions[date]!;
        return _buildDayCard(date, prediction, index);
      },
    );
  }

  Widget _buildDayCard(String date, FatigueDayPrediction prediction, int index) {
    final color = _getRiskColor(prediction.riskLevel);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 18,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          _formatDate(date),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(_getRiskIcon(prediction.riskLevel), size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                prediction.riskLevel,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getFatigueColor(prediction.fatigueLevel).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${prediction.fatigueLevel.toStringAsFixed(1)}/10',
                  style: TextStyle(
                    color: _getFatigueColor(prediction.fatigueLevel),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFatigueGauge(prediction.fatigueLevel),
                const SizedBox(height: 16),
                
                _buildInfoRow(
                  Icons.speed,
                  'Recommended Intensity',
                  '${prediction.recommendedIntensity.toStringAsFixed(1)}/10',
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                
                _buildInfoRow(
                  prediction.recoveryNeeded ? Icons.hotel : Icons.fitness_center,
                  'Status',
                  prediction.recoveryNeeded ? 'Recovery Day' : 'Training Day',
                  prediction.recoveryNeeded ? Colors.orange : Colors.green,
                ),
                
                if (prediction.reasons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Key Factors',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...prediction.reasons.take(3).map((reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                
                if (prediction.tips.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Recovery Tips',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...prediction.tips.take(2).map((tip) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Text(
                      tip,
                      style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                    ),
                  )),
                ],
                
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Confidence: ${(prediction.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_currentResponse?.recommendations == null || _currentResponse!.recommendations!.isEmpty) {
      return const Center(child: Text('No recommendations available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 1,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildRecommendationsList(),
        );
      },
    );
  }

  List<Widget> _buildRecommendationsList() {
    final recommendations = _currentResponse!.recommendations!;
    List<Widget> widgets = [];
    
    for (var rec in recommendations) {
      if (rec.contains('**')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              rec.replaceAll('**', '').replaceAll(RegExp(r'[📊🚨⚠️✅📏📈⚡📅🔄🏊🎯]'), '').trim(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 240, 150, 24)),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 244, 166, 57),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rec.replaceAll('• ', ''),
                    style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    return widgets;
  }

  Widget _buildFatigueGauge(double fatigue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fatigue Level',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '${fatigue.toStringAsFixed(1)}/10',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getFatigueColor(fatigue),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fatigue / 10,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(_getFatigueColor(fatigue)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_errorMessage'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllPredictions,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  double _calculateAverageFatigue(Map<String, FatigueDayPrediction> predictions) {
    if (predictions.isEmpty) return 0;
    final sum = predictions.values.fold(0.0, (sum, p) => sum + p.fatigueLevel);
    return sum / predictions.length;
  }

  String? _findPeakFatigueDate(Map<String, FatigueDayPrediction> predictions) {
    if (predictions.isEmpty) return null;
    
    var maxFatigue = 0.0;
    String? peakDate;
    
    predictions.forEach((date, pred) {
      if (pred.fatigueLevel > maxFatigue) {
        maxFatigue = pred.fatigueLevel;
        peakDate = date;
      }
    });
    
    if (peakDate == null) return null;
    final date = DateTime.parse(peakDate!);
    return '${_getMonthAbbr(date.month)} ${date.day}';
  }

  String _determineOverallRiskLevel(Map<String, FatigueDayPrediction> predictions) {
    if (predictions.isEmpty) return 'Low';
    
    final avgFatigue = _calculateAverageFatigue(predictions);
    if (avgFatigue > 7) return 'High';
    if (avgFatigue > 4) return 'Medium';
    return 'Low';
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return Icons.check_circle;
      case 'medium': return Icons.warning;
      case 'high': return Icons.error;
      default: return Icons.help;
    }
  }

  Color _getFatigueColor(double fatigue) {
    if (fatigue < 4) return Colors.green;
    if (fatigue < 7) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff <= 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[date.weekday - 1]}, ${date.day}/${date.month}';
    }
    
    return '${date.day}/${date.month}/${date.year}';
  }
}