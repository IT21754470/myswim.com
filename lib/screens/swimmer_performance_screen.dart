// ignore_for_file: unused_shown_name, unnecessary_import, prefer_const_declarations, deprecated_member_use

import 'dart:ui' show FontFeature, TextDirection; // Needed for TextPainter
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 added

import 'predict_best_finishing_time_screen.dart' as predict;
import '../models/swim_history_store.dart';

/// ===== Brand palette (more colorful) =====
class BrandColors {
  static const background = Color(0xFFF9FBFF);
  static const primary    = Color(0xFF0E7C86);

  static const headerStart= Color(0xFF06B6D4);
  static const headerEnd  = Color(0xFF6366F1);

  static const headline   = Color(0xFF0F172A);
  static const infoSurface= Color(0xFFE6FFFB);

  static const tile1Start = Color(0xFF00B4D8);
  static const tile1End   = Color(0xFF0077B6);
  static const tile2Start = Color(0xFFFF7A59);
  static const tile2End   = Color(0xFFF4A261);
  static const tile3Start = Color(0xFF6D28D9);
  static const tile3End   = Color(0xFF8B5CF6);
  static const tile4Start = Color(0xFF14B8A6);
  static const tile4End   = Color(0xFF0EA5E9);
}

class BrandTheme {
  static List<Color> accentFor(String distance, String stroke) {
    switch (distance) {
      case '50m':  return const [BrandColors.tile1Start, BrandColors.tile1End];
      case '100m': return const [BrandColors.tile2Start, BrandColors.tile2End];
      case '200m': return const [BrandColors.tile3Start, BrandColors.tile3End];
      case '400m': return const [BrandColors.tile4Start, BrandColors.tile4End];
      default:     return const [BrandColors.primary, BrandColors.headerEnd];
    }
  }
}

/// ===== Time helpers =====
double _timeStrToSeconds(String s) {
  final t = s.trim();
  if (t.isEmpty || t == '—') return double.nan;
  final colon = t.indexOf(':');
  try {
    if (colon >= 0) {
      final mm = int.parse(t.substring(0, colon));
      final sec = double.parse(t.substring(colon + 1));
      return mm * 60 + sec;
    } else {
      return double.parse(t);
    }
  } catch (_) {
    return double.nan;
  }
}

String _secondsToTimeStr(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return '—';
  if (seconds < 0) seconds = 0;
  final mm = seconds ~/ 60;
  final ss = seconds % 60;
  return '${mm.toString().padLeft(2, '0')}:${ss.toStringAsFixed(2).padLeft(5, '0')}';
}

/// ===== ENTRY WIDGET =====
class SwimmerPerformanceScreen extends StatefulWidget {
  const SwimmerPerformanceScreen({super.key, this.userName});
  final String? userName;

  @override
  State<SwimmerPerformanceScreen> createState() => _SwimmerPerformanceScreenState();
}

class _SwimmerPerformanceScreenState extends State<SwimmerPerformanceScreen> {
  int _index = 1;

  DateTime selectedDate = DateTime.now();
  String selectedDistance = '100m';
  String selectedStroke   = 'Freestyle';

  String? bestTimeBaseline;
  double? lastWaterTemp;
  double? lastHumidity;

  Future<void> _openPredict() async {
    final res = await Navigator.of(context).push<predict.PredictionTransfer>(
      MaterialPageRoute(builder: (_) => const predict.PredictBestFinishingTimeScreen()),
    );
    if (res != null) {
      setState(() {
        selectedDate     = res.raceDate;
        selectedDistance = res.distance;
        selectedStroke   = res.stroke;
        bestTimeBaseline = res.baseline;
        lastWaterTemp    = res.waterTemp;
        lastHumidity     = res.humidity;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // 🔒 If not signed in, don't show any history
    if (uid == null) {
      return Scaffold(
        backgroundColor: BrandColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [BrandColors.headerStart, BrandColors.headerEnd]),
            ),
          ),
          title: const Text('Swimmer Performance', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Sign in to view your performance.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    final name = (widget.userName ?? '').trim().isNotEmpty ? widget.userName!.trim() : 'Swimmer';
    final headerGrad = const LinearGradient(colors: [BrandColors.headerStart, BrandColors.headerEnd]);

    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: headerGrad)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          const CircleAvatar(radius: 14, backgroundColor: Colors.white, child: Icon(Icons.person, size: 16, color: Colors.indigo)),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: Colors.white)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.trending_up, color: Colors.white),
            tooltip: 'Predict best time',
            onPressed: _openPredict,
          ),
          const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.notifications_outlined, color: Colors.white)),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const _ProfilePlaceholder(),
          _OverviewTab(
            onChangeDistance: (v) => setState(() => selectedDistance = v),
            onChangeStroke: (v) => setState(() => selectedStroke = v),
            distance: selectedDistance,
            stroke: selectedStroke,
            baseline: bestTimeBaseline,
            envWater: lastWaterTemp,
            envHumidity: lastHumidity,
            anchorDate: selectedDate,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        selectedItemColor: BrandColors.headerEnd,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        ],
      ),
      // ⛔ FAB intentionally omitted
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Profile', style: TextStyle(color: BrandColors.headline, fontSize: 16)));
}

