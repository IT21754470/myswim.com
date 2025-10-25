import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/improvement_prediction.dart';

class ImprovementTrendChart extends StatefulWidget {
  final Map<String, List<ImprovementPrediction>> predictionsByDate;
  final bool showFuture;

  const ImprovementTrendChart({
    super.key,
    required this.predictionsByDate,
    this.showFuture = true,
  });

  @override
  State<ImprovementTrendChart> createState() => _ImprovementTrendChartState();
}

class _ImprovementTrendChartState extends State<ImprovementTrendChart> {
  String? _selectedStroke;
  bool _showAllStrokes = true;

  @override
  Widget build(BuildContext context) {
    if (widget.predictionsByDate.isEmpty) {
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
        child: const Center(
          child: Text('No data available for chart'),
        ),
      );
    }

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
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStrokeFilter(),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(_createChartData()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.show_chart,
            color: Color(0xFF4A90E2),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Performance Trend',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStrokeFilter() {
    // Get all unique strokes
    final allStrokes = <String>{};
    for (var predictions in widget.predictionsByDate.values) {
      for (var pred in predictions) {
        allStrokes.add(pred.stroke);
      }
    }

    if (allStrokes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // "All Strokes" chip
        ChoiceChip(
          label: const Text('All Strokes'),
          selected: _showAllStrokes,
          onSelected: (selected) {
            setState(() {
              _showAllStrokes = true;
              _selectedStroke = null;
            });
          },
          selectedColor: const Color(0xFF4A90E2).withOpacity(0.2),
          labelStyle: TextStyle(
            color: _showAllStrokes ? const Color(0xFF4A90E2) : Colors.grey[700],
            fontWeight: _showAllStrokes ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        // Individual stroke chips
        ...allStrokes.map((stroke) => ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStrokeColor(stroke),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(stroke),
            ],
          ),
          selected: _selectedStroke == stroke,
          onSelected: (selected) {
            setState(() {
              _showAllStrokes = false;
              _selectedStroke = stroke;
            });
          },
          selectedColor: _getStrokeColor(stroke).withOpacity(0.2),
          labelStyle: TextStyle(
            color: _selectedStroke == stroke 
                ? _getStrokeColor(stroke) 
                : Colors.grey[700],
            fontWeight: _selectedStroke == stroke 
                ? FontWeight.w600 
                : FontWeight.normal,
            fontSize: 12,
          ),
        )),
      ],
    );
  }

  Color _getStrokeColor(String stroke) {
    switch (stroke.toLowerCase()) {
      case 'freestyle':
      case 'free':
        return const Color(0xFF4A90E2); // Blue
      case 'backstroke':
      case 'back':
        return const Color(0xFF50C878); // Green
      case 'breaststroke':
      case 'breast':
        return const Color(0xFFFF6B6B); // Red
      case 'butterfly':
      case 'fly':
        return const Color(0xFFFFB84D); // Orange
      default:
        return const Color(0xFF9B59B6); // Purple
    }
  }

  LineChartData _createChartData() {
    final sortedDates = widget.predictionsByDate.keys.toList()..sort();
    
    if (_showAllStrokes) {
      return _createMultiStrokeChart(sortedDates);
    } else {
      return _createSingleStrokeChart(sortedDates, _selectedStroke!);
    }
  }

  LineChartData _createMultiStrokeChart(List<String> sortedDates) {
    // Get all strokes
    final strokeData = <String, List<FlSpot>>{};
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final predictions = widget.predictionsByDate[date]!;
      
      // Group by stroke
      final strokeGroups = <String, List<double>>{};
      for (var pred in predictions) {
        strokeGroups.putIfAbsent(pred.stroke, () => []).add(pred.improvement);
      }
      
      // Calculate average for each stroke
      strokeGroups.forEach((stroke, improvements) {
        final avg = improvements.reduce((a, b) => a + b) / improvements.length;
        strokeData.putIfAbsent(stroke, () => []).add(FlSpot(i.toDouble(), avg));
      });
    }

    // Create line bars for each stroke
    final lineBars = strokeData.entries.map((entry) {
      return LineChartBarData(
        spots: entry.value,
        isCurved: true,
        color: _getStrokeColor(entry.key),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: _getStrokeColor(entry.key),
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: false,
        ),
      );
    }).toList();

    return _buildChartData(sortedDates, lineBars);
  }

  LineChartData _createSingleStrokeChart(List<String> sortedDates, String stroke) {
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final predictions = widget.predictionsByDate[date]!
          .where((p) => p.stroke == stroke)
          .toList();
      
      if (predictions.isNotEmpty) {
        final avgImprovement = predictions.fold<double>(
          0, (sum, p) => sum + p.improvement
        ) / predictions.length;
        spots.add(FlSpot(i.toDouble(), avgImprovement));
      }
    }

    if (spots.isEmpty) {
      // Return empty chart if no data for selected stroke
      return LineChartData(
        lineBarsData: [],
        titlesData: const FlTitlesData(show: false),
      );
    }

    final lineBar = LineChartBarData(
      spots: spots,
      isCurved: true,
      gradient: LinearGradient(
        colors: [
          _getStrokeColor(stroke),
          _getStrokeColor(stroke).withOpacity(0.6),
        ],
      ),
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final color = spot.y > 0 ? Colors.green : Colors.red;
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
            _getStrokeColor(stroke).withOpacity(0.2),
            _getStrokeColor(stroke).withOpacity(0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );

    return _buildChartData(sortedDates, [lineBar]);
  }

  LineChartData _buildChartData(List<String> sortedDates, List<LineChartBarData> lineBars) {
    // Calculate min and max values for Y axis
    double minY = 0;
    double maxY = 0;
    
    for (var lineBar in lineBars) {
      for (var spot in lineBar.spots) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    
    // Add padding to Y axis
    minY = minY - 0.5;
    maxY = maxY + 0.5;

    return LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 5,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[300]!,
            strokeWidth: 1,
            dashArray: value == 0 ? null : [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            interval: (maxY - minY) / 5,
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}s',
                  style: TextStyle(
                    fontSize: 10,
                    color: value > 0 ? Colors.green[700] : 
                           value < 0 ? Colors.red[700] : Colors.grey,
                    fontWeight: value == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: sortedDates.length > 10 ? 2 : 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= sortedDates.length || value.toInt() < 0) {
                return const Text('');
              }
              final date = DateTime.parse(sortedDates[value.toInt()]);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('MM/dd').format(date),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: Colors.grey[300]!, width: 1),
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      lineBarsData: lineBars,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.blueGrey.withOpacity(0.9),
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final date = sortedDates[spot.x.toInt()];
              final dateFormatted = DateFormat('MMM d').format(DateTime.parse(date));
              
              // Get stroke from color if showing all strokes
              String strokeLabel = '';
              if (_showAllStrokes) {
                final strokeColor = spot.bar.color ?? spot.bar.gradient?.colors.first;
                if (strokeColor != null) {
                  // Find stroke by color (approximate)
                  final strokeData = <String, List<FlSpot>>{};
                  for (var pred in widget.predictionsByDate[date]!) {
                    strokeData.putIfAbsent(pred.stroke, () => []);
                  }
                  for (var stroke in strokeData.keys) {
                    if (_getStrokeColor(stroke) == strokeColor) {
                      strokeLabel = '\n$stroke';
                      break;
                    }
                  }
                }
              }
              
              return LineTooltipItem(
                '$dateFormatted$strokeLabel\n${spot.y > 0 ? '+' : ''}${spot.y.toStringAsFixed(2)}s',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
        touchSpotThreshold: 30,
      ),
    );
  }
}