// ignore_for_file: deprecated_member_use, sort_child_properties_last, no_leading_underscores_for_local_identifiers, prefer_const_constructors, unnecessary_import
import 'dart:ui' show FontFeature;
import 'dart:convert'; // <-- added for http json decode
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; // <-- added for location
import 'package:http/http.dart' as http; // <-- added for Open-Meteo requests

// 🔌 Firebase identity + data
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// In-app history store
import '../models/swim_history_store.dart';

// Your models
import '../models/user_profile.dart';

// 🔌 Backend prediction service (singleton: predictionService)
import '../services/prediction_service.dart';
import '../services/env_service.dart';

/// ---- Vibrant Palette
class BrandColors {
  static const headline = Color(0xFF0F172A);

  // Primary “ocean rainbow” swatch
  static const aqua = Color(0xFF06B6D4);
  static const teal = Color(0xFF14B8A6);
  static const blue = Color(0xFF3B82F6);
  static const indigo = Color(0xFF6366F1);
  static const violet = Color(0xFF8B5CF6);
  static const coral = Color(0xFFFF7A59);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const raspberry = Color(0xFFEF4444);

  // Light tints
  static const surface = Color(0xFFFFFFFF);
  static const surfaceTint = Color(0xFFF6FAFF);
  static const border = Color(0xFFE2E8F0);

  // Distance-based accents (for gradients)
  static const tile1Start = Color(0xFF00B4D8);
  static const tile1End = Color(0xFF0077B6);
  static const tile2Start = Color(0xFFFF7A59);
  static const tile2End = Color(0xFFF4A261);
  static const tile3Start = Color(0xFF6D28D9);
  static const tile3End = Color(0xFF8B5CF6);
  static const tile4Start = Color(0xFF14B8A6);
  static const tile4End = Color(0xFF0EA5E9);
}

class BrandTheme {
  static List<Color> accentFor(String distance, [String? _]) {
    switch (distance) {
      case '50m':
        return const [BrandColors.tile1Start, BrandColors.tile1End];
      case '100m':
        return const [BrandColors.tile2Start, BrandColors.tile2End];
      case '200m':
        return const [BrandColors.tile3Start, BrandColors.tile3End];
      case '400m':
        return const [BrandColors.tile4Start, BrandColors.tile4End];
      default:
        return const [BrandColors.aqua, BrandColors.blue];
    }
  }

  static const backgroundGradient = [
  Color(0xFFF4FAFF),
  Color(0xFFE9F6FF),
  Color(0xFFDDF3FF),
];

}

extension ColorUtils on Color {
  /// Returns a darker variant of this color by the given [amount] (0.0-1.0).
  /// Example: color.darken(0.15) reduces lightness by 15%.
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDarker = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0) as double);
    return hslDarker.toColor();
  }
}