/// ===== OVERVIEW =====
class _OverviewTab extends StatefulWidget {
  final String distance;
  final String stroke;
  final String? baseline;
  final double? envWater;
  final double? envHumidity;
  final ValueChanged<String> onChangeDistance;
  final ValueChanged<String> onChangeStroke;
  final DateTime? anchorDate;

  const _OverviewTab({
    required this.distance,
    required this.stroke,
    required this.onChangeDistance,
    required this.onChangeStroke,
    this.baseline,
    this.envWater,
    this.envHumidity,
    this.anchorDate,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _loading = false;

  DateTime? _todayDate;
  double? _todayPoint;

  List<double> _pastPoints = const [];
  List<DateTime> _pastDates = const [];
  List<double> _upcomingPoints = const [];
  List<DateTime> _upcomingDates = const [];

  double? _bestEver; // best predicted time across history for this distance/stroke

  @override
  void initState() {
    super.initState();
    SwimHistoryStore().addListener(_onStoreChange);
    _rebuild();
  }

  @override
  void dispose() {
    SwimHistoryStore().removeListener(_onStoreChange);
    super.dispose();
  }

  void _onStoreChange() {
    if (mounted) _rebuild();
  }

  @override
  void didUpdateWidget(covariant _OverviewTab old) {
    super.didUpdateWidget(old);
    if (old.distance != widget.distance ||
        old.stroke != widget.stroke ||
        old.baseline != widget.baseline ||
        old.envWater != widget.envWater ||
        old.envHumidity != widget.envHumidity ||
        old.anchorDate != widget.anchorDate) {
      _rebuild();
    }
  }

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _rebuild() async {
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // If no user, clear everything quickly
    if (uid == null) {
      setState(() {
        _todayDate = _ymd(widget.anchorDate ?? DateTime.now());
        _todayPoint = null;
        _pastDates = List.generate(7, (i) => _todayDate!.subtract(Duration(days: 7 - i)));
        _pastPoints = List.filled(7, double.nan);
        _upcomingDates = List.generate(7, (i) => _todayDate!.add(Duration(days: i + 1)));
        _upcomingPoints = List.filled(7, double.nan);
        _bestEver = null;
        _loading = false;
      });
      return;
    }

    final anchor = widget.anchorDate ?? DateTime.now();
    final startOfAnchor = _ymd(anchor);

    // 👇 STRICT: use only this user's items
    final allMine = SwimHistoryStore()
        .items
        .where((s) => s.swimmerId == uid)
        .toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

    // Filter to this distance/stroke & predictions
    final filtered = allMine.where((s) =>
      s.isPrediction && s.distance == widget.distance && s.stroke == widget.stroke).toList();

    // Best Ever across history for this distance/stroke (mine only)
    final allTimes = filtered
        .map((s) => _timeStrToSeconds(s.predictedTime ?? ''))
        .where((v) => !v.isNaN && !v.isInfinite)
        .toList();
    _bestEver = allTimes.isNotEmpty ? allTimes.reduce((a, b) => a < b ? a : b) : null;

    // Today (anchored)
    _todayDate = startOfAnchor;
    _todayPoint = null;
    final todays = filtered.where((s) => _ymd(s.sessionDate) == startOfAnchor).toList();
    if (todays.isNotEmpty) {
      todays.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final v = _timeStrToSeconds(todays.first.predictedTime ?? '');
      if (!v.isNaN && !v.isInfinite) _todayPoint = v;
    }

    // Past 7 calendar days: anchor-7 .. anchor-1
    final pastStart = startOfAnchor.subtract(const Duration(days: 7));
    final pastDates = List.generate(7, (i) => pastStart.add(Duration(days: i)));
    final pastPts = <double>[];
    for (final day in pastDates) {
      final m = filtered.where((s) => _ymd(s.sessionDate) == day);
      if (m.isNotEmpty) {
        final latest = m.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
        pastPts.add(_timeStrToSeconds(latest.predictedTime ?? ''));
      } else {
        pastPts.add(double.nan);
      }
    }

    // Upcoming 7 days: anchor+1 .. anchor+7
    final upcDates = List.generate(7, (i) => startOfAnchor.add(Duration(days: i + 1)));
    final upcPts = <double>[];
    for (final d in upcDates) {
      final m = filtered.where((s) => _ymd(s.sessionDate) == d);
      if (m.isNotEmpty) {
        final latest = m.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
        upcPts.add(_timeStrToSeconds(latest.predictedTime ?? ''));
      } else {
        upcPts.add(double.nan);
      }
    }

    if (!mounted) return;
    setState(() {
      _pastDates = pastDates;
      _pastPoints = pastPts;
      _upcomingDates = upcDates;
      _upcomingPoints = upcPts;
      _loading = false;
    });
  }

  String _chartDateLabel(DateTime d) => DateFormat('MM-dd').format(d);
  String _listDateLabel(DateTime d)  => DateFormat('EEE, dd MMM').format(d);

  @override
  Widget build(BuildContext context) {
    final accent = BrandTheme.accentFor(widget.distance, widget.stroke);

    final pastClean = _pastPoints.where((v) => !v.isNaN && !v.isInfinite).toList();
    final pastStats = _Stats.fromPoints(pastClean);
    final upcStats  = _Stats.fromPoints(_upcomingPoints.where((v) => !v.isNaN && !v.isInfinite).toList());

    final double firstValidUpcoming = _upcomingPoints.firstWhere(
      (v) => !(v.isNaN || v.isInfinite),
      orElse: () => double.nan,
    );
    final bool hasNext = !(firstValidUpcoming.isNaN || firstValidUpcoming.isInfinite);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // selectors
        Row(
          children: [
            Expanded(
              child: _ChipDropdown<String>(
                label: 'Distance',
                value: widget.distance,
                items: const ['50m', '100m', '200m', '400m'],
                onChanged: (v) => widget.onChangeDistance(v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChipDropdown<String>(
                label: 'Stroke',
                value: widget.stroke,
                items: const ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly'],
                onChanged: (v) => widget.onChangeStroke(v),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Today
        _loading
            ? const _TodaySkeleton()
            : (_todayPoint == null)
                ? _EmptyTodayCard(
                    date: _todayDate ?? DateTime.now(),
                    colors: accent,
                    onTapPredict: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const predict.PredictBestFinishingTimeScreen()),
                    ),
                  )
                : TodayPerformanceCard(
                    date: _todayDate ?? DateTime.now(),
                    timeText: _secondsToTimeStr(_todayPoint!),
                    colors: accent,
                  ),

        const SizedBox(height: 16),

        // Past 7 days
        _SectionHeader(text: 'Past 7 days (predictions)', colors: accent),
        const SizedBox(height: 8),
        _loading
            ? const _ChartSkeleton()
            : PerformanceChartCard(
                dates: _pastDates,
                points: _pastPoints,
                labelForDay: _chartDateLabel,
                colors: accent,
                avgSeconds: pastStats.avg, // overlay = average of past
                highlightIndex: pastStats.minIndex,
                overlayLabel: pastStats.avg == null ? null : 'Avg ${_secondsToTimeStr(pastStats.avg!)}',
                showValueLabels: false,
              ),
        if (!_loading) ...[
          const SizedBox(height: 8),
          _AnalysisBar(
            stats: pastStats,
            title: 'Last ${_pastDates.length} days',
            accent: accent,
            bestEverSeconds: _bestEver,
          ),
          // 👇 Row-by-row list for Past 7 days
          const SizedBox(height: 8),
          PerformanceListCard(
            dates: _pastDates,
            points: _pastPoints,
            dateLabelFor: _listDateLabel,
            timeHeader: 'Predicted',
            colors: accent,
          ),
        ],

        const SizedBox(height: 20),

        // Upcoming 7 days — BEST line + value labels
        _SectionHeader(text: 'Upcoming 7 days (saved predictions)', colors: accent),
        const SizedBox(height: 8),
        _loading
            ? const _ChartSkeleton()
            : PerformanceChartCard(
                dates: _upcomingDates,
                points: _upcomingPoints,
                labelForDay: _chartDateLabel,
                colors: accent,
                // Use overlay to show BEST line (not avg) on the upcoming chart
                avgSeconds: _bestEver,
                highlightIndex: upcStats.minIndex,
                overlayLabel: (_bestEver == null) ? null : 'Best ${_secondsToTimeStr(_bestEver!)}',
                showValueLabels: true,
                valueLabelForPoint: (v) => _secondsToTimeStr(v),
              ),
        if (!_loading) ...[
          const SizedBox(height: 8),
          _AnalysisBar(
            stats: upcStats,
            title: 'Next ${_upcomingDates.length} days',
            accent: accent,
            isFuture: true,
            predictedSeconds: hasNext ? firstValidUpcoming : null,
            bestEverSeconds: _bestEver,
          ),
          // 👇 Row-by-row list for Upcoming 7 days
          const SizedBox(height: 8),
          PerformanceListCard(
            dates: _upcomingDates,
            points: _upcomingPoints,
            dateLabelFor: _listDateLabel,
            timeHeader: 'Predicted',
            colors: accent,
          ),
        ],
      ],
    );
  }
}

/// Simple stats/calcs for analysis bars
class _Stats {
  final double? min;
  final int? minIndex;
  final double? max;
  final double? avg;
  final double? trendPerDay; // negative = improving (faster)

  _Stats({this.min, this.minIndex, this.max, this.avg, this.trendPerDay});

  static _Stats fromPoints(List<double> pts) {
    if (pts.isEmpty) return _Stats();
    double min = pts.first, max = pts.first, sum = 0;
    int minIdx = 0;
    for (int i = 0; i < pts.length; i++) {
      final v = pts[i];
      if (v < min) { min = v; minIdx = i; }
      if (v > max) max = v;
      sum += v;
    }
    final avg = sum / pts.length;

    // linear regression slope (index vs value)
    final n = pts.length;
    double sx = 0, sy = 0, sxy = 0, sxx = 0;
    for (int i = 0; i < n; i++) {
      sx += i;
      sy += pts[i];
      sxy += i * pts[i];
      sxx += i * i;
    }
    final denom = n * sxx - sx * sx;
    final slope = denom == 0 ? 0.0 : (n * sxy - sx * sy) / denom;

    return _Stats(min: min, minIndex: minIdx, max: max, avg: avg, trendPerDay: slope);
  }
}

/// ===== Today Performance Card =====
class TodayPerformanceCard extends StatelessWidget {
  final DateTime date;
  final String timeText;
  final List<Color> colors;

  const TodayPerformanceCard({
    super.key,
    required this.date,
    required this.timeText,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, dd MMM').format(date);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.first.withOpacity(0.18), colors.last.withOpacity(0.14)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.last.withOpacity(0.35)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 60,
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today’s performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(timeText, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: colors.last)),
                const SizedBox(height: 4),
                Text(dateStr, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const Icon(Icons.bolt_rounded, color: Colors.amber),
        ],
      ),
    );
  }
}

class _EmptyTodayCard extends StatelessWidget {
  final DateTime date;
  final List<Color> colors;
  final VoidCallback onTapPredict;
  const _EmptyTodayCard({required this.date, required this.colors, required this.onTapPredict});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, dd MMM').format(date);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.first.withOpacity(0.12), colors.last.withOpacity(0.10)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.last.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text('No prediction saved for $dateStr.\nTap “Predict” to add one.',
                style: const TextStyle(color: Colors.black87)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: onTapPredict,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.last,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.speed),
            label: const Text('Predict'),
          )
        ],
      ),
    );
  }
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// ===== Section header =====
class _SectionHeader extends StatelessWidget {
  final String text;
  final List<Color> colors;
  const _SectionHeader({required this.text, required this.colors});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.first.withOpacity(0.16), colors.last.withOpacity(0.16)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timeline, color: colors.last),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: colors.last)),
        ],
      ),
    );
  }
}

