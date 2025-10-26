import 'package:flutter/material.dart';
import '../models/improvement_prediction.dart';

class EnhancedImprovementPredictionCard extends StatelessWidget {
  final String date;
  final List<ImprovementPrediction> predictions;

  const EnhancedImprovementPredictionCard({
    super.key,
    required this.date,
    required this.predictions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            ...predictions.map((pred) => _buildPredictionRow(pred)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final parsedDate = DateTime.parse(date);
    final formattedDate = '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF4A90E2)),
        const SizedBox(width: 8),
        Text(
          formattedDate,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${predictions.length} prediction${predictions.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4A90E2),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionRow(ImprovementPrediction prediction) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: prediction.improvementColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: prediction.improvementColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                prediction.improvementIcon,
                color: prediction.improvementColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prediction.stroke,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${prediction.improvement > 0 ? '+' : ''}${prediction.improvement.toStringAsFixed(2)}s',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: prediction.improvementColor,
                ),
              ),
            ],
          ),
          if (prediction.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              prediction.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (prediction.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Key Factors:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...prediction.reasons.take(3).map((reason) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Row(
                children: [
                  const Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}