/// ---- Time helpers
double _timeStrToSeconds(String s) {
  final t = s.trim();
  if (t.isEmpty || t == '—') return double.nan;
  final i = t.indexOf(':');
  try {
    if (i >= 0) {
      final mm = int.parse(t.substring(0, i));
      final ss = double.parse(t.substring(i + 1));
      return mm * 60 + ss;
    }
    return double.parse(t);
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

int _distanceLabelToMeters(String d) {
  switch (d) {
    case '50m':
      return 50;
    case '100m':
      return 100;
    case '200m':
      return 200;
    case '400m':
      return 400;
    default:
      return 100;
  }
}

DateTime? _parseDate(dynamic dateValue) {
  if (dateValue == null) return null;
  if (dateValue is String) {
    try {
      return DateTime.parse(dateValue);
    } catch (_) {
      return null;
    }
  }
  if (dateValue is Timestamp) {
    return dateValue.toDate();
  }
  return null;
}

const _defaultByDistance = <String, double>{
  '50m': 36,
  '100m': 78,
  '200m': 165,
  '400m': 345
};

/// ---- Progress status
class _Status {
  final String label;
  final Color color;
  final IconData icon;
  const _Status(this.label, this.color, this.icon);
}

// ✅ Updated thresholds
_Status _progressStatus(double deltaSeconds, String distance) {
  if (deltaSeconds.isNaN || deltaSeconds.isInfinite) {
    return const _Status('No baseline', BrandColors.amber, Icons.thumbs_up_down_rounded);
  }

  double dead, good, bad;
  switch (distance) {
    case '50m':
      dead = 0.10; good = -0.20; bad = 0.40; break;
    case '100m':
      dead = 0.20; good = -0.30; bad = 0.60; break;
    case '200m':
      dead = 0.35; good = -0.70; bad = 1.30; break;
    case '400m':
      dead = 0.60; good = -1.40; bad = 2.40; break;
    default:
      dead = 0.20; good = -0.30; bad = 0.60;
  }

  if (deltaSeconds.abs() <= dead) return const _Status('On track', BrandColors.emerald, Icons.thumb_up_rounded);
  if (deltaSeconds <= good)      return const _Status('On track', BrandColors.emerald, Icons.thumb_up_rounded);
  if (deltaSeconds > bad)        return const _Status('Needs work', BrandColors.raspberry, Icons.thumb_down_rounded);
  return const _Status('Borderline', BrandColors.amber, Icons.thumbs_up_down_rounded);
}

/// ✅ Human-friendly delta label
String _deltaLabel(double? delta) {
  if (delta == null || delta.isNaN) return '';
  if (delta < -0.005) return 'Faster by ${(-delta).toStringAsFixed(2)}s';
  if (delta >  0.005) return 'Slower by ${delta.toStringAsFixed(2)}s';
  return 'On par';
}

/// ---- Local fallback prediction
class PredictionResult {
  final String timeText;
  final String confidenceText;
  PredictionResult(this.timeText, this.confidenceText);
}

class PredictionTransfer {
  final DateTime raceDate;
  final String distance;
  final String stroke;
  final String baseline;
  final double? waterTemp;
  final double? humidity;
  final String predictedTime;
  final String? confidence;

  const PredictionTransfer({
    required this.raceDate,
    required this.distance,
    required this.stroke,
    required this.baseline,
    required this.waterTemp,
    required this.humidity,
    required this.predictedTime,
    required this.confidence,
  });
}

Future<PredictionResult> predictBestTime({
  required DateTime raceDate,
  required String distance,
  required String stroke,
  double? waterTempC,
  double? humidityPct,
  String? bestTimeBaseline,
}) async {
  final hasBaseline = (bestTimeBaseline != null && bestTimeBaseline.trim().isNotEmpty);
  final baseSec = hasBaseline
      ? _timeStrToSeconds(bestTimeBaseline!)
      : (_defaultByDistance[distance] ?? 90.0);

  double pred = baseSec.isNaN ? (_defaultByDistance[distance] ?? 90.0) : baseSec;

  // --- Taper
  final daysDiff = raceDate.difference(DateTime.now()).inDays; // future => positive
  if (daysDiff > 0) {
    final capped = daysDiff.clamp(0, 10);
    pred += -0.25 * capped; // up to -2.5s
  } else if (daysDiff < 0) {
    final capped = (-daysDiff).clamp(0, 5);
    pred += 0.10 * capped; // up to +0.5s
  }

  // --- Water temperature (~27°C ideal)
  if (waterTempC != null) {
    final d = (waterTempC - 27.0).abs();
    if (d <= 1.0) {
      pred -= 0.40;
    } else {
      pred += 0.06 * (d - 1.0);
    }
  }

  // --- Humidity: 40–55% is best
  if (humidityPct != null) {
    if (humidityPct >= 40 && humidityPct <= 55) {
      pred -= 0.25;
    } else if (humidityPct > 65) {
      pred += 0.03 * (humidityPct - 65);
    } else if (humidityPct < 35) {
      pred += 0.02 * (35 - humidityPct);
    }
  }

  if (!hasBaseline) {
    if (stroke == 'Breaststroke') pred += 0.20;
    if (stroke == 'Butterfly') pred += 0.10;
  }

  if (pred < 0) pred = 0;
  const conf = '±0.4s';
  return PredictionResult(_secondsToTimeStr(pred), conf);
}

/// ---- Validators & parsers

/// Accepts "55" OR a range "40-55" / "40 – 55" and returns the midpoint.
double? _parseHumidity(String? v) {
  if (v == null) return null;
  final s = v.trim().replaceAll('%', '').replaceAll(' ', '');
  if (s.isEmpty) return null;

  // try single number
  final single = double.tryParse(s);
  if (single != null) return single;

  // try range: 40-55 or 40–55 (en dash)
  final parts = s.split(RegExp(r'[-–]'));
  if (parts.length == 2) {
    final a = double.tryParse(parts[0]);
    final b = double.tryParse(parts[1]);
    if (a != null && b != null) return (a + b) / 2.0;
  }
  return null;
}

String? _required(String? v, {String name = 'This field'}) {
  if (v == null || v.trim().isEmpty) return '$name is required';
  return null;
}

String? _requiredTime(String? v) {
  if (v == null || v.trim().isEmpty) return 'Best time is required';
  return _timeStrToSeconds(v).isNaN ? 'Enter time as mm:ss.ss or seconds' : null;
}

String? _requiredNum(String? v, {String name = 'This field'}) {
  if (v == null || v.trim().isEmpty) return '$name is required';
  return double.tryParse(v.trim()) == null ? '$name must be a number' : null;
}

String? _requiredHumidity(String? v) {
  if (v == null || v.trim().isEmpty) return 'Humidity is required';
  final parsed = _parseHumidity(v);
  if (parsed == null) return 'Enter % or range like 40-55';
  if (parsed < 0 || parsed > 100) return 'Humidity must be between 0 and 100';
  return null;
}

/// ---- Screen with THREE tabs (clean header, pull-to-refresh)
class PredictBestFinishingTimeScreen extends StatefulWidget {
  const PredictBestFinishingTimeScreen({super.key});

  @override
  State<PredictBestFinishingTimeScreen> createState() => _PredictBestFinishingTimeScreenState();
}

class _PredictBestFinishingTimeScreenState extends State<PredictBestFinishingTimeScreen>
    with TickerProviderStateMixin {
  DateTime _raceDate = DateTime.now();
  String _distance = '100m';
  String _stroke = 'Freestyle';

  final _baselineCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _humidCtrl = TextEditingController();

  final _quickFormKey = GlobalKey<FormState>();

  // --- automatic weather (added)
  double? _autoTemp;
  double? _autoHumidity;
  bool _loadingWeather = false;

  bool _predicting = false;
  String? _predicted;
  String? _conf;

  // identity + profile + baseline status
  String? _uid;
  UserProfile? _userProfile;
  bool _loadingBaseline = false;
  String? _baselineSourceNote;

  // tabs
  late final TabController _tabController;

  void _goToPerformance(PredictionTransfer p) {
    Navigator.of(context).pushNamed('/swimmer-performance', arguments: p);
  }

  Future<void> _fetchWeatherAuto() async {
    setState(() => _loadingWeather = true);
    try {
      final weather = await fetchWeatherAuto();
      if (mounted) {
        setState(() {
          _autoTemp = weather['temp'];
          _autoHumidity = weather['humidity'];
          _waterCtrl.text = _autoTemp?.toStringAsFixed(1) ?? '';
          _humidCtrl.text = _autoHumidity?.toStringAsFixed(0) ?? '';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _hydrateUser();
    _tabController = TabController(length: 3, vsync: this);

    _fetchWeatherAuto(); // start auto-weather fetch

  }

  @override
  void dispose() {
    _baselineCtrl.dispose();
    _waterCtrl.dispose();
    _humidCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _hydrateUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _uid = null);
        await SwimHistoryStore().setActiveUser(null);
        return;
      }
      setState(() => _uid = user.uid);
      await SwimHistoryStore().setActiveUser(_uid);

      final doc = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        _userProfile = UserProfile.fromMap(doc.data()!);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No profile found — using anonymous prediction')),
        );
      }

      await _refreshAutoBaseline();
    } catch (_) {}
  }

  Future<void> _refreshAutoBaseline() async {
    if (_uid == null) return;
    setState(() {
      _loadingBaseline = true;
      _baselineSourceNote = null;
    });

    try {
      final meters = _distanceLabelToMeters(_distance) * 1.0;

      final q = await FirebaseFirestore.instance
          .collection('swim_training_sessions')
          .where('userId', isEqualTo: _uid)
          .where('strokeType', isEqualTo: _stroke)
          .where('trainingDistance', isEqualTo: meters)
          .limit(50)
          .get();

      double? bestSecs;
      DateTime? bestDate;

      for (final d in q.docs) {
        final data = d.data();
        final secs = (data['actualTime'] is int)
            ? (data['actualTime'] as int).toDouble()
            : (data['actualTime'] as num?)?.toDouble();
        if (secs == null || secs <= 0) continue;

        final when = _parseDate(data['date']);
        if (bestSecs == null || secs < bestSecs) {
          bestSecs = secs;
          bestDate = when;
        }
      }

      if (bestSecs != null) {
        setState(() {
          _baselineCtrl.text = _secondsToTimeStr(bestSecs!);
          _baselineSourceNote = bestDate == null
              ? 'Auto baseline from your past session'
              : 'Auto baseline from ${DateFormat('yyyy-MM-dd').format(bestDate!)}';
        });
      } else {
        setState(() => _baselineSourceNote = 'No past sessions found — enter a baseline');
      }
    } catch (_) {
      setState(() => _baselineSourceNote = 'Could not auto-load baseline — enter manually');
    } finally {
      if (mounted) setState(() => _loadingBaseline = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _raceDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) setState(() => _raceDate = picked);
  }

  /// 🔴 Write a prediction log to Firestore (Quick tab)
  Future<void> _logPredictionToFirestore({
    required String contextTag, // 'quick' | 'training'
    required String distance,
    required String stroke,
    required DateTime raceDate,
    required String? baseline,
    required double? waterTemp,
    required double? humidity,
    required String predictedTime,
    required String? confidence,
    required bool usedBackend,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('prediction_logs').add({
        'userId': user?.uid,
        'context': contextTag,
        'distance': distance,
        'stroke': stroke,
        'raceDate': Timestamp.fromDate(raceDate),
        'baseline': baseline,
        'waterTemp': waterTemp,
        'humidity': humidity,
        'predictedTime': predictedTime,
        'confidence': confidence,
        'usedBackend': usedBackend,
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {}
  }

  // 🚀 QUICK PREDICT — uses backend, falls back to local model on error
  Future<void> _doPredict() async {
    if (!_quickFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    setState(() {
      _predicting = true;
      _predicted = null;
      _conf = null;
    });

    final wt = double.parse(_waterCtrl.text.trim());
    final huMid = _parseHumidity(_humidCtrl.text.trim())!; // validated above

    try {
      final resp = await predictionService.predict(
        swimmerId: _uid,
        name: _userProfile?.name,
        distance: _distance,
        stroke: _stroke,
        waterTemp: wt,
        humidityPct: huMid,
        date: _raceDate,
      );

      if (!mounted) return;
      final predicted = resp['predicted_best_time'] as String?;
      const conf = '±0.4s';

      setState(() {
        _predicting = false;
        _predicted = predicted;
        _conf = conf;
      });

      if (predicted != null) {
        await _logPredictionToFirestore(
          contextTag: 'quick',
          distance: _distance,
          stroke: _stroke,
          raceDate: _raceDate,
          baseline: _baselineCtrl.text.trim().isEmpty ? null : _baselineCtrl.text.trim(),
          waterTemp: wt,
          humidity: huMid,
          predictedTime: predicted,
          confidence: conf,
          usedBackend: true,
        );
      }
    } catch (e) {
      final res = await predictBestTime(
        raceDate: _raceDate,
        distance: _distance,
        stroke: _stroke,
        waterTempC: wt,
        humidityPct: huMid,
        bestTimeBaseline: _baselineCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _predicting = false;
        _predicted = res.timeText;
        _conf = res.confidenceText;
      });

      await _logPredictionToFirestore(
        contextTag: 'quick',
        distance: _distance,
        stroke: _stroke,
        raceDate: _raceDate,
        baseline: _baselineCtrl.text.trim().isEmpty ? null : _baselineCtrl.text.trim(),
        waterTemp: wt,
        humidity: huMid,
        predictedTime: res.timeText,
        confidence: res.confidenceText,
        usedBackend: false,
      );
    }
  }

  void _applyToPerformance() {
    if (_predicted == null) return;
    final wt = double.tryParse(_waterCtrl.text.trim());
    final hu = _parseHumidity(_humidCtrl.text.trim());

    SwimHistoryStore().add(TrainingSession(
      createdAt: DateTime.now(),
      sessionDate: _raceDate,
      distance: _distance,
      stroke: _stroke,
      swimmerId: _uid,
      swimmerName: _userProfile?.name,
      bestTimeText: _baselineCtrl.text.trim().isEmpty ? null : _baselineCtrl.text.trim(),
      waterTemp: wt,
      humidity: hu,
      predictedTime: _predicted,
      confidence: _conf,
      isPrediction: true,
    ));

    _goToPerformance(
      PredictionTransfer(
        raceDate: _raceDate,
        distance: _distance,
        stroke: _stroke,
        baseline: _baselineCtrl.text.trim(),
        waterTemp: wt,
        humidity: hu,
        predictedTime: _predicted!,
        confidence: _conf,
      ),
    );
  }

  Future<void> _refreshAll() async {
    await _hydrateUser();
    await _refreshAutoBaseline();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = BrandTheme.accentFor(_distance);

    double? _delta() {
      if (_predicted == null) return null;
      final p = _timeStrToSeconds(_predicted!);
      final b = _timeStrToSeconds(_baselineCtrl.text);
      if (p.isNaN || b.isNaN || b <= 0) return null;
      return p - b;
    }

    double? _pct() {
      final d = _delta();
      final b = _timeStrToSeconds(_baselineCtrl.text);
      if (d == null || b <= 0 || b.isNaN) return null;
      return (d / b) * 100;
    }

    final delta = _delta();
    final pct = _pct();
    final status = _progressStatus(delta ?? double.nan, _distance);

    return DefaultTabController(
      length: 3,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: BrandTheme.backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            // ✅ Clean AppBar — banner removed
            title: const Text('Predict best finishing time'),
            centerTitle: true,
            elevation: 0.5,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refreshAll,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _ColorfulTabBar(
                  controller: _tabController,
                  accent: colors,
                  tabs: const [
                    Tab(icon: Icon(Icons.speed), text: 'Quick Predict'),
                    Tab(icon: Icon(Icons.edit_calendar), text: 'Training & Predict'),
                    Tab(icon: Icon(Icons.history), text: 'History'),
                  ],
                ),
              ),
            ),
          ),

  // ✅ put this inside your Scaffold:
resizeToAvoidBottomInset: true,

body: SafeArea(
  maintainBottomViewPadding: true,
  child: Padding(
    padding: EdgeInsets.only(
      // include keyboard inset + device safe area + extra buffer to avoid tiny overflows
      bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
    ),
    child: TabBarView(
      controller: _tabController,
      children: [
        // === Tab 1: Quick Predict (with pull-to-refresh) ===
        RefreshIndicator(
          onRefresh: _refreshAll,
          child: Form(
            key: _quickFormKey,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                // keep original bottom space and account for system insets
                32 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _GlassCard(
                  borderColor: colors.last.withOpacity(.35),
                  gradient: LinearGradient(
                    colors: [
                      colors.first.withOpacity(.15),
                      colors.last.withOpacity(.10)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Set your race context'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _FieldDateLike(
                              label: 'Race date',
                              value: DateFormat('yyyy-MM-dd')
                                  .format(_raceDate),
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Dropdown(
                              label: 'Distance',
                              value: _distance,
                              items: const [
                                '50m',
                                '100m',
                                '200m',
                                '400m'
                              ],
                              onChanged: (v) => setState(() {
                                _distance = v!;
                                _refreshAutoBaseline();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Dropdown(
                        label: 'Stroke',
                        value: _stroke,
                        items: const [
                          'Freestyle',
                          'Backstroke',
                          'Breaststroke',
                          'Butterfly'
                        ],
                        onChanged: (v) => setState(() {
                          _stroke = v!;
                          _refreshAutoBaseline();
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Inputs'),
                      const SizedBox(height: 10),

                      if (_loadingBaseline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Loading your best baseline...'),
                            ],
                          ),
                        )
                      else if (_baselineSourceNote != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _baselineSourceNote!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),

                              ),
                            ],
                          ),
                        ),


                      _TextField(
                        label: 'Baseline best time',
                        controller: _baselineCtrl,
                        hint: 'mm:ss.ss or seconds',
                        validator: _requiredTime,
                        icon: Icons.timer_rounded,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              label: 'Water Temp',
                              controller: _waterCtrl,
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  _requiredNum(v, name: 'Water temperature'),
                              suffixText: '°C',
                              icon: Icons.water_drop_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TextField(
                              label: 'Humidity',
                              controller: _humidCtrl,
                              keyboardType: TextInputType.text,
                              validator: _requiredHumidity,
                              suffixText: '% or 40-55',
                              icon: Icons.air_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GradientButton(
                        text: 'Predict',
                        onPressed: _predicting ? null : _doPredict,
                        colors: colors,
                        loading: _predicting,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_predicted != null)
                  _GlassCard(
                    borderColor: colors.last.withOpacity(.35),
                    gradient: LinearGradient(
                      colors: [
                        colors.first.withOpacity(.12),
                        colors.last.withOpacity(.08)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Estimated finishing time'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(status.icon, color: status.color),
                            const SizedBox(width: 8),
                            Text(
                              _predicted!,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: status.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Confidence: ${_conf ?? "—"}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: -6,
                          children: [
                            _Pill(
                                text:
                                    'Date: ${DateFormat('EEE, dd MMM').format(_raceDate)}',
                                tint: colors.first),
                            _Pill(
                                text: 'Distance: $_distance',
                                tint: colors.first),
                            _Pill(text: 'Stroke: $_stroke', tint: colors.first),
                            _StatusPill(status),
                            if (delta != null) ...[
                              _Pill(
                                  text: _deltaLabel(delta),
                                  tint: status.color),
                              if (pct != null)
                                _Pill(
                                  text:
                                      '(${(delta < 0 ? '-' : '+')}${pct.abs().toStringAsFixed(1)}%)',
                                  tint: status.color,
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        GradientButton(
                          text: 'Use in Performance',
                          onPressed: _applyToPerformance,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),
        ),

        // === Tab 2: Training & Predict (with pull-to-refresh) ===
        _TrainingAndPredictTabX(
          onRefresh: _refreshAll,
          selectedDate: _raceDate,
          onPickDate: (d) => setState(() => _raceDate = d),
          distance: _distance,
          onChangeDistance: (v) => setState(() {
            _distance = v!;
            _refreshAutoBaseline();
          }),
          stroke: _stroke,
          onChangeStroke: (v) => setState(() {
            _stroke = v!;
            _refreshAutoBaseline();
          }),
          onSaveBestTime: (bt) {
            if ((bt ?? '').isNotEmpty) _baselineCtrl.text = bt!;
          },
          onSaveEnvironment: (wt, hu) {
            _waterCtrl.text = wt?.toString() ?? '';
            _humidCtrl.text = hu?.toString() ?? '';
          },
          bestTimeBaseline:
              _baselineCtrl.text.isEmpty ? null : _baselineCtrl.text,
          onApplyToPerformance: (predicted, conf, comp) {
            final wt = double.tryParse(_waterCtrl.text.trim());
            final hu = _parseHumidity(_humidCtrl.text.trim());
            SwimHistoryStore().add(TrainingSession(
              createdAt: DateTime.now(),
              sessionDate: _raceDate,
              distance: _distance,
              stroke: _stroke,
              swimmerId: _uid,
              swimmerName: _userProfile?.name,
              competition: comp,
              bestTimeText: _baselineCtrl.text.trim(),
              waterTemp: wt,
              humidity: hu,
              predictedTime: predicted,
              confidence: conf,
              isPrediction: true,
            ));
            _goToPerformance(
              PredictionTransfer(
                raceDate: _raceDate,
                distance: _distance,
                stroke: _stroke,
                baseline: _baselineCtrl.text.trim(),
                waterTemp: wt,
                humidity: hu,
                predictedTime: predicted,
                confidence: conf,
              ),
            );
          },
        ),
 
        // === Tab 3: History (with pull-to-refresh) ===
        // ensure history tab also has safe bottom padding
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
          ),
          child: _HistoryTabInsidePredict(currentUserId: _uid, onRefresh: _refreshAll),
        ),
      ],
    ),
  ),
),
        ),
      ),
    );
  }
}

/// Colorful, rounded TabBar
class _ColorfulTabBar extends StatelessWidget {
  final activeBlue = const Color(0xFF0077B6);
 final TabController controller;
  final List<Tab> tabs;
  final List<Color> accent;

  const _ColorfulTabBar({
    required this.controller,
    required this.tabs,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E4F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        indicatorSize: TabBarIndicatorSize.tab,
        overlayColor: MaterialStateProperty.all(Colors.transparent),

        // 🌊 Swimming gradient indicator
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33007BFF),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),

        // 🩵 Text & icon colors
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF0F172A),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),

        tabs: tabs.map((tab) {
          final t = tab as Tab;
          return Tab(
            iconMargin: const EdgeInsets.only(bottom: 2),
            icon: t.icon,
            text: t.text,
          );
        }).toList(),
      ),
    );
  }
}

/// Colorful, rounded TabBar

 

  

/// ---- Small section title
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: BrandColors.headline,
      ),
    );
  }
}

/// ---- “Glass” card helper
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? borderColor;
  const _GlassCard({required this.child, this.gradient, this.borderColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient ?? const LinearGradient(colors: [BrandColors.surface, BrandColors.surfaceTint]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? BrandColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// ---- Pills
class _Pill extends StatelessWidget {
  final String text;
  final Color tint;
  const _Pill({required this.text, required this.tint});
  @override
  Widget build(BuildContext context) {
    return Chip(
        backgroundColor: tint.withOpacity(.10),
        side: BorderSide(color: tint.withOpacity(.35)),
        label: Text(text, style: TextStyle(color: tint.darken(0.15))));
  }
}

class _StatusPill extends StatelessWidget {
  final _Status status;
  const _StatusPill(this.status);
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: status.color.withOpacity(.15),
        child: Icon(status.icon, color: status.color, size: 16),
      ),
      backgroundColor: status.color.withOpacity(.10),
      side: BorderSide(color: status.color.withOpacity(.35)),
      label: Text(status.label, style: TextStyle(color: status.color)),
    );
  }
}

/// ---- Quick Predict atoms
class _TextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? hint;
  final String? Function(String?)? validator;
  final String? suffixText;
  final IconData? icon;
  final bool readOnly;

  const _TextField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.hint,
    this.validator,
    this.suffixText,
    this.icon,
    this.readOnly = false,
  });

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  final FocusNode _node = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _hasFocus = _node.hasFocus));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _hasFocus && !widget.readOnly;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(colors: [BrandColors.aqua, BrandColors.indigo]) : null,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: BrandColors.border),
        boxShadow: active
            ? const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]
            : const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: widget.readOnly ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(11),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              if (widget.icon != null) Icon(widget.icon, size: 16, color: Colors.grey.shade600),
              if (widget.icon != null) const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          TextFormField(
            readOnly: widget.readOnly,
            focusNode: _node,
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: widget.hint,
              suffixText: widget.suffixText,
            ),
            validator: widget.validator ?? (v) => _required(v, name: widget.label),
          ),
        ]),
      ),
    );
  }
}