/// ===== Reusable CHART card with analysis overlay =====
class PerformanceChartCard extends StatelessWidget {
  final List<DateTime> dates;
  final List<double> points;
  final String Function(DateTime) labelForDay;
  final List<Color> colors;

  // Analysis overlays (generic)
  final double? avgSeconds;     // used as overlay line value (avg OR best, depending where used)
  final int? highlightIndex;
  final String? overlayLabel;

  // Optional value labels on points
  final bool showValueLabels;
  final String Function(double)? valueLabelForPoint;

  // Height control
  final double height;

  const PerformanceChartCard({
    super.key,
    required this.dates,
    required this.points,
    required this.labelForDay,
    required this.colors,
    this.avgSeconds,
    this.highlightIndex,
    this.overlayLabel,
    this.showValueLabels = false,
    this.valueLabelForPoint,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final n = dates.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: CustomPaint(
              painter: _SimpleChartPainter(
                points: points,
                startColor: colors.first,
                endColor: colors.last,
                avgSeconds: avgSeconds,
                highlightIndex: highlightIndex,
                overlayLabel: overlayLabel,
                showValueLabels: showValueLabels,
                valueLabelForPoint: valueLabelForPoint,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(n, (i) => Text(labelForDay(dates[i]), style: const TextStyle(fontSize: 11))),
          ),
        ],
      ),
    );
  }
}

