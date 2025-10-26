// lib/screens/analysis_results_screen.dart
// Renders live backend JSON (decision, prob, window_probs, risky_features_overall)

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ---- Brand palette (keeps styles consistent) ----
const kBrandStart    = Color(0xFF1E3C72); // app bar gradient start
const kBrandEnd      = Color(0xFF2A5298); // app bar gradient end
const kAccentA       = Color(0xFF4facfe); // line gradient A
const kAccentB       = Color(0xFF00f2fe); // line gradient B
const kAccentC       = Color(0xFFf093fb); // donut gradient A
const kAccentD       = Color(0xFFf5576c); // donut/dot accent
const kBadgeBlue     = Color(0xFF2A5298); // info/tip badges


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
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _data == null) {
      setState(() => _data = args);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: (d == null) ? const _EmptyResultsNote() : _Results(d: d),
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

    // Returns a one-line tip like:
  // "Try to keep Left Shoulder between 40–150°"
  String? _safeRangeTipFromPayload(Map<String, dynamic> d) {
    final risky = (d['risky_features_overall'] as List?)?.cast<String>() ?? const [];
    if (risky.isEmpty) return null;

    // Use the top (most risky) joint
    final top = risky.first;

    String side(String s) => s.contains('left')
        ? 'Left '
        : s.contains('right')
            ? 'Right '
            : '';

    if (top.contains('shoulder')) {
      return 'Try to keep ${side(top)}Shoulder between 40–150°';
    }
    if (top.contains('knee')) {
      return 'Try to keep ${side(top)}Knee between 30–140°';
    }
    return null;
  }


  // ----- NEW: resolve angles from top-level or meta.angles, both shapes -----
  Map<String, dynamic>? get _angles {
    final a = d['angles'];
    if (a is Map) return a.cast<String, dynamic>();
    final meta = d['meta'];
    if (meta is Map && meta['angles'] is Map) {
      return (meta['angles'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  // ----- NEW: bottom sheet with per-window mean angles for a joint -----
  void _showAnglesForJoint(BuildContext context, String jointKey) {
    final angles = _angles;
    if (angles == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Angles not available for this result.')),
      );
      return;
    }

    // windows.frame_ranges: [[start,end], ...]
    final List<dynamic> rangesDyn =
        (angles['windows'] is Map && angles['windows']['frame_ranges'] is List)
            ? (angles['windows']['frame_ranges'] as List<dynamic>)
            : const [];
    final ranges = rangesDyn
        .map<List<int>>((e) => [(e[0] as num).toInt(), (e[1] as num).toInt()])
        .toList();

    // Two supported shapes for per_frame
    final pf = angles['per_frame'];
    List<double> series;

    if (pf is Map) {
      // Map-of-arrays: { "left_knee_angle":[...], ... }
      final list = pf[jointKey];
      if (list is List) {
        series = list.map((n) => (n as num).toDouble()).toList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No series for $jointKey')),
        );
        return;
      }
    } else if (pf is List) {
      // List-of-rows: [[lk, rk, ls, rs], ...]
      const idxMap = {
        'left_knee_angle': 0,
        'right_knee_angle': 1,
        'left_shoulder_angle': 2,
        'right_shoulder_angle': 3,
      };
      final idx = idxMap[jointKey];
      if (idx == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown joint: $jointKey')),
        );
        return;
      }
      series = <double>[];
      for (final row in pf) {
        if (row is List && row.length > idx) {
          series.add((row[idx] as num).toDouble());
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected angles format.')),
      );
      return;
    }

    // Mean per window
    final means = <double>[];
    for (final r in ranges) {
      final start = r[0].clamp(0, series.length - 1);
      final end = r[1].clamp(0, series.length - 1);
      if (end < start) {
        means.add(0);
        continue;
      }
      double sum = 0; int n = 0;
      for (int i = start; i <= end; i++) { sum += series[i]; n++; }
      means.add(n > 0 ? sum / n : 0);
    }

    final title = _labels[jointKey] ?? jointKey;

        // OPEN the bottom sheet
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title • Angles by window',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),

              // CARD
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    // header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text('Window',
                                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Avg angle (°)',
                                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            child: Text('Spark',
                                textAlign: TextAlign.right,
                                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),

                    // rows
                    if (means.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('No windows found',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      )
                    else
                      for (int i = 0; i < means.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: cs.outlineVariant.withOpacity(.6), width: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text('Window ${i + 1}', style: TextStyle(color: cs.onSurface)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  means[i].toStringAsFixed(1),
                                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // tiny sparkline from frames in this window
                              SizedBox(
                                width: 72,
                                height: 24,
                                child: _MiniSparkline(
                                  values: _sliceSeriesForWindow(series, ranges[i]),
                                  lineStart: kAccentA,
                                  lineEnd: kAccentB,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'Averages are computed across frames inside each analysis window.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    ); // <-- CLOSE showModalBottomSheet
  }     // <-- CLOSE _showAnglesForJoint


  @override
  Widget build(BuildContext context) {
    final decision = (d['decision'] as String?) ?? '—';
    final th = (d['th'] as num?)?.toDouble() ?? 0.463;
    final prob = (d['prob'] as num?)?.toDouble() ?? 0.0;
    final winProbs = (d['window_probs'] as List?)
            ?.cast<num>()
            .map((e) => e.toDouble())
            .toList() ??
        const <double>[];
    final meta = (d['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final window = (meta['window'] as num?)?.toInt() ?? 30;
    final stride = (meta['stride'] as num?)?.toInt() ?? 15;

    final riskyOverall = ((d['risky_features_overall'] as List?) ?? const [])
        .cast<String>()
        .where(_labels.containsKey)
        .toSet();

      final tip = _safeRangeTipFromPayload(d);

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
  child: _DecisionBadge(
    decision: decision,
    prob: prob,
    tip: tip, // NEW: pass tip text
  ),
),

              const SizedBox(width: 12),
              SizedBox(width: 120, height: 120, child: _RiskDonut(value: prob)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Silhouette + chips (chips are tappable)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 110, height: 160, child: _SilhouetteDots(risky: riskyOverall)),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: riskyOverall.isEmpty
                      ? const [Text('No risky joints detected')]
                      : riskyOverall
                          .map((k) => InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _showAnglesForJoint(context, k),
                                child: _ChipPill(label: _labels[k] ?? k),
                              ))
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
                  const Text('Risk timeline',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('win: $window  stride: $stride',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 12),
              AspectRatio(
  aspectRatio: 16 / 9,
  child: _RiskTimelineChart(
    values: winProbs,
    threshold: th,
    window: window,
    stride: stride,
    xLabel: 'Window',
    yLabel: 'Risk prob',   // 0–1
  ),
),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({
    required this.decision,
    required this.prob,
    this.tip,
  });

  final String decision;
  final double prob;
  final String? tip; // NEW: optional one-line tip


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
              Text(decision,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg)),
              const SizedBox(width: 8),
              Text('•  ${(prob * 100).round()}% risk', style: TextStyle(color: fg)),
            ],
          ),
          if (tip != null) ...[
  const SizedBox(height: 10),
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.lightbulb, color: Colors.blue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tip!,
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
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
}

class _RiskDonut extends StatelessWidget {
  const _RiskDonut({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0).toDouble();
    return CustomPaint(
      painter: _DonutPainter(v),
      child: Center(
        child: Text('${(v * 100).round()}%',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double v; _DonutPainter(this.v);

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

    canvas.drawCircle(center, radius, bg);
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

          final anchors = <String, Offset>{
            'left_shoulder_angle': pt(0.32, 0.28),
            'right_shoulder_angle': pt(0.68, 0.28),
            'left_knee_angle': pt(0.42, 0.78),
            'right_knee_angle': pt(0.58, 0.78),
          };

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/human_silhouette.png', fit: BoxFit.cover),
              ...anchors.entries.map((e) {
                final active = risky.contains(e.key);
                return Positioned(
                  left: e.value.dx - 7, top: e.value.dy - 7,
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
      width: 12, height: 12,
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
    this.xLabel = 'Window',
    this.yLabel = 'Risk',
  });

  final List<double> values;
  final double threshold;
  final int window;
  final int stride;
  final String xLabel;
  final String yLabel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimelinePainter(
        values: values,
        threshold: threshold,
        xLabel: xLabel,
        yLabel: yLabel,
      ),
    );
  }
}


class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.values,
    required this.threshold,
    required this.xLabel,
    required this.yLabel,
  });

  final List<double> values;
  final double threshold;
  final String xLabel;
  final String yLabel;


  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pad = 16.0;
    final chart = Rect.fromLTWH(rect.left + pad, rect.top + pad, rect.width - 2 * pad, rect.height - 2 * pad);

    final bg = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), bg);

    final axis = Paint()..color = const Color(0xFFE0E0E0)..strokeWidth = 1.2;
    canvas.drawLine(Offset(chart.left, chart.bottom), Offset(chart.right, chart.bottom), axis);
    canvas.drawLine(Offset(chart.left, chart.top), Offset(chart.left, chart.bottom), axis);

        // ---- Axis labels & ticks ----
    final labelStyle = TextStyle(
      color: const Color(0xFF616161),
      fontSize: 11,
    );

    // X label (centered under chart)
    _drawText(
      canvas,
      text: xLabel,
      style: labelStyle,
      offset: Offset(chart.left + chart.width / 2, rect.bottom - 4),
      anchor: Alignment.bottomCenter,
    );

    // Y label (rotated, centered on left)
    canvas.save();
    // rotate around a point left of the chart
    final yLabelCenter = Offset(rect.left + 6, chart.top + chart.height / 2);
    canvas.translate(yLabelCenter.dx, yLabelCenter.dy);
    canvas.rotate(-math.pi / 2);
    _drawText(
      canvas,
      text: yLabel,
      style: labelStyle,
      offset: Offset.zero,
      anchor: Alignment.center,
    );
    canvas.restore();

    // Simple Y ticks: 0.0, 0.5, 1.0
    for (final t in [0.0, 0.5, 1.0]) {
      final y = chart.bottom - chart.height * t;
      // small tick
      canvas.drawLine(Offset(chart.left - 6, y), Offset(chart.left, y), axis);
      _drawText(
        canvas,
        text: t.toStringAsFixed(1),
        style: labelStyle,
        offset: Offset(chart.left - 8, y),
        anchor: Alignment.centerRight,
      );
    }

    // X ticks: first and last window index (1..N)
    if (values.isNotEmpty) {
      final n = values.length;
      final x0 = chart.left;
      final xN = chart.right;
      canvas.drawLine(Offset(x0, chart.bottom), Offset(x0, chart.bottom + 6), axis);
      canvas.drawLine(Offset(xN, chart.bottom), Offset(xN, chart.bottom + 6), axis);
      _drawText(
        canvas,
        text: '1',
        style: labelStyle,
        offset: Offset(x0, chart.bottom + 8),
        anchor: Alignment.topCenter,
      );
      _drawText(
        canvas,
        text: '$n',
        style: labelStyle,
        offset: Offset(xN, chart.bottom + 8),
        anchor: Alignment.topCenter,
      );
    }


    if (values.isEmpty) return;

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + (chart.width * i / math.max(1, values.length - 1));
      final y = chart.bottom - (chart.height * values[i].clamp(0.0, 1.0));
      pts.add(Offset(x, y));
    }

    final thY = chart.bottom - (chart.height * threshold.clamp(0.0, 1.0));
    final thPaint = Paint()
      ..color = const Color(0xFFFFA000)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(chart.left, thY), Offset(chart.right, thY), thPaint);

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
    final line = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      ).createShader(chart)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);

    final dot = Paint()..color = const Color(0xFFf5576c);
    for (final p in pts) { if (p.dy <= thY) canvas.drawCircle(p, 3.5, dot); }
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
    );

// ---- Helper: slice the per-frame series for a given [start,end] window ----
List<double> _sliceSeriesForWindow(List<double> series, List<int> range) {
  final s = range[0].clamp(0, series.length - 1);
  final e = range[1].clamp(0, series.length - 1);
  if (e < s) return const [];
  return series.sublist(s, e + 1);
}

// ---- Tiny brand sparkline (used in bottom sheet table) ----
class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({
    required this.values,
    required this.lineStart,
    required this.lineEnd,
  });

  final List<double> values;
  final Color lineStart;
  final Color lineEnd;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniSparklinePainter(values, lineStart, lineEnd),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  _MiniSparklinePainter(this.values, this.a, this.b);
  final List<double> values;
  final Color a, b;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final rect = Offset.zero & size;
    final pad = 2.0;
    final chart = Rect.fromLTWH(
      rect.left + pad, rect.top + pad, rect.width - 2 * pad, rect.height - 2 * pad,
    );

    // normalize to 0..1 within min..max
    double minV = values.first, maxV = values.first;
    for (final v in values) { if (v < minV) minV = v; if (v > maxV) maxV = v; }
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * (i / math.max(1, values.length - 1));
      final yNorm = (values[i] - minV) / span;              // 0..1
      final y = chart.bottom - (chart.height * yNorm);      // invert
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }

    final line = Paint()
      ..shader = LinearGradient(colors: [a, b]).createShader(chart)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter old) =>
      old.values != values || old.a != a || old.b != b;
}



// Helper to paint text with alignment
void _drawText(
  Canvas canvas, {
  required String text,
  required TextStyle style,
  required Offset offset,
  Alignment anchor = Alignment.centerLeft,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = offset.dx - (tp.width  * (anchor.x + 1) / 2);
  final dy = offset.dy - (tp.height * (anchor.y + 1) / 2);
  tp.paint(canvas, Offset(dx, dy));
}
