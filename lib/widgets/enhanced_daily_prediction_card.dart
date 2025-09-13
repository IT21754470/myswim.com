import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/improvement_prediction_service.dart';

class EnhancedDailyPredictionCard extends StatelessWidget {
  final String date;
  final List<DailyPrediction> predictions;

  const EnhancedDailyPredictionCard({
    super.key,
    required this.date,
    required this.predictions,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${predictions.length} stroke predictions',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_getAverageImprovement().toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Predictions List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: predictions.map((prediction) => 
                _buildPredictionRow(prediction)
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionRow(DailyPrediction prediction) {
    final improvementColor = prediction.improvement > 0 
        ? Colors.green 
        : prediction.improvement < 0 
            ? Colors.red 
            : Colors.orange;

    final strokeIcon = _getStrokeIcon(prediction.strokeType);
    final strokeColor = _getStrokeColor(prediction.strokeType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: strokeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: strokeColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: strokeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              strokeIcon,
              color: strokeColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prediction.strokeType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Predicted: ${prediction.predictedTime.toStringAsFixed(1)}s',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: improvementColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${prediction.improvement > 0 ? '+' : ''}${prediction.improvement.toStringAsFixed(1)}s',
                  style: TextStyle(
                    color: improvementColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(prediction.confidence * 100).toInt()}% confidence',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMM d').format(date);
    } catch (e) {
      return dateString;
    }
  }

  double _getAverageImprovement() {
    if (predictions.isEmpty) return 0.0;
    final total = predictions.fold<double>(0, (sum, p) => sum + p.improvement);
    return total / predictions.length;
  }

  IconData _getStrokeIcon(String strokeType) {
    switch (strokeType) {
      case 'Freestyle':
        return Icons.pool;
      case 'Backstroke':
        return Icons.flip_camera_android;
      case 'Breaststroke':
        return Icons.favorite;
      case 'Butterfly':
        return Icons.flutter_dash;
      default:
        return Icons.pool;
    }
  }

  Color _getStrokeColor(String strokeType) {
    switch (strokeType) {
      case 'Freestyle':
        return const Color(0xFF4A90E2);
      case 'Backstroke':
        return const Color(0xFF9C27B0);
      case 'Breaststroke':
        return const Color(0xFF4CAF50);
      case 'Butterfly':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF4A90E2);
    }
  }
}