/// Painter for line chart with NaN-safe rendering + overlay line + value labels
class _SimpleChartPainter extends CustomPainter {
  final List<double> points;
  final Color startColor;
  final Color endColor;

  final double? avgSeconds; // generic overlay value (avg or best)
  final int? highlightIndex;
  final String? overlayLabel;

  final bool showValueLabels;
  final String Function(double)? valueLabelForPoint;

  _SimpleChartPainter({
    required this.points,
    required this.startColor,
    required this.endColor,
    this.avgSeconds,
    this.highlightIndex,
    this.overlayLabel,
    this.showValueLabels = false,
    this.valueLabelForPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Compute min/max on valid values only
    final validVals = points.where((p) => !(p.isNaN || p.isInfinite)).toList();
    if (validVals.isEmpty) return;

    const pad = 12.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final origin = Offset(pad, pad + h);

    double minVal = validVals.reduce((a, b) => a < b ? a : b);
    double maxVal = validVals.reduce((a, b) => a > b ? a : b);
    if (minVal == maxVal) { minVal -= 0.5; maxVal += 0.5; }
    final span = maxVal - minVal;
    final stepX = points.length > 1 ? w / (points.length - 1) : 0;

    double yFor(double value) {
      final norm = 1 - ((value - minVal) / span);
      return origin.dy - norm * h;
    }

    // Build segments (skip NaNs)
    final linePaint = Paint()
      ..shader = LinearGradient(colors: [startColor, endColor]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Path? segPath;

    for (int i = 0; i < points.length; i++) {
      final x = origin.dx + i * stepX;
      final v = points[i];
      if (v.isNaN || v.isInfinite) {
        if (segPath != null) {
          canvas.drawPath(segPath, linePaint);
          segPath = null;
        }
        continue;
      }
      final y = yFor(v);
      if (segPath == null) {
        segPath = Path()..moveTo(x, y);
      } else {
        segPath.lineTo(x, y);
      }
    }
    if (segPath != null) {
      canvas.drawPath(segPath, linePaint);
    }

    // Overlay line (avg or best)
    if (avgSeconds != null && !(avgSeconds!.isNaN || avgSeconds!.isInfinite)) {
      final y = yFor(avgSeconds!);
      final avgPaint = Paint()
        ..color = endColor.withOpacity(0.35)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(pad, y), Offset(pad + w, y), avgPaint);

      if (overlayLabel != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: overlayLabel!,
            style: TextStyle(color: endColor.withOpacity(0.7), fontSize: 10),
          ),
          //textDirection: TextDirection.ltr, // ✅ ensure safe on all channels
        )..layout();
        tp.paint(canvas, Offset(pad + w - tp.width, y - tp.height - 2));
      }
    }

