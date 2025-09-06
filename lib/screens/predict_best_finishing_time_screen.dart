// lib/screens/predict_best_finishing_time_screen.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/swim_history_store.dart'; // <-- in-memory store

/// ---- Vibrant Palette
class BrandColors {
  static const headline = Color(0xFF0F172A);

  // Primary “ocean rainbow” swatch
  static const aqua      = Color(0xFF06B6D4); // cyan
  static const teal      = Color(0xFF14B8A6); // teal
  static const blue      = Color(0xFF3B82F6); // blue
  static const indigo    = Color(0xFF6366F1); // indigo
  static const violet    = Color(0xFF8B5CF6); // violet
  static const coral     = Color(0xFFFF7A59); // coral
  static const amber     = Color(0xFFF59E0B); // amber
  static const emerald   = Color(0xFF10B981); // emerald
  static const raspberry = Color(0xFFEF4444); // red-ish

  // Light tints
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceTint = Color(0xFFF6FAFF);
  static const border      = Color(0xFFE2E8F0);

  // Distance-based accents (for gradients)
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
  static List<Color> accentFor(String distance, [String? _]) {
    switch (distance) {
      case '50m':  return const [BrandColors.tile1Start, BrandColors.tile1End];
      case '100m': return const [BrandColors.tile2Start, BrandColors.tile2End];
      case '200m': return const [BrandColors.tile3Start, BrandColors.tile3End];
      case '400m': return const [BrandColors.tile4Start, BrandColors.tile4End];
      default:     return const [BrandColors.aqua, BrandColors.blue];
    }
  }

  // App header rainbow
  static const headerGradient = [
    BrandColors.aqua,
    BrandColors.teal,
    BrandColors.blue,
    BrandColors.indigo,
  ];

  // Whole screen gentle background
  static const backgroundGradient = [
    Color(0xFFF9FBFF),
    Color(0xFFF4FAFF),
    Color(0xFFFDF7FF),
  ];
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

const _defaultByDistance = <String, double>{
  '50m':36, '100m':78, '200m':165, '400m':345
};

/// ---- Progress status (predicted vs baseline)
class _Status {
  final String label;
  final Color color;
  final IconData icon;
  const _Status(this.label, this.color, this.icon);
}

/// Distance-aware thresholds so short events need smaller deltas to count.
_Status _progressStatus(double deltaSeconds, String distance) {
  if (deltaSeconds.isNaN || deltaSeconds.isInfinite) {
    return const _Status('No baseline', BrandColors.amber, Icons.thumbs_up_down_rounded);
  }

  // thresholds per distance
  double good, bad;
  switch (distance) {
    case '50m':  good = -0.15; bad = 0.25; break;
    case '100m': good = -0.30; bad = 0.50; break;
    case '200m': good = -0.60; bad = 1.00; break;
    case '400m': good = -1.20; bad = 2.00; break;
    default:     good = -0.30; bad = 0.50;
  }

  if (deltaSeconds <= good) {
    return const _Status('On track', BrandColors.emerald, Icons.thumb_up_rounded);
  }
  if (deltaSeconds > bad) {
    return const _Status('Needs work', BrandColors.raspberry, Icons.thumb_down_rounded);
  }
  return const _Status('Borderline', BrandColors.amber, Icons.thumbs_up_down_rounded);
}

/// ---- Prediction model
class PredictionResult {
  final String timeText;
  final String confidenceText;
  PredictionResult(this.timeText, this.confidenceText);
}

/// Payload returned back to caller (e.g., Performance)
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
  final userProvidedBaseline =
      (bestTimeBaseline != null && bestTimeBaseline.trim().isNotEmpty);
  final baseSec = userProvidedBaseline
      ? _timeStrToSeconds(bestTimeBaseline!)
      : (_defaultByDistance[distance] ?? 90.0);

  double pred = baseSec.isNaN ? (_defaultByDistance[distance] ?? 90.0) : baseSec;

  // Days ahead benefit (taper/time-to-peak)
  final days = DateTime.now().difference(raceDate).inDays;
  if (days < 0) {
    final ahead = (-days).clamp(0, 14);
    pred += -0.11 * ahead; // up to ~ -1.5s at 14 days
  }

  // Water temperature: penalty if far from 27C, tiny bonus if ideal (26.5–27.5C)
  if (waterTempC != null) {
    final d = (waterTempC - 27.0).abs();
    pred += d * 0.12;                 // penalty grows with distance from 27
    if (d <= 0.5) pred -= 0.10;       // small improvement when near-ideal
  }