class _FieldDateLike extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _FieldDateLike({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [BrandColors.aqua, BrandColors.indigo]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(value),
            ])),
            const Icon(Icons.date_range_rounded, color: BrandColors.aqua),
          ]),
        ),
      ),
    );
  }
}

class _Dropdown extends StatefulWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});
  @override
  State<_Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<_Dropdown> {
  final FocusNode _node = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _hasFocus = _node.hasFocus));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(colors: [BrandColors.teal, BrandColors.indigo]) : null,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: BrandColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              focusNode: _node,
              isExpanded: true,
              value: widget.value,
              items: widget.items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Row(
                          children: [
                            const Icon(Icons.pool_rounded, size: 16, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(e),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: widget.onChanged,
              icon: const Icon(Icons.expand_more_rounded),
            ),
          ),
        ]),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final bool loading;
  const GradientButton(
      {super.key, required this.text, required this.onPressed, required this.colors, this.loading = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: colors.last.withOpacity(.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// ========================================================================
/// Training + Predict tab
/// ========================================================================
class _TrainingAndPredictTabX extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime) onPickDate;

  final String distance;
  final ValueChanged<String> onChangeDistance;

  final String stroke;
  final ValueChanged<String> onChangeStroke;

  final ValueChanged<String?> onSaveBestTime;
  final void Function(double? waterTemp, double? humidity) onSaveEnvironment;

  final String? bestTimeBaseline;

  final void Function(
    String predicted,
    String? confidence,
    String? competition,
  ) onApplyToPerformance;

  final Future<void> Function()? onRefresh; // 👈 added

  const _TrainingAndPredictTabX({
    required this.selectedDate,
    required this.onPickDate,
    required this.distance,
    required this.onChangeDistance,
    required this.stroke,
    required this.onChangeStroke,
    required this.onSaveBestTime,
    required this.onSaveEnvironment,
    required this.bestTimeBaseline,
    required this.onApplyToPerformance,
    this.onRefresh,
  });

  @override
  State<_TrainingAndPredictTabX> createState() => _TrainingAndPredictTabXState();
}

class _TrainingAndPredictTabXState extends State<_TrainingAndPredictTabX> {
  final _compCtrl = TextEditingController();
  final _bestCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _humidCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  DateTime? _bestTimeDate;
  bool _saving = false;
  bool _predicting = false;
  String? _predicted;
  String? _predConf;
  String? _error;
  bool _showBestTimeDateError = false;

  @override
  void initState() {
    super.initState();
    if (widget.bestTimeBaseline != null) _bestCtrl.text = widget.bestTimeBaseline!;
    _bestTimeDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _compCtrl.dispose();
    _bestCtrl.dispose();
    _waterCtrl.dispose();
    _humidCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) widget.onPickDate(picked);
  }

  Future<void> _pickBestTimeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _bestTimeDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) setState(() {
      _bestTimeDate = picked;
      _showBestTimeDateError = false;
    });
  }

  bool _validateAll() {
    final valid = _formKey.currentState!.validate();
    final bestDateOk = _bestTimeDate != null;
    setState(() => _showBestTimeDateError = !bestDateOk);
    return valid && bestDateOk;
  }

  /// ✅ Firestore: write training session to 'swim_training_sessions'
  Future<void> _writeTrainingSessionToFirestore({
    required String distance,
    required String stroke,
    required DateTime date,
    required String bestTimeText,
    required DateTime bestTimeDate,
    double? waterTemp,
    double? humidity,
    String? competition,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('swim_training_sessions').add({
        'userId': user?.uid,
        'strokeType': stroke,
        'trainingDistance': _distanceLabelToMeters(distance) * 1.0,
        'actualTime': _timeStrToSeconds(bestTimeText),
        'bestTimeText': bestTimeText,
        'date': Timestamp.fromDate(date),
        'bestTimeDate': Timestamp.fromDate(bestTimeDate),
        'waterTemp': waterTemp,
        'humidity': humidity,
        'competition': competition,
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sync training session to cloud (saved locally).')),
        );
      }
    }
  }

  /// ✅ Firestore: write prediction log to 'prediction_logs'
  Future<void> _logPredictionToFirestore({
    required String contextTag, // 'training'
    required String distance,
    required String stroke,
    required DateTime raceDate,
    required String? baseline,
    required double? waterTemp,
    required double? humidity,
    required String predictedTime,
    required String? confidence,
    required bool usedBackend,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('prediction_logs').add({
        'userId': user?.uid,
        'context': contextTag,
        'distance': distance,
        'stroke': stroke,
        'raceDate': Timestamp.fromDate(raceDate),
        'baseline': baseline,
        'waterTemp': waterTemp,
        'humidity': humidity,
        'predictedTime': predictedTime,
        'confidence': confidence,
        'usedBackend': usedBackend,
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sync prediction to cloud (saved locally).')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_validateAll()) {
      setState(() {
        _error = 'Please fill all required fields.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 250));
    widget.onSaveBestTime(_bestCtrl.text.trim());
    final wt = double.tryParse(_waterCtrl.text.trim());
    final hu = _parseHumidity(_humidCtrl.text.trim());
    widget.onSaveEnvironment(wt, hu);

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // local store
    SwimHistoryStore().add(TrainingSession(
      createdAt: DateTime.now(),
      sessionDate: widget.selectedDate,
      distance: widget.distance,
      stroke: widget.stroke,
      competition: _compCtrl.text.trim().isEmpty ? null : _compCtrl.text.trim(),
      bestTimeText: _bestCtrl.text.trim(),
      bestTimeDate: _bestTimeDate,
      waterTemp: wt,
      humidity: hu,
      isPrediction: false,
      swimmerId: currentUid,
      swimmerName: null,
    ));

    await _writeTrainingSessionToFirestore(
      distance: widget.distance,
      stroke: widget.stroke,
      date: widget.selectedDate,
      bestTimeText: _bestCtrl.text.trim(),
      bestTimeDate: _bestTimeDate!,
      waterTemp: wt,
      humidity: hu,
      competition: _compCtrl.text.trim().isNotEmpty ? _compCtrl.text.trim() : null,
    );

    setState(() {
      _saving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Training session saved')));
    }
  }

  // 🚀 TRAINING TAB PREDICT
  Future<void> _predict() async {
    if (!_validateAll()) {
      setState(() {
        _error = 'Please fill all required fields.';
      });
      return;
    }
    setState(() {
      _predicting = true;
      _error = null;
      _predicted = null;
      _predConf = null;
    });

    try {
      final wt = double.parse(_waterCtrl.text.trim());
      final huMid = _parseHumidity(_humidCtrl.text.trim())!;

      final resp = await predictionService.predict(
        distance: widget.distance,
        stroke: widget.stroke,
        waterTemp: wt,
        humidityPct: huMid,
        date: widget.selectedDate,
      );

      if (!mounted) return;
      final String? predicted = resp['predicted_best_time'] as String?;
      const String? conf = '±0.4s';

      setState(() {
        _predicted = predicted;
        _predConf = conf;
      });

      if (predicted != null) {
        await _logPredictionToFirestore(
          contextTag: 'training',
          distance: widget.distance,
          stroke: widget.stroke,
          raceDate: widget.selectedDate,
          baseline: _bestCtrl.text.trim().isEmpty ? null : _bestCtrl.text.trim(),
          waterTemp: wt,
          humidity: huMid,
          predictedTime: predicted,
          confidence: conf,
          usedBackend: true,
        );
      }
    } catch (_) {
      try {
        final wt = double.tryParse(_waterCtrl.text.trim());
        final huMid = _parseHumidity(_humidCtrl.text.trim());
        final res = await predictBestTime(
          raceDate: widget.selectedDate,
          distance: widget.distance,
          stroke: widget.stroke,
          waterTempC: wt,
          humidityPct: huMid,
          bestTimeBaseline: _bestCtrl.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _predicted = res.timeText;
          _predConf = res.confidenceText;
        });

        await _logPredictionToFirestore(
          contextTag: 'training',
          distance: widget.distance,
          stroke: widget.stroke,
          raceDate: widget.selectedDate,
          baseline: _bestCtrl.text.trim().isEmpty ? null : _bestCtrl.text.trim(),
          waterTemp: wt,
          humidity: huMid,
          predictedTime: res.timeText,
          confidence: res.confidenceText,
          usedBackend: false,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not generate prediction. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _predicting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final bestDateText =
        _bestTimeDate == null ? 'Pick date' : DateFormat('yyyy-MM-dd').format(_bestTimeDate!);
    final accent = BrandTheme.accentFor(widget.distance, widget.stroke);

    double? delta() {
      if (_predicted == null) return null;
      final p = _timeStrToSeconds(_predicted!);
      final b = _timeStrToSeconds(_bestCtrl.text);
      if (p.isNaN || b.isNaN || b <= 0) return null;
      return p - b;
    }

    double? pct() {
      final d = delta();
      final b = _timeStrToSeconds(_bestCtrl.text);
      if (d == null || b <= 0 || b.isNaN) return null;
      return (d / b) * 100;
    }

    final d = delta();
    final p = pct();
    final status = _progressStatus(d ?? double.nan, widget.distance);

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: Form(
        key: _formKey,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16, 8, 16,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            _GlassCard(
              gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF7FBFF)]),
              child: Row(children: [
                Icon(Icons.edit_calendar, color: accent.last),
                const SizedBox(width: 8),
                const Text('Add your training session',
                    style: TextStyle(fontWeight: FontWeight.w800, color: BrandColors.headline)),
              ]),
            ),
            const SizedBox(height: 12),

            const _SectionLabelX('Basic Info'),
            _TapFieldX(label: 'Date', value: dateText, onTap: _pickDate, icon: Icons.today_rounded),
            const SizedBox(height: 10),

            _DropdownFieldX(
              label: 'Stroke type',
              value: widget.stroke,
              items: const ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly'],
              onChanged: (v) => widget.onChangeStroke(v!),
            ),

            const SizedBox(height: 14),
            const _SectionLabelX('Performance metrics'),
            _InputFieldX(
                label: 'Competition',
                controller: _compCtrl,
                validator: (v) => _required(v, name: 'Competition'),
                icon: Icons.emoji_events_rounded),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _InputFieldX(
                        label: 'Best time',
                        controller: _bestCtrl,
                        validator: _requiredTime,
                        icon: Icons.timer_rounded,
                        hint: 'mm:ss.ss or seconds')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      _TapFieldX(
                          label: 'Best time date',
                          value: bestDateText,
                          onTap: _pickBestTimeDate,
                          icon: Icons.calendar_month_rounded),
                      if (_showBestTimeDateError)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Best time date is required',
                                style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const _SectionLabelX('Environmental Factors'),
            _InputFieldX(
                label: 'Water Temp',
                controller: _waterCtrl,
                keyboard: TextInputType.number,
                validator: (v) => _requiredNum(v, name: 'Water temperature'),
                icon: Icons.water_drop_rounded,
                suffixText: '°C'),
            const SizedBox(height: 10),
            _InputFieldX(
                label: 'Humidity (or 40-55)',
                controller: _humidCtrl,
                keyboard: TextInputType.text,
                validator: _requiredHumidity,
                icon: Icons.air_rounded,
                suffixText: '%'),

            const SizedBox(height: 12),
            GradientButton(text: 'Save', onPressed: _saving ? null : _save, colors: accent, loading: _saving),

            const SizedBox(height: 20),
            const _SectionLabelX('Predict time for upcoming competition'),
            _DropdownFieldX(
              label: 'Distance',
              value: widget.distance,
              items: const ['50m', '100m', '200m', '400m'],
              onChanged: (v) => widget.onChangeDistance(v!),
            ),

            const SizedBox(height: 12),
            GradientButton(text: 'Predict', onPressed: _predicting ? null : _predict, colors: accent, loading: _predicting),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700)))
                ]),
              ),

            if (_predicted != null)
              _GlassCard(
                borderColor: accent.last.withOpacity(.35),
                gradient: LinearGradient(colors: [accent.first.withOpacity(0.12), accent.last.withOpacity(0.06)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Predicted time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(status.icon, color: status.color),
                      const SizedBox(width: 6),
                      Text(_predicted!, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: status.color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Confidence: ${_predConf ?? "—"}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: -6, children: [
                    _Pill(text: 'Date: ${DateFormat('yyyy-MM-dd').format(widget.selectedDate)}', tint: accent.first),
                    _Pill(text: 'Distance: ${widget.distance}', tint: accent.first),
                    _Pill(text: 'Stroke: ${widget.stroke}', tint: accent.first),
                    _StatusPill(status),
                    if (d != null) ...[
                      _Pill(text: _deltaLabel(d), tint: status.color),
                      if (p != null)
                        _Pill(
                          text: '(${(d < 0 ? '-' : '+')}${p.abs().toStringAsFixed(1)}%)',
                          tint: status.color,
                        ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  GradientButton(
                    text: 'Use in Performance',
                    onPressed: () => widget.onApplyToPerformance(
                      _predicted!,
                      _predConf,
                      _compCtrl.text.trim().isNotEmpty ? _compCtrl.text.trim() : null,
                    ),
                    colors: accent,
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---- HISTORY TAB (inside predictor) — STRICT per-user view + per-user clear
class _HistoryTabInsidePredict extends StatefulWidget {
  final String? currentUserId;
  final Future<void> Function()? onRefresh; // 👈 added
  const _HistoryTabInsidePredict({this.currentUserId, this.onRefresh});
  @override
  State<_HistoryTabInsidePredict> createState() => _HistoryTabInsidePredictState();
}

class _HistoryTabInsidePredictState extends State<_HistoryTabInsidePredict>
    with AutomaticKeepAliveClientMixin<_HistoryTabInsidePredict> {
  late final SwimHistoryStore _store;

  @override
  void initState() {
    super.initState();
    _store = SwimHistoryStore();
    _store.addListener(_onChange);
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    if (widget.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to clear your history.')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear your history?'),
        content: const Text('This removes local history entries for your account on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final uid = widget.currentUserId!;
      final others = _store.items.where((s) => s.swimmerId != uid).toList();
      _store.clear();
      for (final s in others) {
        _store.add(s);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your history was cleared.')),
        );
      }
    } catch (e) {
      try {
        _store.clear();
      } catch (_) {}
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final uid = widget.currentUserId;

    if (uid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Sign in to view your history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('History is scoped to the currently signed-in swimmer.'),
            ],
          ),
        ),
      );
    }

    final filtered = _store.items
        .where((s) => s.swimmerId == uid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a!.createdAt));

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: filtered.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16, 12, 16,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear my history'),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No history yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      Text('Save a training session or add a prediction to see it here.'),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16, 12, 16,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear my history'),
                  ),
                ),
                const SizedBox(height: 4),
                ...List.generate(filtered.length, (i) {
                  final s = filtered[i];
                  final isPred = s.isPrediction;
                  final colors = BrandTheme.accentFor(s.distance, s.stroke);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 6,
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: colors),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(isPred ? 'Prediction' : 'Training session',
                                style: TextStyle(fontWeight: FontWeight.w800, color: colors.last)),
                            const Spacer(),
                            Text(DateFormat('yyyy-MM-dd HH:mm').format(s.createdAt),
                                style: const TextStyle(color: Colors.grey)),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: -6,
                            children: [
                              Chip(label: Text('Date: ${DateFormat('yyyy-MM-dd').format(s.sessionDate)}')),
                              Chip(label: Text('Distance: ${s.distance}')),
                              Chip(label: Text('Stroke: ${s.stroke}')),
                              if (s.competition?.isNotEmpty == true) Chip(label: Text('Comp: ${s.competition}')),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (!isPred) ...[
                            _kvRowH('Best time', s.bestTimeText ?? '—', valueBold: true),
                            _kvRowH('Best time date',
                                s.bestTimeDate == null ? '—' : DateFormat('yyyy-MM-dd').format(s.bestTimeDate!)),
                          ],

                          _kvRowH('Water °C', s.waterTemp?.toStringAsFixed(1) ?? '—'),
                          _kvRowH('Humidity %', s.humidity?.toStringAsFixed(0) ?? '—'),

                          if (isPred) ...[
                            const SizedBox(height: 6),
                            _kvRowH('Predicted time', s.predictedTime ?? '—', valueBold: true),
                            _kvRowH('Confidence', s.confidence ?? '—'),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _kvRowH(String k, String v, {bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 8),
          Text(
            v,
            style: TextStyle(
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---- Small UI atoms for Training tab
class _SectionLabelX extends StatelessWidget {
  final String text;
  const _SectionLabelX(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: BrandColors.headline));
}

class _InputFieldX extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboard;
  final String? hint;
  final String? Function(String?)? validator;
  final String? suffixText;
  final IconData? icon;
  final bool readOnly;
  const _InputFieldX({
    required this.label,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.hint,
    this.validator,
    this.suffixText,
    this.icon,
    this.readOnly = false,
  });

  @override
  State<_InputFieldX> createState() => _InputFieldXState();
}

class _InputFieldXState extends State<_InputFieldX> {
  final FocusNode _node = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _hasFocus = _node.hasFocus));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _hasFocus && !widget.readOnly;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(colors: [BrandColors.aqua, BrandColors.indigo]) : null,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: BrandColors.border),
        boxShadow: active
            ? const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]
            : const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: widget.readOnly ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(11),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              if (widget.icon != null) Icon(widget.icon, size: 16, color: Colors.grey.shade600),
              if (widget.icon != null) const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          TextFormField(
            readOnly: widget.readOnly,
            focusNode: _node,
            controller: widget.controller,
            keyboardType: widget.keyboard,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: widget.hint,
              suffixText: widget.suffixText,
            ),
            validator: widget.validator ?? (v) => _required(v, name: widget.label),
          ),
        ]),
      ),
    );
  }
}

