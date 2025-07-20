import 'package:flutter/material.dart';
import 'dart:math' as math;

class MiniChartPainter extends CustomPainter {
  final List<double>? dataPoints;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;

  MiniChartPainter({
    this.dataPoints,
    this.lineColor = Colors.white,
    this.fillColor = const Color(0x33FFFFFF),
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints == null || dataPoints!.isEmpty) {
      _drawSampleChart(canvas, size);
      return;
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Calculate dimensions
    final double chartWidth = size.width;
    final double chartHeight = size.height;
    final double stepX = chartWidth / (dataPoints!.length - 1);

    // Find min and max values for scaling
    final double maxValue = dataPoints!.reduce(math.max);
    final double minValue = dataPoints!.reduce(math.min);
    final double valueRange = maxValue - minValue;

    // Start fill path from bottom
    fillPath.moveTo(0, chartHeight);

    // Generate points
    for (int i = 0; i < dataPoints!.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = valueRange > 0 
          ? (dataPoints![i] - minValue) / valueRange 
          : 0.5;
      final double y = chartHeight - (normalizedValue * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(chartWidth, chartHeight);
    fillPath.close();

    // Draw filled area
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints!.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = valueRange > 0 
          ? (dataPoints![i] - minValue) / valueRange 
          : 0.5;
      final double y = chartHeight - (normalizedValue * chartHeight);
      
      canvas.drawCircle(Offset(x, y), 2, pointPaint);
    }
  }

  void _drawSampleChart(Canvas canvas, Size size) {
    // Generate sample data for demo
    final sampleData = List.generate(8, (index) => 
        50 + math.sin(index * 0.8) * 20 + math.Random().nextDouble() * 10);
    
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final double chartWidth = size.width;
    final double chartHeight = size.height;
    final double stepX = chartWidth / (sampleData.length - 1);

    final double maxValue = sampleData.reduce(math.max);
    final double minValue = sampleData.reduce(math.min);
    final double valueRange = maxValue - minValue;

    fillPath.moveTo(0, chartHeight);

    for (int i = 0; i < sampleData.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = (sampleData[i] - minValue) / valueRange;
      final double y = chartHeight - (normalizedValue * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(chartWidth, chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw sample points
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < sampleData.length; i++) {
      final double x = i * stepX;
      final double normalizedValue = (sampleData[i] - minValue) / valueRange;
      final double y = chartHeight - (normalizedValue * chartHeight);
      
      canvas.drawCircle(Offset(x, y), 2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}

class PerformanceChartPainter extends CustomPainter {
  final List<double> timeData;
  final List<String> labels;
  final Color primaryColor;
  final Color backgroundColor;

  PerformanceChartPainter({
    required this.timeData,
    required this.labels,
    this.primaryColor = const Color(0xFF4A90E2),
    this.backgroundColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (timeData.isEmpty) return;

    final double chartWidth = size.width - 60; // Leave space for labels
    final double chartHeight = size.height - 40; // Leave space for bottom labels
    final double chartLeft = 40;
    final double chartTop = 20;

    // Find min and max values
    final double maxTime = timeData.reduce(math.max);
    final double minTime = timeData.reduce(math.min);
    final double timeRange = maxTime - minTime;

    // Draw background
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final double y = chartTop + (chartHeight / 5) * i;
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartLeft + chartWidth, y),
        gridPaint,
      );
    }

    // Draw chart line
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = primaryColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final double stepX = chartWidth / (timeData.length - 1);

    // Start fill path
    fillPath.moveTo(chartLeft, chartTop + chartHeight);

    for (int i = 0; i < timeData.length; i++) {
      final double x = chartLeft + i * stepX;
      final double normalizedValue = timeRange > 0 
          ? (maxTime - timeData[i]) / timeRange 
          : 0.5;
      final double y = chartTop + (1 - normalizedValue) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(chartLeft + chartWidth, chartTop + chartHeight);
    fillPath.close();

    // Draw filled area and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw data points
    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < timeData.length; i++) {
      final double x = chartLeft + i * stepX;
      final double normalizedValue = timeRange > 0 
          ? (maxTime - timeData[i]) / timeRange 
          : 0.5;
      final double y = chartTop + (1 - normalizedValue) * chartHeight;

      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      
      // Draw white center
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 2, whitePaint);
    }

    // Draw labels
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
    );

    for (int i = 0; i < labels.length && i < timeData.length; i++) {
      final double x = chartLeft + i * stepX;
      final textPainter = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartTop + chartHeight + 5),
      );
    }

    // Draw Y-axis labels
    for (int i = 0; i <= 5; i++) {
      final double value = minTime + (timeRange / 5) * (5 - i);
      final double y = chartTop + (chartHeight / 5) * i;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${value.toStringAsFixed(1)}s',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(5, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}