  // Humidity: penalty >60%, small bonus in 45–60%
  if (humidityPct != null) {
    if (humidityPct > 60) {
      pred += (humidityPct - 60) * 0.02;
    } else if (humidityPct >= 45) {
      pred -= 0.08;                   // slightly favorable comfort band
    }
  }

  // Stroke adjustment: ONLY when no user baseline was provided.
  if (!userProvidedBaseline) {
    if (stroke == 'Breaststroke') pred += 0.25;
    if (stroke == 'Butterfly')    pred += 0.15;
  }

  // Confidence band from input completeness
  int complete = 0;
  if (userProvidedBaseline) complete++;
  if (waterTempC != null)   complete++;
  if (humidityPct != null)  complete++;
  final conf = switch (complete) { 3 => '±0.4s', 2 => '±0.6s', 1 => '±0.9s', _ => '±1.2s' };

  return PredictionResult(_secondsToTimeStr(pred), conf);
}

/// ---- Validators
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
  final d = double.tryParse(v.trim());
  if (d == null) return 'Humidity must be a number';
  if (d < 0 || d > 100) return 'Humidity must be between 0 and 100';
  return null;
}

/// ---- Screen with THREE tabs: Quick Predict + Training & Predict + History
class PredictBestFinishingTimeScreen extends StatefulWidget {
  const PredictBestFinishingTimeScreen({super.key});

  @override
  State<PredictBestFinishingTimeScreen> createState() => _PredictBestFinishingTimeScreenState();
}

class _PredictBestFinishingTimeScreenState extends State<PredictBestFinishingTimeScreen> {
  DateTime _raceDate = DateTime.now();
  String _distance = '100m';
  String _stroke   = 'Freestyle';

  final _baselineCtrl = TextEditingController();
  final _waterCtrl    = TextEditingController();
  final _humidCtrl    = TextEditingController();

  final _quickFormKey = GlobalKey<FormState>();

  bool _predicting = false;
  String? _predicted;
  String? _conf;

  // 👇 helper: always navigate to performance with payload
  void _goToPerformance(PredictionTransfer p) {
    Navigator.of(context).pushNamed('/swimmer-performance', arguments: p);
  }

