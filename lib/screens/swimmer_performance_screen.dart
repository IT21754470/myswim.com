// lib/screens/swimmer_performance_screen.dart
// ignore_for_file: unused_shown_name, unnecessary_import, prefer_const_declarations, deprecated_member_use

import 'dart:ui' show FontFeature, TextDirection; // TextDirection needed for TextPainter
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Use the predictor screen and its transfer payload
import 'predict_best_finishing_time_screen.dart' as predict;

// Pull real data from your in-memory history store
import '../models/swim_history_store.dart';

/// ===== Brand palette =====
class BrandColors {
  static const background = Color(0xFFF7FAFC);
  static const primary    = Color(0xFF0E7C86);
  static const headerStart= Color(0xFF0E7C86);
  static const headerEnd  = Color(0xFF023047);
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

/// Picks vibrant gradient pairs per selection
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

/// ===== Time helpers (robust) =====
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

/// Fallback baselines (seconds) – used only when we have no history for “today”
const _defaultByDistance = <String, double>{
  '50m' : 36.0,
  '100m': 78.0,
  '200m': 165.0,
  '400m': 345.0,
};

/// ===== Prediction model (local fallback only for “Today” when no history) =====
class PredictionResult {
  final String timeText;
  final String confidenceText;
  PredictionResult(this.timeText, this.confidenceText);
}

Future<PredictionResult> predictBestTime({
  required DateTime raceDate,
  required String distance,
  required String stroke,
  double? waterTempC,
  double? humidityPct,
  String? bestTimeBaseline,
}) async {
  final baseSec = bestTimeBaseline != null && bestTimeBaseline.trim().isNotEmpty
      ? _timeStrToSeconds(bestTimeBaseline)
      : (_defaultByDistance[distance] ?? 90.0);

  double pred = baseSec.isNaN ? (_defaultByDistance[distance] ?? 90.0) : baseSec;

  // Future taper (up to ~1.5s over 14 days)
  final days = DateTime.now().difference(raceDate).inDays; // negative if future
  if (days < 0) {
    final ahead = (-days).clamp(0, 14);
    pred += -0.11 * ahead;
  }

  // Environment
  if (waterTempC != null) pred += (waterTempC - 27.0).abs() * 0.12;
  if (humidityPct != null && humidityPct > 60) pred += (humidityPct - 60) * 0.02;

  // Small stroke nudges
  if (stroke == 'Breaststroke') pred += 0.25;
  if (stroke == 'Butterfly') pred += 0.15;

  // Confidence
  int complete = 0;
  if (bestTimeBaseline != null && bestTimeBaseline.trim().isNotEmpty) complete++;
  if (waterTempC != null) complete++;
  if (humidityPct != null) complete++;
  final conf = switch (complete) { 3 => '±0.4s', 2 => '±0.6s', 1 => '±0.9s', _ => '±1.2s' };

  return PredictionResult(_secondsToTimeStr(pred), conf);
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

  DateTime selectedDate = DateTime.now();           // anchored by prediction
  String selectedDistance = '100m';                 // valid defaults
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
        selectedDate     = res.raceDate;   // anchor charts here
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
          const CircleAvatar(radius: 14, backgroundColor: Colors.white, child: Icon(Icons.person, size: 16, color: BrandColors.headerEnd)),
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
            anchorDate: selectedDate, // << anchor around chosen race date
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        selectedItemColor: BrandColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        ],
      ),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Profile', style: TextStyle(color: BrandColors.headline, fontSize: 16)));
}