    // Dots
    final dot = Paint()..color = endColor..style = PaintingStyle.fill;
    final dotHighlight = Paint()..color = endColor.withOpacity(0.9)..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      final v = points[i];
      if (v.isNaN || v.isInfinite) continue;
      final x = origin.dx + i * stepX;
      final y = yFor(v);
      canvas.drawCircle(Offset(x, y), (highlightIndex == i ? 4.2 : 3.0), highlightIndex == i ? dotHighlight : dot);
    }

    // Value labels above each valid point
    if (showValueLabels && valueLabelForPoint != null) {
      for (int i = 0; i < points.length; i++) {
        final v = points[i];
        if (v.isNaN || v.isInfinite) continue;
        final x = origin.dx + i * stepX;
        final y = yFor(v);

        final label = valueLabelForPoint!(v);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 10,
              color: endColor.withOpacity(0.85),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          //textDirection: TextDirection.ltr, // ✅ ensure safe on all channels
          maxLines: 1,
        )..layout();

        final dx = (x - tp.width / 2).clamp(pad, pad + w - tp.width);
        final dy = (y - tp.height - 6).clamp(pad, pad + h - tp.height);
        tp.paint(canvas, Offset(dx as double, dy as double));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleChartPainter old) {
    if (old.points.length != points.length) return true;
    if (old.startColor != startColor || old.endColor != endColor) return true;
    if (old.avgSeconds != avgSeconds || old.highlightIndex != highlightIndex || old.overlayLabel != overlayLabel) return true;
    if (old.showValueLabels != showValueLabels) return true;
    for (int i = 0; i < points.length; i++) {
      if (old.points[i] != points[i]) return true;
    }
    return false;
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// ===== Compact stats/analysis bar =====
class _AnalysisBar extends StatelessWidget {
  final _Stats stats;
  final String title;
  final List<Color> accent;
  final bool isFuture;

  /// Optional chips
  final double? predictedSeconds; // nearest upcoming valid point
  final double? bestEverSeconds;

  const _AnalysisBar({
    required this.stats,
    required this.title,
    required this.accent,
    this.isFuture = false,
    this.predictedSeconds,
    this.bestEverSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final trend = stats.trendPerDay ?? 0;
    final trendGood = trend < 0; // down = faster
    final arrow = trendGood ? Icons.south_east : Icons.north_east;
    final arrowColor = trendGood ? Colors.green.shade600 : Colors.red.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(width: 6, height: 18, decoration: BoxDecoration(gradient: LinearGradient(colors: accent), borderRadius: BorderRadius.circular(6))),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: -6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (stats.min != null) Chip(label: Text('Best: ${_secondsToTimeStr(stats.min!)}')),
                if (stats.avg != null) Chip(label: Text('Avg: ${_secondsToTimeStr(stats.avg!)}')),
                if (stats.max != null) Chip(label: Text('Slowest: ${_secondsToTimeStr(stats.max!)}')),
                Chip(
                  avatar: Icon(arrow, size: 16, color: arrowColor),
                  label: Text('Trend: ${trend.toStringAsFixed(2)}s/day', style: TextStyle(color: arrowColor)),
                  backgroundColor: arrowColor.withOpacity(.10),
                  side: BorderSide(color: arrowColor.withOpacity(.35)),
                ),
                if (bestEverSeconds != null)
                  Chip(
                    label: Text('Best Ever: ${_secondsToTimeStr(bestEverSeconds!)}'),
                    backgroundColor: Colors.indigo.withOpacity(.08),
                    side: BorderSide(color: Colors.indigo.withOpacity(.35)),
                  ),
                if (predictedSeconds != null && !(predictedSeconds!.isNaN || predictedSeconds!.isInfinite))
                  Chip(
                    label: Text('Predicted: ${_secondsToTimeStr(predictedSeconds!)}'),
                    backgroundColor: Colors.deepPurple.withOpacity(.08),
                    side: BorderSide(color: Colors.deepPurple.withOpacity(.35)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Reusable LIST card =====
class PerformanceListCard extends StatelessWidget {
  final List<DateTime> dates;
  final List<double> points;
  final String Function(DateTime) dateLabelFor;
  final String timeHeader;
  final List<Color> colors;

  const PerformanceListCard({
    super.key,
    required this.dates,
    required this.points,
    required this.dateLabelFor,
    required this.timeHeader,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final n = dates.length;
    final safePoints = points.length == n ? points : List<double>.filled(n, double.nan);

    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          // gradient header bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colors.first.withOpacity(0.15), colors.last.withOpacity(0.15)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Text(timeHeader, style: TextStyle(fontWeight: FontWeight.w700, color: colors.last)),
              ],
            ),
          ),
          const Divider(height: 1),
          // items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: n,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final dateStr = dateLabelFor(dates[i]);
              final seconds = safePoints[i];
              final timeStr = (seconds.isNaN || seconds.isInfinite) ? '—' : _secondsToTimeStr(seconds);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12),
                child: Row(
                  children: [
                    // left accent pill
                    Container(width: 6, height: 18, decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(6))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(dateStr)),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(color: colors.last, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// ===== Dropdown with label container =====
class _ChipDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;

  const _ChipDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Fallback if value isn’t in items (prevents Dropdown crash)
    final T effectiveValue = (items.contains(value) ? value : (items.isNotEmpty ? items.first : value));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        DropdownButton<T>(
          isExpanded: true,
          value: effectiveValue,
          underline: const SizedBox.shrink(),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ]),
    );
  }
}