  @override
  void dispose() {
    _baselineCtrl.dispose(); _waterCtrl.dispose(); _humidCtrl.dispose();
    super.dispose();
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

  Future<void> _doPredict() async {
    if (!_quickFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }
    setState(() { _predicting = true; _predicted = null; _conf = null; });
    final wt = double.tryParse(_waterCtrl.text.trim());
    final hu = double.tryParse(_humidCtrl.text.trim());
    final res = await predictBestTime(
      raceDate: _raceDate,
      distance: _distance,
      stroke: _stroke,
      waterTempC: wt,
      humidityPct: hu,
      bestTimeBaseline: _baselineCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() { _predicting = false; _predicted = res.timeText; _conf = res.confidenceText; });
  }

  void _applyToPerformance() {
    if (_predicted == null) return;
    final wt = double.tryParse(_waterCtrl.text.trim());
    final hu = double.tryParse(_humidCtrl.text.trim());

    // Log a prediction row to History (Quick Predict has no swimmer identity)
    SwimHistoryStore().add(TrainingSession(
      createdAt: DateTime.now(),
      sessionDate: _raceDate,
      distance: _distance,
      stroke: _stroke,
      bestTimeText: _baselineCtrl.text.trim().isEmpty ? null : _baselineCtrl.text.trim(),
      waterTemp: wt,
      humidity: hu,
      predictedTime: _predicted,
      confidence: _conf,
      isPrediction: true,
    ));

    // Take the user straight to Performance with payload
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

  @override
  Widget build(BuildContext context) {
    final colors = BrandTheme.accentFor(_distance);

    // helpers for Quick Predict result
    double? _delta() {
      if (_predicted == null) return null;
      final p = _timeStrToSeconds(_predicted!);
      final b = _timeStrToSeconds(_baselineCtrl.text);
      if (p.isNaN || b.isNaN || b <= 0) return null;
      return p - b; // + slower, - faster
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
            title: const Text('Predict best finishing time'),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandTheme.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                height: 44,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: colors.last.withOpacity(.35), blurRadius: 10, offset: const Offset(0,4))],
                  ),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.9),
                  tabs: const [
                    Tab(icon: Icon(Icons.speed), text: 'Quick Predict'),
                    Tab(icon: Icon(Icons.edit_calendar), text: 'Training & Predict'),
                    Tab(icon: Icon(Icons.history), text: 'History'),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.pool_outlined),
            label: const Text('Add Training Data'),
            backgroundColor: colors.last,
          ),
          body: TabBarView(
            children: [
              // === Tab 1: Quick Predict ===
              Form(
                key: _quickFormKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    // Context header (glass)
                    _GlassCard(
                      borderColor: colors.last.withOpacity(.35),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Set your race context'),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _FieldDateLike(label: 'Race date', value: DateFormat('yyyy-MM-dd').format(_raceDate), onTap: _pickDate)),
                            const SizedBox(width: 10),
                            Expanded(child: _Dropdown(label: 'Distance', value: _distance, items: const ['50m','100m','200m','400m'], onChanged: (v)=>setState(()=>_distance=v!))),
                          ]), 
                          const SizedBox(height: 10),
                          _Dropdown(label: 'Stroke', value: _stroke, items: const ['Freestyle','Backstroke','Breaststroke','Butterfly'], onChanged: (v)=>setState(()=>_stroke=v!)),
                        ],
                      ),
                      gradient: LinearGradient(colors: [colors.first.withOpacity(.15), colors.last.withOpacity(.10)]),
                    ),

                    const SizedBox(height: 16),

                    // Inputs (glass)
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Inputs'),
                          const SizedBox(height: 10),
                          _TextField(
                            label: 'Baseline best time',
                            controller: _baselineCtrl,
                            hint: 'mm:ss.ss or seconds',
                            validator: _requiredTime,
                            icon: Icons.timer_rounded,
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _TextField(label: 'Water Temp', controller: _waterCtrl, keyboardType: TextInputType.number, validator: (v)=>_requiredNum(v, name:'Water temperature'), suffixText: '°C', icon: Icons.water_drop_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _TextField(label: 'Humidity', controller: _humidCtrl, keyboardType: TextInputType.number, validator: _requiredHumidity, suffixText: '%', icon: Icons.air_rounded)),
                          ]),
                          const SizedBox(height: 14),
                          GradientButton(text: 'Predict', onPressed: _predicting ? null : _doPredict, colors: colors, loading: _predicting),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_predicted != null)
                      _GlassCard(
                        borderColor: colors.last.withOpacity(.35),
                        gradient: LinearGradient(colors: [colors.first.withOpacity(.12), colors.last.withOpacity(.08)]),
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
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: status.color),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Confidence: ${_conf ?? "—"}'),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: -6, children: [
                              _Pill(text: 'Date: ${DateFormat('EEE, dd MMM').format(_raceDate)}', tint: colors.first),
                              _Pill(text: 'Distance: $_distance', tint: colors.first),
                              _Pill(text: 'Stroke: $_stroke', tint: colors.first),
                              _StatusPill(status),
                              if (delta != null)
                                _Pill(
                                  text: 'Δ ${(delta >= 0 ? '+' : '')}${delta.toStringAsFixed(2)}s'
                                      '${pct == null ? '' : ' (${(pct >= 0 ? '+' : '')}${pct.toStringAsFixed(1)}%)'}',
                                  tint: status.color,
                                ),
                            ]),
                            const SizedBox(height: 10),
                            GradientButton(text: 'Use in Performance', onPressed: _applyToPerformance, colors: colors),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // === Tab 2: Training & Predict ===
              _TrainingAndPredictTabX(
                selectedDate: _raceDate,
                onPickDate: (d) => setState(() => _raceDate = d),
                distance: _distance,
                onChangeDistance: (v) => setState(() => _distance = v),
                stroke: _stroke,
                onChangeStroke: (v) => setState(() => _stroke = v),
                onSaveBestTime: (bt) { if ((bt ?? '').isNotEmpty) _baselineCtrl.text = bt!; },
                onSaveEnvironment: (wt, hu) {
                  _waterCtrl.text = wt?.toString() ?? '';
                  _humidCtrl.text = hu?.toString() ?? '';
                },
                bestTimeBaseline: _baselineCtrl.text.isEmpty ? null : _baselineCtrl.text,
                onApplyToPerformance: (
                  String predicted,
                  String? conf,
                  String? swimmerId,
                  String? swimmerName,
                  String? competition,
                ) {
                  final wt = double.tryParse(_waterCtrl.text.trim());
                  final hu = double.tryParse(_humidCtrl.text.trim());

                  // Log prediction in History WITH identity
                  SwimHistoryStore().add(TrainingSession(
                    createdAt: DateTime.now(),
                    sessionDate: _raceDate,
                    distance: _distance,
                    stroke: _stroke,
                    swimmerId: swimmerId,
                    swimmerName: swimmerName,
                    competition: competition,
                    bestTimeText: _baselineCtrl.text.trim().isEmpty ? null : _baselineCtrl.text.trim(),
                    waterTemp: wt,
                    humidity: hu,
                    predictedTime: predicted,
                    confidence: conf,
                    isPrediction: true,
                  ));

                  // Go straight to Performance
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

              // === Tab 3: History ===
              const _HistoryTabInsidePredict(),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// ---- “Glass” card helper (tinted gradient + border + soft shadow)
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
      label: Text(text, style: TextStyle(color: tint.darken(0.15))),
    );
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

/// ---- Quick Predict atoms (fancy colorful fields)
class _TextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? hint;
  final String? Function(String?)? validator;
  final String? suffixText;
  final IconData? icon;

  const _TextField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.hint,
    this.validator,
    this.suffixText,
    this.icon,
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
    final active = _hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [BrandColors.aqua, BrandColors.indigo])
            : null,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: BrandColors.border),
        boxShadow: active
            ? const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]
            : const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
            focusNode: _node,
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: widget.hint,
              suffixText: widget.suffixText,
            ),
            validator: widget.validator ?? (v)=>_required(v, name: widget.label),
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
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        gradient: active
            ? const LinearGradient(colors: [BrandColors.teal, BrandColors.indigo])
            : null,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: BrandColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
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
              items: widget.items.map((e) => DropdownMenuItem(value: e, child: Row(
                children: [
                  const Icon(Icons.pool_rounded, size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(e),
                ],
              ))).toList(),
              onChanged: widget.onChanged,
              icon: const Icon(Icons.expand_more_rounded),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Public GradientButton (used by both tabs)
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final bool loading;
  const GradientButton({super.key, required this.text, required this.onPressed, required this.colors, this.loading = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: colors.last.withOpacity(.35), blurRadius: 12, offset: const Offset(0,6))],
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
/// Training + Predict tab (colorful styles kept across controls)
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

  /// Callback to send result back to parent screen
  final void Function(
    String predicted,
    String? confidence,
    String? swimmerId,
    String? swimmerName,
    String? competition,
  ) onApplyToPerformance;

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
  });

  @override
  State<_TrainingAndPredictTabX> createState() => _TrainingAndPredictTabXState();
}