/// ===== OVERVIEW (History-driven Past + History-driven Upcoming) =====
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
  int _pastEntriesCap = 7; // show last N records from history (not calendar days)
  bool _loading = false;

  // Today (anchored)
  DateTime? _todayDate;
  double? _todayPoint;
  String? _todayConf;

  // Past & upcoming (history-driven)
  List<double> _pastPoints = const [];
  List<DateTime> _pastDates = const [];
  List<double> _upcomingPoints = const [];
  List<DateTime> _upcomingDates = const [];

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

    final anchor = widget.anchorDate ?? DateTime.now();
    final startOfAnchor = _ymd(anchor);

    final history = List<TrainingSession>.from(SwimHistoryStore().items)
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

    // ===== “Today” (anchored) – prefer history (prediction > training), else fallback model
    _todayDate = startOfAnchor;
    double? todaySec;
    String? todayConf;

    final todays = history.where((s) {
      if (s.distance != widget.distance || s.stroke != widget.stroke) return false;
      final d = _ymd(s.sessionDate);
      return d == startOfAnchor;
    }).toList();

    if (todays.isNotEmpty) {
      // Prefer latest prediction for the day, else latest training
      todays.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final pred = todays.where((s) => s.isPrediction && (s.predictedTime ?? '').trim().isNotEmpty).toList();
      if (pred.isNotEmpty) {
        final s = _timeStrToSeconds(pred.first.predictedTime!);
        if (!s.isNaN && !s.isInfinite) { todaySec = s; todayConf = pred.first.confidence; }
      } else {
        final train = todays.where((s) => !s.isPrediction && (s.bestTimeText ?? '').trim().isNotEmpty).toList();
        if (train.isNotEmpty) {
          final s = _timeStrToSeconds(train.first.bestTimeText!);
          if (!s.isNaN && !s.isInfinite) todaySec = s;
        }
      }
    }

    if (todaySec == null) {
      // Fallback to model ONLY for today if no history
      final todayRes = await predictBestTime(
        raceDate: startOfAnchor,
        distance: widget.distance,
        stroke: widget.stroke,
        waterTempC: widget.envWater,
        humidityPct: widget.envHumidity,
        bestTimeBaseline: widget.baseline,
      );
      final ts = _timeStrToSeconds(todayRes.timeText);
      todaySec = (ts.isNaN || ts.isInfinite) ? (_defaultByDistance[widget.distance] ?? 90.0) : ts;
      todayConf = todayRes.confidenceText;
    }
    _todayPoint = todaySec;
    _todayConf = todayConf;

    // ===== PAST: Build strictly from History (prefer Prediction for a day; else Training). No model fill.
    final Map<DateTime, _DayBest> pastPerDay = {};
    for (final s in history) {
      if (s.distance != widget.distance || s.stroke != widget.stroke) continue;
      final d = _ymd(s.sessionDate);
      if (!d.isBefore(startOfAnchor)) continue; // past only

      final String raw = s.isPrediction ? (s.predictedTime ?? '') : (s.bestTimeText ?? '');
      final secs = _timeStrToSeconds(raw);
      if (secs.isNaN || secs.isInfinite) continue;

      final cur = pastPerDay[d];
      if (cur == null) {
        pastPerDay[d] = _DayBest(seconds: secs, isPrediction: s.isPrediction, createdAt: s.createdAt);
      } else {
        // Prefer prediction over training; if same type, take latest createdAt
        final replace = (s.isPrediction && !cur.isPrediction) ||
            (s.isPrediction == cur.isPrediction && s.createdAt.isAfter(cur.createdAt));
        if (replace) {
          pastPerDay[d] = _DayBest(seconds: secs, isPrediction: s.isPrediction, createdAt: s.createdAt);
        }
      }
    }
    var pastEntries = pastPerDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (pastEntries.length > _pastEntriesCap) {
      pastEntries = pastEntries.sublist(pastEntries.length - _pastEntriesCap);
    }
    final pastDates = pastEntries.map((e) => e.key).toList();
    final pastPts   = pastEntries.map((e) => e.value.seconds).toList();

    // ===== UPCOMING: Use only History predictions (latest per future day). No model fill.
    final Map<DateTime, _DayBest> futurePerDay = {};
    for (final s in history) {
      if (!s.isPrediction) continue;
      if (s.distance != widget.distance || s.stroke != widget.stroke) continue;
      final d = _ymd(s.sessionDate);
      if (!d.isAfter(startOfAnchor)) continue; // future only
      final secs = _timeStrToSeconds(s.predictedTime ?? '');
      if (secs.isNaN || secs.isInfinite) continue;

      final cur = futurePerDay[d];
      if (cur == null || s.createdAt.isAfter(cur.createdAt)) {
        futurePerDay[d] = _DayBest(seconds: secs, isPrediction: true, createdAt: s.createdAt);
      }
    }
    var futureEntries = futurePerDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (futureEntries.length > 7) {
      futureEntries = futureEntries.sublist(0, 7); // next 7 prediction dates
    }
    final upcomingDates = futureEntries.map((e) => e.key).toList();
    final futurePts     = futureEntries.map((e) => e.value.seconds).toList();

    if (!mounted) return;
    setState(() {
      _pastDates = pastDates;
      _pastPoints = pastPts;
      _upcomingDates = upcomingDates;
      _upcomingPoints = futurePts;
      _loading = false;
    });
  }

  String _chartDateLabel(DateTime d) => DateFormat('yyyy-MM-dd').format(d); // show actual dates on x-axis
  String _listDateLabel(DateTime d)  => DateFormat('EEE, dd MMM').format(d);

  @override
  Widget build(BuildContext context) {
    final accent = BrandTheme.accentFor(widget.distance, widget.stroke);

    // quick stats
    final pastStats = _Stats.fromPoints(_pastPoints);
    final upcStats  = _Stats.fromPoints(_upcomingPoints);

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
                onChanged: (v) => setState(() => widget.onChangeDistance(v)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChipDropdown<String>(
                label: 'Stroke',
                value: widget.stroke,
                items: const ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly'],
                onChanged: (v) => setState(() => widget.onChangeStroke(v)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ===== Today’s performance (history-preferred, else model) =====
        _loading
            ? const _TodaySkeleton()
            : TodayPerformanceCard(
                date: _todayDate ?? DateTime.now(),
                timeText: _secondsToTimeStr(_todayPoint ?? (_defaultByDistance[widget.distance] ?? 90.0)),
                distance: widget.distance,
                stroke: widget.stroke,
                confidence: _todayConf,
                colors: accent,
              ),

        const SizedBox(height: 16),

        // ===== Past performance (purely from History) =====
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Past performance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ToggleButtons(
              isSelected: [_pastEntriesCap == 7, _pastEntriesCap == 14],
              onPressed: (i) => setState(() => _pastEntriesCap = (i == 0 ? 7 : 14)),
              borderRadius: BorderRadius.circular(10),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 28),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('7')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('14')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        _loading
            ? const _ChartSkeleton()
            : PerformanceChartCard(
                dates: _pastDates,
                points: _pastPoints,
                labelForDay: _chartDateLabel, // 👈 actual dates, not Sun/Mon
                colors: accent,
                avgSeconds: pastStats.avg,
                highlightIndex: pastStats.minIndex,
                overlayLabel: pastStats.avg == null ? null : 'Avg ${_secondsToTimeStr(pastStats.avg!)}',
              ),
        if (!_loading) ...[
          const SizedBox(height: 8),
          _AnalysisBar(stats: pastStats, title: 'Last ${_pastDates.length} entries', accent: accent),
        ],

        const SizedBox(height: 20),

        // ===== Upcoming predictions (purely from History predictions) =====
        const Text('Upcoming (from saved predictions)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),

        _loading
            ? const _ChartSkeleton()
            : PerformanceChartCard(
                dates: _upcomingDates,
                points: _upcomingPoints,
                labelForDay: _chartDateLabel, // 👈 actual dates
                colors: accent,
                avgSeconds: upcStats.avg,
                highlightIndex: upcStats.minIndex,
                overlayLabel: upcStats.avg == null ? null : 'Avg ${_secondsToTimeStr(upcStats.avg!)}',
              ),
        if (!_loading) ...[
          const SizedBox(height: 8),
          _AnalysisBar(stats: upcStats, title: 'Next ${_upcomingDates.length} saved', accent: accent, isFuture: true),
        ],

        // LISTS
        const SizedBox(height: 12),
        if (!_loading)
          PerformanceListCard(
            dates: _pastDates,
            points: _pastPoints,
            dateLabelFor: _listDateLabel,
            timeHeader: 'Time (from History)',
            colors: accent,
          ),
        const SizedBox(height: 12),
        if (!_loading)
          PerformanceListCard(
            dates: _upcomingDates,
            points: _upcomingPoints,
            dateLabelFor: _listDateLabel,
            timeHeader: 'Predicted time',
            colors: accent,
          ),
      ],
    );
  }
}

class _DayBest {
  final double seconds;
  final bool isPrediction;
  final DateTime createdAt;
  _DayBest({required this.seconds, required this.isPrediction, required this.createdAt});
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
  final String distance;
  final String stroke;
  final String? confidence;
  final List<Color> colors;

  const TodayPerformanceCard({
    super.key,
    required this.date,
    required this.timeText,
    required this.distance,
    required this.stroke,
    required this.colors,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, dd MMM').format(date);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.first.withOpacity(0.15), colors.last.withOpacity(0.15)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.last.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today’s performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(timeText, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: colors.last)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: -6,
            children: [
              Chip(backgroundColor: colors.first.withOpacity(0.1), label: Text(dateStr)),
              Chip(backgroundColor: colors.first.withOpacity(0.1), label: Text('Distance: $distance')),
              Chip(backgroundColor: colors.first.withOpacity(0.1), label: Text('Stroke: $stroke')),
              if (confidence != null) Chip(backgroundColor: colors.first.withOpacity(0.1), label: Text('Confidence: $confidence')),
            ],
          ),
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

/// ===== Reusable CHART card with analysis overlay =====
class PerformanceChartCard extends StatelessWidget {
  final List<DateTime> dates;
  final List<double> points;
  final String Function(DateTime) labelForDay;
  final List<Color> colors;

  // Analysis overlays
  final double? avgSeconds;
  final int? highlightIndex;
  final String? overlayLabel;

  const PerformanceChartCard({
    super.key,
    required this.dates,
    required this.points,
    required this.labelForDay,
    required this.colors,
    this.avgSeconds,
    this.highlightIndex,
    this.overlayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final n = dates.length;
    final safePoints = points.length == n ? points : List<double>.filled(n, 0);

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
            height: 120,
            child: CustomPaint(
              painter: _SimpleChartPainter(
                points: safePoints,
                startColor: colors.first,
                endColor: colors.last,
                avgSeconds: avgSeconds,
                highlightIndex: highlightIndex,
                overlayLabel: overlayLabel,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(n, (i) => Text(labelForDay(dates[i]))),
          ),
        ],
      ),
    );
  }
}

/// Painter for a simple line chart with gradient + soft area + average line + fastest marker
class _SimpleChartPainter extends CustomPainter {
  final List<double> points;
  final Color startColor;
  final Color endColor;

  final double? avgSeconds;
  final int? highlightIndex;
  final String? overlayLabel;

  _SimpleChartPainter({
    required this.points,
    required this.startColor,
    required this.endColor,
    this.avgSeconds,
    this.highlightIndex,
    this.overlayLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Card bg
    final bg = Paint()..color = const Color(0xFFF2F6FA);
    final border = Paint()
      ..color = const Color(0xFFE0E6ED)
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(rrect, border);

    if (points.isEmpty) return;

    final cleaned = points.map((p) => (p.isNaN || p.isInfinite) ? points.first : p).toList();

    const pad = 12.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final origin = Offset(pad, pad + h);

    double minVal = cleaned.reduce((a, b) => a < b ? a : b);
    double maxVal = cleaned.reduce((a, b) => a > b ? a : b);
    if (minVal == maxVal) { minVal -= 0.5; maxVal += 0.5; }
    final span = (maxVal - minVal);
    final stepX = cleaned.length > 1 ? w / (cleaned.length - 1) : 0;

    double yFor(double value) {
      final norm = 1 - ((value - minVal) / span);
      return origin.dy - norm * h;
    }

    final lineGradient = LinearGradient(colors: [startColor, endColor]);
    final fillGradient = LinearGradient(colors: [startColor.withOpacity(0.18), endColor.withOpacity(0.05)]);

    final line = Paint()
      ..shader = lineGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < cleaned.length; i++) {
      final x = origin.dx + i * stepX;
      final y = yFor(cleaned[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, origin.dy);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(origin.dx + (cleaned.length - 1) * stepX, origin.dy);
    fillPath.close();

    // Draw area then line
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);

    // Average line overlay
    if (avgSeconds != null) {
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
//textDirection: TextDirection.LTR, // ✅ required
        )..layout();
        tp.paint(canvas, Offset(pad + w - tp.width, y - tp.height - 2));
      }
    }

    // Dots
    final dot = Paint()..color = endColor..style = PaintingStyle.fill;
    final dotHighlight = Paint()..color = endColor.withOpacity(0.9)..style = PaintingStyle.fill;
    for (int i = 0; i < cleaned.length; i++) {
      final x = origin.dx + i * stepX;
      final y = yFor(cleaned[i]);
      canvas.drawCircle(Offset(x, y), (highlightIndex == i ? 4.2 : 3.0), highlightIndex == i ? dotHighlight : dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleChartPainter old) {
    if (old.points.length != points.length) return true;
    if (old.startColor != startColor || old.endColor != endColor) return true;
    if (old.avgSeconds != avgSeconds || old.highlightIndex != highlightIndex || old.overlayLabel != overlayLabel) return true;
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

  const _AnalysisBar({required this.stats, required this.title, required this.accent, this.isFuture = false});

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
                  label: Text(
                    isFuture
                        ? 'Trend: ${trend.toStringAsFixed(2)}s/day'
                        : 'Trend: ${trend.toStringAsFixed(2)}s/day',
                    style: TextStyle(color: arrowColor),
                  ),
                  backgroundColor: arrowColor.withOpacity(.10),
                  side: BorderSide(color: arrowColor.withOpacity(.35)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Reusable LIST card (date + time) =====
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
    final safePoints = points.length == n ? points : List<double>.filled(n, 0);

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
              final timeStr = _secondsToTimeStr(safePoints[i]);
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

/// ===== Small UI blocks =====
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
    // Fallback if value isn’t in items (prevents DropdownButton crash)
    final T effectiveValue =
        (items.contains(value) ? value : (items.isNotEmpty ? items.first : value));

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
