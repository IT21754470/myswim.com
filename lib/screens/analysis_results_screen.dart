// lib/screens/analysis_results_screen.dart
// Renders live backend JSON (decision, prob, window_probs, risky_features_overall)

import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnalysisResultsScreen extends StatefulWidget {
  static const routeName = '/analysis-results';
  const AnalysisResultsScreen({super.key});

  @override
  State<AnalysisResultsScreen> createState() => _AnalysisResultsScreenState();
}

class _AnalysisResultsScreenState extends State<AnalysisResultsScreen> {
  Map<String, dynamic>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read args once
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _data == null) {
      setState(() => _data = args);
    }
  }

  @override
Widget build(BuildContext context) {
  // Read data passed via Navigator; fall back to existing _data
  final args = ModalRoute.of(context)?.settings.arguments;
  final Map<String, dynamic>? incoming =
      (args is Map<String, dynamic>) ? args : null;
  final d = incoming ?? _data;

  return Scaffold(
    appBar: AppBar(
      elevation: 0,
      centerTitle: true,
      title: const Text('Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          ),
        ),
      ),
    ),
    body: Container(
      color: const Color(0xFFF3E5F5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: (d == null)
            ? const _EmptyResultsNote()
            : _Results(d: d),
      ),
    ),
  );
}
}


class _EmptyResultsNote extends StatelessWidget {
  const _EmptyResultsNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: const Text(
        'No results passed. Run an analysis from the Injury Prediction screen.',
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.d});
  final Map<String, dynamic> d;

  static const _labels = {
    'left_shoulder_angle': 'Left Shoulder',
    'right_shoulder_angle': 'Right Shoulder',
    'left_knee_angle': 'Left Knee',
    'right_knee_angle': 'Right Knee',
  };

  @override
  Widget build(BuildContext context) {
    final decision = (d['decision'] as String?) ?? '—';
    final th = (d['th'] as num?)?.toDouble() ?? 0.463;
    final prob = (d['prob'] as num?)?.toDouble() ?? 0.0;
    final winProbs = (d['window_probs'] as List?)?.cast<num>().map((e) => e.toDouble()).toList() ?? const <double>[];
    final meta = (d['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final window = (meta['window'] as num?)?.toInt() ?? 30;
    final stride = (meta['stride'] as num?)?.toInt() ?? 15;

    final riskyOverall = ((d['risky_features_overall'] as List?) ?? const [])
        .cast<String>()
        .where(_labels.containsKey)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with decision + donut
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Row(
            children: [
              Expanded(
                child: _DecisionBadge(decision: decision, prob: prob),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                height: 120,
                child: _RiskDonut(value: prob),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Silhouette + bullet list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 160,
                child: _SilhouetteDots(risky: riskyOverall),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: riskyOverall.isEmpty
                      ? const [Text('No risky joints detected')]
                      : riskyOverall
                          .map((k) => _ChipPill(label: _labels[k] ?? k))
                          .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Risk timeline
Container(
  padding: const EdgeInsets.all(16),
  decoration: _cardDeco(),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const _IconBadge(icon: Icons.timeline, color: Color(0xFF764ba2)),
          const SizedBox(width: 8),
          const Text('Risk timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('win: $window  stride: $stride',
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: 16 / 9,
        child: _RiskTimelineChart(values: winProbs, threshold: th, window: window, stride: stride),
      ),

            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({required this.decision, required this.prob});
  final String decision;
  final double prob;

  @override
  Widget build(BuildContext context) {
    final isRisky = decision.toLowerCase() == 'risky';
    final bg = isRisky ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
    final fg = isRisky ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Decision', style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(isRisky ? Icons.warning_rounded : Icons.check_circle_rounded, color: fg),
              const SizedBox(width: 6),
              Text(
                decision,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg),
              ),
              const SizedBox(width: 8),
              Text('•  ${(prob * 100).round()}% risk', style: TextStyle(color: fg)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskDonut extends StatelessWidget {
  const _RiskDonut({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0).toDouble(); // ensure double
    return CustomPaint(
      painter: _DonutPainter(v),
      child: Center(
        child: Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double v; // 0..1
  _DonutPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.min(size.width, size.height) * 0.12;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;

    final bg = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawCircle(center, radius, bg);

    // Foreground arc
    final start = -math.pi / 2;
    final sweep = v * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.v != v;
}

class _SilhouetteDots extends StatelessWidget {
  const _SilhouetteDots({required this.risky});
  final Set<String> risky;

  @override
Widget build(BuildContext context) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        Offset pt(double x, double y) => Offset(w * x, h * y);

        // Anchor points tuned for a centered, full-height silhouette image
        final anchors = <String, Offset>{
          'left_shoulder_angle' : pt(0.32, 0.28),
          'right_shoulder_angle': pt(0.68, 0.28),
          'left_knee_angle'     : pt(0.42, 0.78),
          'right_knee_angle'    : pt(0.58, 0.78),
        };

        return Stack(
          fit: StackFit.expand,
          children: [
            // background silhouette
            Image.asset(
              'assets/images/human_silhouette.png',
              fit: BoxFit.cover,
            ),

            // overlay risk dots
            ...anchors.entries.map((e) {
              final active = risky.contains(e.key);
              return Positioned(
                left: e.value.dx - 7,
                top:  e.value.dy - 7,
                child: _riskDot(active),
              );
            }),
          ],
        );
      },
    ),
  );
}


  Widget _riskDot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF44336) : const Color(0xFFBDBDBD),
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: const Color(0xFFF44336).withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
    );
  }
}

class _RiskTimelineChart extends StatelessWidget {
  const _RiskTimelineChart({
    required this.values,
    required this.threshold,
    required this.window,
    required this.stride,
  });

  final List<double> values;
  final double threshold;
  final int window;
  final int stride;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimelinePainter(values: values, threshold: threshold),
      
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.values, required this.threshold});

  final List<double> values;
  final double threshold;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pad = 16.0;
    final chart = Rect.fromLTWH(rect.left + pad, rect.top + pad, rect.width - 2 * pad, rect.height - 2 * pad);

    // BG
    final bg = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), bg);

    // Axes
    final axis = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(chart.left, chart.bottom), Offset(chart.right, chart.bottom), axis);
    canvas.drawLine(Offset(chart.left, chart.top), Offset(chart.left, chart.bottom), axis);

    if (values.isEmpty) return;

    // Normalize y (0..1)
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + (chart.width * i / math.max(1, values.length - 1));
      final y = chart.bottom - (chart.height * values[i].clamp(0.0, 1.0));
      pts.add(Offset(x, y));
    }

    // Threshold line
    final thY = chart.bottom - (chart.height * threshold.clamp(0.0, 1.0));
    final thPaint = Paint()
      ..color = const Color(0xFFFFA000)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(chart.left, thY), Offset(chart.right, thY), thPaint);

    // Line path
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    final line = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      ).createShader(chart)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);

    // Points above threshold
    final dot = Paint()..color = const Color(0xFFf5576c);
    for (final p in pts) {
      if (p.dy <= thY) {
        canvas.drawCircle(p, 3.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.values != values || old.threshold != threshold;
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A5298).withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A5298).withOpacity(0.2)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
    );