class _TrainingAndPredictTabXState extends State<_TrainingAndPredictTabX> {
  final _idCtrl    = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _compCtrl  = TextEditingController();
  final _bestCtrl  = TextEditingController();
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
    _idCtrl.dispose(); _nameCtrl.dispose(); _compCtrl.dispose(); _bestCtrl.dispose(); _waterCtrl.dispose(); _humidCtrl.dispose();
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
    if (picked != null) setState(() { _bestTimeDate = picked; _showBestTimeDateError = false; });
  }

  bool _validateAll() {
    final valid = _formKey.currentState!.validate();
    final bestDateOk = _bestTimeDate != null;
    setState(() => _showBestTimeDateError = !bestDateOk);
    return valid && bestDateOk;
  }

  Future<void> _save() async {
    if (!_validateAll()) {
      setState(() { _error = 'Please fill all required fields.'; });
      return;
    }
    setState(() { _saving = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 250));
    widget.onSaveBestTime(_bestCtrl.text.trim());
    final wt = double.tryParse(_waterCtrl.text.trim());
    final hu = double.tryParse(_humidCtrl.text.trim());
    widget.onSaveEnvironment(wt, hu);

    // write to history store
    SwimHistoryStore().add(TrainingSession(
      createdAt: DateTime.now(),
      sessionDate: widget.selectedDate,
      distance: widget.distance,
      stroke: widget.stroke,
      swimmerId: _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
      swimmerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      competition: _compCtrl.text.trim().isEmpty ? null : _compCtrl.text.trim(),
      bestTimeText: _bestCtrl.text.trim(),
      bestTimeDate: _bestTimeDate,
      waterTemp: wt,
      humidity: hu,
      isPrediction: false,
    ));

    setState(() { _saving = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Training session saved')));
    }
  }

  Future<void> _predict() async {
    if (!_validateAll()) {
      setState(() { _error = 'Please fill all required fields.'; });
      return;
    }
    setState(() { _predicting = true; _error = null; _predicted = null; _predConf = null; });
    try {
      final wt = double.tryParse(_waterCtrl.text.trim());
      final hu = double.tryParse(_humidCtrl.text.trim());
      final res = await predictBestTime(
        raceDate: widget.selectedDate,
        distance: widget.distance,
        stroke: widget.stroke,
        waterTempC: wt,
        humidityPct: hu,
        bestTimeBaseline: _bestCtrl.text.trim(),
      );
      setState(() { _predicted = res.timeText; _predConf = res.confidenceText; });
    } catch (_) {
      setState(() { _error = 'Could not generate prediction. Please try again.'; });
    } finally {
      if (mounted) setState(() { _predicting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final bestDateText = _bestTimeDate == null ? 'Pick date' : DateFormat('yyyy-MM-dd').format(_bestTimeDate!);
    final accent = BrandTheme.accentFor(widget.distance, widget.stroke);

    // progress calc for Training tab
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

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _GlassCard(
            gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF7FBFF)]),
            child: Row(children: [
              Icon(Icons.edit_calendar, color: accent.last),
              const SizedBox(width: 8),
              const Text('Add your training session', style: TextStyle(fontWeight: FontWeight.w800, color: BrandColors.headline)),
            ]),
          ),
          const SizedBox(height: 12),

          const _SectionLabelX('Basic Info'),
          _InputFieldX(label: 'Swimmer ID', controller: _idCtrl, validator: (v)=>_required(v, name:'Swimmer ID'), icon: Icons.badge_rounded),
          const SizedBox(height: 10),
          _InputFieldX(label: 'Swimmer Name', controller: _nameCtrl, validator: (v)=>_required(v, name:'Swimmer Name'), icon: Icons.person_rounded),
          const SizedBox(height: 10),

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
          _InputFieldX(label: 'Competition', controller: _compCtrl, validator: (v)=>_required(v, name:'Competition'), icon: Icons.emoji_events_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InputFieldX(label: 'Best time', controller: _bestCtrl, validator: _requiredTime, icon: Icons.timer_rounded, hint: 'mm:ss.ss or seconds')),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    _TapFieldX(label: 'Best time date', value: bestDateText, onTap: _pickBestTimeDate, icon: Icons.calendar_month_rounded),
                    if (_showBestTimeDateError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Best time date is required', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const _SectionLabelX('Environmental Factors'),
          _InputFieldX(label: 'Water Temp', controller: _waterCtrl, keyboard: TextInputType.number, validator: (v)=>_requiredNum(v, name:'Water temperature'), icon: Icons.water_drop_rounded, suffixText: '°C'),
          const SizedBox(height: 10),
          _InputFieldX(label: 'Humidity', controller: _humidCtrl, keyboard: TextInputType.number, validator: _requiredHumidity, icon: Icons.air_rounded, suffixText: '%'),

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
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
              child: Row(children: [Icon(Icons.error_outline, color: Colors.red.shade400), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700)))]),
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
                  if (d != null)
                    _Pill(text: 'Δ ${(d >= 0 ? '+' : '')}${d.toStringAsFixed(2)}s'
                        '${p == null ? '' : ' (${(p >= 0 ? '+' : '')}${p.toStringAsFixed(1)}%)'}', tint: status.color),
                ]),
                const SizedBox(height: 10),
                GradientButton(
                  text: 'Use in Performance',
                  onPressed: () => widget.onApplyToPerformance(
                    _predicted!,
                    _predConf,
                    _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
                    _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
                    _compCtrl.text.trim().isEmpty ? null : _compCtrl.text.trim(),
                  ),
                  colors: accent,
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// ---- HISTORY TAB (inside predictor)
class _HistoryTabInsidePredict extends StatefulWidget {
  const _HistoryTabInsidePredict();
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // newest first
    final items = List<TrainingSession>.from(_store.items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = items[i];
        final isPred = s.isPrediction;
        final colors = BrandTheme.accentFor(s.distance, s.stroke);

        return Container(
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
        );
      },
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

/// ---- Small UI atoms for Training tab (colorful)
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
  const _InputFieldX({
    required this.label,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.hint,
    this.validator,
    this.suffixText,
    this.icon,
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
    final active = _hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [BrandColors.teal, BrandColors.indigo])
            : null,
        borderRadius: BorderRadius.circular(12),
        border: active ? null : Border.all(color: BrandColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
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
            focusNode: _node,
            controller: widget.controller,
            keyboardType: widget.keyboard,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: widget.hint,
              suffixText: widget.suffixText,
            ),
            validator: widget.validator ?? (v)=>_required(v, name: widget.label),
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
        gradient: active
            ? const LinearGradient(colors: [BrandColors.violet, BrandColors.indigo])
            : null,
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

/// ---- Color helper
extension _ColorX on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    final h = hsl.hue, s = hsl.saturation, l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return HSLColor.fromAHSL(hsl.alpha, h, s, l).toColor();
  }
}