class _TapFieldX extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;
  const _TapFieldX({required this.label, required this.value, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [BrandColors.aqua, BrandColors.indigo]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                if (icon != null) Icon(icon, size: 16, color: Colors.grey.shade600),
                if (icon != null) const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
                      ),
            const SizedBox(height: 6),
            Text(value),
          ]),
        ),
      ),
    );
  }
}

class _DropdownFieldX extends StatefulWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownFieldX({required this.label, required this.value, required this.items, required this.onChanged});
  @override
  State<_DropdownFieldX> createState() => _DropdownFieldXState();
}

class _DropdownFieldXState extends State<_DropdownFieldX> {
  final FocusNode _node = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _hasFocus = _node.hasFocus));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(colors: [BrandColors.violet, BrandColors.indigo]) : null,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: BrandColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              focusNode: _node,
              isExpanded: true,
              value: widget.value,
              items: widget.items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Row(
                          children: [
                            const Icon(Icons.pool_rounded, size: 16, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(e),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: widget.onChanged,
              icon: const Icon(Icons.expand_more_rounded),
            ),
          ),
        ]),
      ),
    );
  }
}

/// ---- Fetch weather automatically (Open-Meteo)
/// ---- Fetch location-based water temperature + humidity (no hardcoding)
/// ---- USA-friendly weather fetch: real water temp if coastal, fallback inland
Future<Map<String, double>> fetchWeatherAuto() async {
  try {
    // ✅ Check location permission
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location service disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    // ✅ Get GPS coordinates
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    debugPrint("📍 lat=${pos.latitude}, lon=${pos.longitude}");

    // 🌊 1️⃣ Try Marine API (real water + humidity if available)
    final marineUrl =
        "https://marine-api.open-meteo.com/v1/marine?latitude=${pos.latitude}"
        "&longitude=${pos.longitude}"
        "&current=water_temperature,humidity"
        "&timezone=auto";
    final marineRes = await http.get(Uri.parse(marineUrl));

    if (marineRes.statusCode == 200) {
      final data = jsonDecode(marineRes.body);
      final current = data['current'] as Map<String, dynamic>? ?? {};
      final water = (current['water_temperature'] as num?)?.toDouble();
      final humid = (current['humidity'] as num?)?.toDouble();

      if (water != null && humid != null) {
        debugPrint(
            "🌊 Marine API → Water ${water.toStringAsFixed(1)}°C, Humidity ${humid.toStringAsFixed(0)}%");
        return {"temp": water, "humidity": humid};
      }
    }

    // 🌦️ 2️⃣ Fallback: standard Open-Meteo current weather + hourly humidity
    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}"
        "&longitude=${pos.longitude}"
        "&current=temperature_2m,relative_humidity_2m"
        "&timezone=auto";
    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) {
      throw Exception('Fallback API failed');
    }

    final data = jsonDecode(res.body);
    final current = data['current'] as Map<String, dynamic>?;

    final airTemp = (current?['temperature_2m'] as num?)?.toDouble();
    final humidity = (current?['relative_humidity_2m'] as num?)?.toDouble();
    final time = current?['time'];

    if (airTemp == null || humidity == null) {
      throw Exception('Missing current weather data');
    }

    debugPrint(
        "🌦️ Live → Air ${airTemp.toStringAsFixed(1)}°C, Humidity ${humidity.toStringAsFixed(0)}% (at $time)");
    return {"temp": airTemp, "humidity": humidity};
  } catch (e) {
    debugPrint("❌ Weather fetch failed: $e");
    // Return NaN to make it clear it failed instead of pretending with 89 %
    return {"temp": double.nan, "humidity": double.nan};
  }
}