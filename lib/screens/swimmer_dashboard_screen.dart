// lib/screens/swimmer_dashboard_screen.dart
// ignore_for_file: deprecated_member_use, unused_element_parameter, unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; //  added
import '../models/swim_history_store.dart';


/// ===== Tunable thresholds (team-specific) =====
const double kAccHighMaxRatio     = 0.006;
const double kAccMedHighMaxRatio  = 0.009;
const double kAccMediumMaxRatio   = 0.013;

/// ===== Colors & accents by distance =====

class BrandColors {
  static const headline = Color(0xFF072A40);

  // Primary ocean palette (blue family)
  static const aqua    = Color(0xFF38BDF8); // light aqua blue
  static const sea     = Color(0xFF0EA5E9); // sky/sea blue
  static const deep    = Color(0xFF0369A1); // deep ocean blue
  static const teal    = Color(0xFF0284C7); // blue-leaning teal
  static const coral   = Color(0xFF2563EB); // repurposed: vivid blue
  static const amber   = Color(0xFF3B82F6); // repurposed: bright blue
  static const violet  = Color(0xFF1D4ED8); // repurposed: strong indigo/blue

  // Distance tiles (now all blue gradients)
  static const tile1Start = aqua;                 // 50m — light aqua
  static const tile1End   = sea;                  // → sea blue
  static const tile2Start = coral;                // 100m — vivid blue
  static const tile2End   = Color(0xFF60A5FA);    // soft blue end
  static const tile3Start = violet;               // 200m — indigo/blue
  static const tile3End   = Color(0xFF93C5FD);    // pale blue end
  static const tile4Start = teal;                 // 400m — blue teal
  static const tile4End   = Color(0xFF38BDF8);    // aqua end

  // Surfaces & subtle UI tokens
  static const chipBg   = Color(0xFFF1FAFF);
  static const cardBg   = Color(0xFFFFFFFF);
  static const divider  = Color(0xFFE6EEF6);
  static const subtleBg = Color(0xFFF7FBFF);
  static const muted    = Color(0xFF64748B);

  // Semantic helpers (kept as is)
  static const success  = Color(0xFF16A34A);
  static const warning  = Color(0xFFF59E0B);
  static const danger   = Color(0xFFEF4444);
}

List<Color> _accentFor(String distance) {
  switch (distance) {
    case '50m':  return const [BrandColors.tile1Start, BrandColors.tile1End];
    case '100m': return const [BrandColors.tile2Start, BrandColors.tile2End];
    case '200m': return const [BrandColors.tile3Start, BrandColors.tile3End];
    case '400m': return const [BrandColors.tile4Start, BrandColors.tile4End];
    default:     return const [BrandColors.tile1Start, BrandColors.tile1End];
  }
}

/// Distance sort priority
const _distanceOrder = {'50m': 0, '100m': 1, '200m': 2, '400m': 3};

class SwimmerDashboardScreen extends StatefulWidget {
  const SwimmerDashboardScreen({super.key});
  @override
  State<SwimmerDashboardScreen> createState() => _SwimmerDashboardScreenState();
}

class _SwimmerDashboardScreenState extends State<SwimmerDashboardScreen> {
  final _store = SwimHistoryStore();
  Timer? _ticker; // live refresh for countdowns
  String _distanceFilter = 'All';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {}); // keep countdown fresh
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // Parse "mm:ss.xx" or seconds -> total seconds
  double _timeToSeconds(String? t) {
    if (t == null || t.trim().isEmpty) return double.nan;
    final s = t.trim();
    final i = s.indexOf(':');
    try {
      if (i >= 0) {
        final mm = int.parse(s.substring(0, i));
        final ss = double.parse(s.substring(i + 1));
        return mm * 60 + ss;
      }
      return double.parse(s);
    } catch (_) {
      return double.nan;
    }
  }

  // Try to find a baseline for a prediction row if it's missing/invalid.
  double _resolveBaselineSeconds(TrainingSession s) {
    final fromSelf = _timeToSeconds(s.bestTimeText);
    if (!fromSelf.isNaN && fromSelf > 0) return fromSelf;

    TrainingSession? candidate;

    bool sameEvent(TrainingSession t) =>
        !t.isPrediction && t.distance == s.distance && t.stroke == s.stroke;

    bool sameSwimmer(TrainingSession t) {
      final idOk   = (s.swimmerId?.isNotEmpty == true)   && s.swimmerId == t.swimmerId;
      final nameOk = (s.swimmerName?.isNotEmpty == true) && s.swimmerName == t.swimmerName;
      return idOk || nameOk;
    }

    for (final t in _store.items) {
      if (sameEvent(t) && sameSwimmer(t) && (t.bestTimeText?.isNotEmpty ?? false)) {
        if (candidate == null || t.sessionDate.isAfter(candidate!.sessionDate)) {
          candidate = t;
        }
      }
    }

    candidate ??= _store.items
        .where((t) => sameEvent(t) && (t.bestTimeText?.isNotEmpty ?? false))
        .fold<TrainingSession?>(null, (prev, t) {
      if (prev == null || t.sessionDate.isAfter(prev.sessionDate)) return t;
      return prev;
    });

    return _timeToSeconds(candidate?.bestTimeText);
  }

  // Friendly time-to-go/ago string
  String _timeLeftText(DateTime target) {
    final now = DateTime.now();
    final diff = target.difference(now);
    if (diff.inSeconds.abs() < 60) return 'Now';
    if (diff.isNegative) {
      final ad = diff.abs();
      if (ad.inDays >= 1) return '${ad.inDays}d ago';
      if (ad.inHours >= 1) return '${ad.inHours}h ago';
      return '${ad.inMinutes}m ago';
    } else {
      if (diff.inDays >= 1) return '${diff.inDays}d to go';
      if (diff.inHours >= 1) return '${diff.inHours}h to go';
      return '${diff.inMinutes}m to go';
    }
  }

  /// === Dynamic accuracy band derived from predicted time ===
  ({double bandSec, double ratio}) _bandForSession(TrainingSession s) {
    final pred = _timeToSeconds(s.predictedTime);
    if (pred.isNaN || pred <= 0) return (bandSec: double.nan, ratio: double.nan);

    final double baseFactor =

        (pred <= 45) ? 0.006 :
        (pred <= 90) ? 0.007 :
        (pred <= 180) ? 0.008 : 0.009;


    final hasBaseline = !_timeToSeconds(s.bestTimeText).isNaN;
    final hasWater    = s.waterTemp != null;
    final hasHumid    = s.humidity  != null;

    double penalty = 1.0;
    if (!hasBaseline) penalty *= 1.15;
    if (!hasWater)    penalty *= 1.10;
    if (!hasHumid)    penalty *= 1.10;

    double band = pred * baseFactor * penalty;

    band = band.clamp(0.12, double.infinity);


    return (bandSec: band, ratio: band / pred);
  }

  ({String label, Color color}) _accuracyFromRatio(double ratio) {
    if (ratio.isNaN) return (label: 'Unknown', color: Colors.grey);
    if (ratio <= 0.006) return (label: 'High',      color: const Color(0xFF16A34A));
    if (ratio <= 0.009) return (label: 'Med-High',  color: const Color(0xFF22C55E));
    if (ratio <= 0.013) return (label: 'Medium',    color: const Color(0xFFF59E0B));
    return (label: 'Low', color: const Color(0xFFEF4444));
  }

  String _displayNameFor(TrainingSession s) => 'Swimmer';
  String _initials(String? text) => '—';

  String _fmtBand(double bandSec) {
    if (bandSec.isNaN) return '—';
    return bandSec >= 1 ? '±${bandSec.toStringAsFixed(1)}s'
                        : '±${bandSec.toStringAsFixed(2)}s';
  }

  // ===== Group rows by date + sort inside groups + optional distance filter
  List<_DateGroup> _buildDateGroups(Iterable<TrainingSession> source) {
    final filtered = _distanceFilter == 'All'
        ? source
        : source.where((s) => s.distance == _distanceFilter);

    // Best (fastest) per swimmer+date+event
    final Map<String, TrainingSession> bestByKey = {};
    for (final s in filtered) {
      final key =
          '${s.swimmerId ?? "-"}|${s.swimmerName ?? "-"}|${DateFormat('yyyy-MM-dd').format(s.sessionDate)}|${s.distance}|${s.stroke}';
      final cur = bestByKey[key];
      if (cur == null || _timeToSeconds(s.predictedTime) < _timeToSeconds(cur.predictedTime)) {
        bestByKey[key] = s;
      }
    }
    final list = bestByKey.values.toList();

    // Group by date
    final Map<String, List<TrainingSession>> byDate = {};
    for (final s in list) {
      final k = DateFormat('yyyy-MM-dd').format(s.sessionDate);
      byDate.putIfAbsent(k, () => []).add(s);
    }

    // Sort
    final groups = <_DateGroup>[];
    final keys = byDate.keys.toList()..sort();
    for (final k in keys) {
      final parsed = DateTime.parse(k);
      final items = byDate[k]!..sort((a, b) {
        final d1 = _distanceOrder[a.distance] ?? 99;
        final d2 = _distanceOrder[b.distance] ?? 99;
        if (d1 != d2) return d1.compareTo(d2);
        final n1 = (_displayNameFor(a)).toLowerCase();
        final n2 = (_displayNameFor(b)).toLowerCase();
        if (n1 != n2) return n1.compareTo(n2);
        return a.stroke.compareTo(b.stroke);
      });
      groups.add(_DateGroup(date: parsed, items: items));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // 🔒 If not signed in, show a friendly prompt (no data shown)
    if (uid == null) {
      return Scaffold(
        backgroundColor: BrandColors.subtleBg,
        appBar: AppBar(
          title: const Text('Swimmer Dashboard'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Sign in to see your upcoming predictions.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 👇 Only the current user's items
    final myItems = _store.items.where((s) => s.swimmerId == uid);

    // FUTURE predictions (incl. today)
    final upcoming = myItems.where((r) =>
        r.isPrediction &&
        (DateTime(r.sessionDate.year, r.sessionDate.month, r.sessionDate.day).isAfter(today) ||
         DateUtils.isSameDay(r.sessionDate, today)));

    // ===== TODAY OVERVIEW (mine only) =====
    final todayPreds = myItems.where(
      (r) => r.isPrediction && DateUtils.isSameDay(r.sessionDate, today),
    );

    final Map<String, _Agg> aggBySwimmer = {};
    for (final p in todayPreds) {
      final key = '${p.swimmerId ?? ""}|${p.swimmerName ?? ""}';
      final dispName = _displayNameFor(p); // "Swimmer"
      final (bandSec: band, ratio: ratio) = _bandForSession(p);

      aggBySwimmer.putIfAbsent(key, () => _Agg(name: dispName));
      aggBySwimmer[key]!.strokes.add(p.stroke);
      aggBySwimmer[key]!.distances.add(p.distance);
      aggBySwimmer[key]!.events.add('${p.distance} ${p.stroke}');

      if (!band.isNaN && !ratio.isNaN) {
        aggBySwimmer[key]!.bandsSec.add(band);
        aggBySwimmer[key]!.ratios.add(ratio);
      } else {
        aggBySwimmer[key]!.unknownCount++;
      }
      aggBySwimmer[key]!.totalCount++;
    }
    final swimmerAgg = aggBySwimmer.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    // Team averages for today (in this screen: effectively "my" averages)
    final allBands  = swimmerAgg.expand((a) => a.bandsSec).toList();
    final allRatios = swimmerAgg.expand((a) => a.ratios).toList();

    final teamAvgBandSec = allBands.isEmpty
        ? double.nan
        : allBands.reduce((a, b) => a + b) / allBands.length;

    final teamAvgRatio = allRatios.isEmpty
        ? double.nan
        : allRatios.reduce((a, b) => a + b) / allRatios.length;

    final teamAcc = _accuracyFromRatio(teamAvgRatio);

    // Counts

    final eventsToday = todayPreds.map((e) => '${e.distance}|${e.stroke}').toSet().length;


    // Groups (ordered)
    final groups = _buildDateGroups(upcoming);

    // Header accent
    final headerAccent = groups.isNotEmpty
        ? _accentFor(groups.first.items.first.distance)
        : const [BrandColors.tile1Start, BrandColors.tile1End];

    return Scaffold(
      backgroundColor: BrandColors.subtleBg,
      appBar: AppBar(
        title: const Text('Swimmer Dashboard'),
        flexibleSpace: groups.isNotEmpty
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: headerAccent,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              )
            : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: groups.isEmpty
          ? _EmptyState(onClear: _store.clear)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [

                if (todayPreds.isNotEmpty) ...[
                  // Swimming-themed header — adjusted sizes

                  _TodayOverviewHeaderQuality(
                    accent: headerAccent,
                    avgText: _fmtBand(teamAvgBandSec),
                    teamColor: teamAcc.color,
                    teamLabel: teamAcc.label,
                    teamRatio: teamAvgRatio,
                    events: eventsToday,

                  ),
                  const SizedBox(height: 16),

                  _SectionDivider(title: 'Upcoming predictions', accent: headerAccent),
                ],

                // Filter row
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: _FilterBar(
                    active: _distanceFilter,
                    onChange: (v) => setState(() => _distanceFilter = v),
                  ),
                ),

                // Date groups with cards
                for (final g in groups) ...[
                  _DateHeader(date: g.date, accent: _accentFor(g.items.first.distance)),
                  const SizedBox(height: 10),
                  for (final s in g.items) ...[
                    _buildUpcomingCard(s),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _buildUpcomingCard(TrainingSession s) {
    final accent = _accentFor(s.distance);

    final secsPred = _timeToSeconds(s.predictedTime);
    final secsBaseResolved = _resolveBaselineSeconds(s);

    final hasBaseline = !secsBaseResolved.isNaN;
    final delta = (hasBaseline && !secsPred.isNaN) ? secsPred - secsBaseResolved : double.nan;
    final pct   = (!delta.isNaN && secsBaseResolved > 0) ? (delta / secsBaseResolved) * 100 : double.nan;

    final status = _progressStatus(delta);

    final (bandSec: band, ratio: ratio) = _bandForSession(s);
    final acc   = _accuracyFromRatio(ratio);
    final accStr = '${acc.label} · ${_fmtBand(band)}';

    return _UpcomingCard(
      s: s,
      accent: accent,
      status: status,
      delta: delta,
      pct: pct,
      timeLeftText: _timeLeftText(s.sessionDate),
      accuracyLabel: accStr,
      accuracyColor: acc.color,
    );
  }

  _Status _progressStatus(double deltaSeconds) {
    if (deltaSeconds.isNaN || deltaSeconds.isInfinite) {
      return const _Status(label: 'No baseline', color: Color(0xFFF59E0B), icon: Icons.thumbs_up_down_rounded);
    }
    if (deltaSeconds <= -0.30) {
      return const _Status(label: 'On track', color: Color(0xFF22C55E), icon: Icons.thumb_up_rounded);
    }
    if (deltaSeconds > 0.50) {
      return const _Status(label: 'Needs work', color: Color(0xFFEF4444), icon: Icons.thumb_down_rounded);
    }
    return const _Status(label: 'Borderline', color: Color(0xFFF59E0B), icon: Icons.thumbs_up_down_rounded);
  }
}

/// ===== Models for grouping =====
class _DateGroup {
  _DateGroup({required this.date, required this.items});
  final DateTime date;
  final List<TrainingSession> items;
}

/// ===== Overview aggregation =====
class _Agg {
  _Agg({required this.name});
  final String name;
  final List<double> bandsSec = [];
  final List<double> ratios   = [];
  final Set<String> strokes   = {};
  final Set<String> distances = {};
  final Set<String> events    = {};
  int totalCount = 0;
  int unknownCount = 0;

  double get avgBandSec =>
      bandsSec.isEmpty ? double.nan : bandsSec.reduce((a, b) => a + b) / bandsSec.length;

  double get avgRatio =>
      ratios.isEmpty ? double.nan : ratios.reduce((a, b) => a + b) / ratios.length;
}

/// ===== Small UI atoms =====
class _SectionDivider extends StatelessWidget {
  final String title;
  final List<Color> accent;
  const _SectionDivider({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: BrandColors.divider)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accent.first.withOpacity(.15), accent.last.withOpacity(.12)]),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accent.last.withOpacity(.28)),
          ),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        Expanded(child: Container(height: 1, color: BrandColors.divider)),
      ],
    );
  }
}


/// ===== Today header with quality gauge (swimming-themed, adjusted sizes) =====

class _TodayOverviewHeaderQuality extends StatelessWidget {
  final List<Color> accent;
  final String avgText;
  final Color teamColor;
  final String teamLabel;
  final double teamRatio; // band/pred ratio

  // Only Events left (swimmer & prediction tabs removed)
  final int events;

  const _TodayOverviewHeaderQuality({
    super.key,
    required this.accent,
    required this.avgText,
    required this.teamColor,
    required this.teamLabel,
    required this.teamRatio,
    required this.events,
  });

  double _qualityPos(double r) {
    if (r.isNaN) return .5;
    final clamped = r.clamp(0.004, 0.02);
    return ((clamped - 0.004) / (0.02 - 0.004)).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('EEE, dd MMM').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(18), // ↑ padding
      decoration: BoxDecoration(
        color: BrandColors.cardBg,
        borderRadius: BorderRadius.circular(20), // ↑ radius
        border: Border.all(color: accent.last.withOpacity(.25)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(

                padding: const EdgeInsets.all(9),

              

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: accent),
                  borderRadius: BorderRadius.circular(14),
                ),

                child: const Icon(Icons.pool_rounded, color: Colors.white),

              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Today prediction quality',
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,

                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),

                ),
              ),
              const SizedBox(width: 8),
              Chip(label: Text(todayStr), backgroundColor: BrandColors.chipBg),
            ],
          ),
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: Chip(
              label: Text(todayStr, style: const TextStyle(fontSize: 13)),
              backgroundColor: BrandColors.subtleBg,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            ),
          ),
          const SizedBox(height: 10),


          // Average + Team badge (also slightly smaller)
          Row(
            children: [
              Text('Avg $avgText',

                  style: TextStyle(fontSize: 19.5, fontWeight: FontWeight.w900, color: teamColor)),
              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // ↑ pill
                decoration: BoxDecoration(
                  color: teamColor.withOpacity(.10),

                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: teamColor.withOpacity(.35)),
                ),
                child: Text('Team: $teamLabel',
                    style: TextStyle(color: teamColor, fontWeight: FontWeight.w700, fontSize: 12)),

              ),
            ],
          ),

          const SizedBox(height: 14),

          // Quality gauge bar (larger)
          LayoutBuilder(
            builder: (context, c) {
              final pos = _qualityPos(teamRatio) * (c.maxWidth - 24);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(

                        height: 9,

                       

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF22C55E)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: pos,
                        top: -3,
                        child: Container(

                          width: 4,
                          height: 13,

                       

                          decoration: BoxDecoration(
                            color: teamColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Low', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text('High', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),


          // Only one KPI left (Events) — swimmer & predictions removed
          Row(
            children: const [
              Expanded(
                child: _KpiTile(
                  icon: Icons.flag_rounded,
                  label: 'Events',
                  value: '', // value is set by parent via text below
                ),
              ),


            ],
          ),

          // Small text to show the actual events count clearly
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$events total today',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _KpiTile({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), // ↑ padding
      decoration: BoxDecoration(
        color: BrandColors.subtleBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.divider),
      ),
      child: Row(
        children: [

          Icon(icon, size: 18, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),

        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final List<Color> accent;
  const _DateHeader({required this.date, required this.accent});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dOnly = DateTime(date.year, date.month, date.day);
    final tOnly = DateTime(today.year, today.month, today.day);

    String label;
    if (DateUtils.isSameDay(dOnly, tOnly)) {
      label = 'Today';
    } else if (DateUtils.isSameDay(dOnly, tOnly.add(const Duration(days: 1)))) {
      label = 'Tomorrow';
    } else {
      label = DateFormat('EEE, dd MMM').format(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BrandColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [accent.first.withOpacity(.10), accent.last.withOpacity(.06)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: accent.last.withOpacity(.25)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: accent),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChange;
  const _FilterBar({required this.active, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final items = const ['All', '50m', '100m', '200m', '400m'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        final selected = e == active;
        return ChoiceChip(
          selected: selected,
          label: Text(e),
          selectedColor: Colors.blue.withOpacity(.15),
          backgroundColor: BrandColors.cardBg,
          side: BorderSide(color: selected ? Colors.blue.shade300 : BrandColors.divider),
          labelStyle: TextStyle(
            color: selected ? Colors.blue.shade800 : Colors.black87,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          onSelected: (_) => onChange(e),
        );
      }).toList(),
    );
  }
}

/// ===== Upcoming card =====
class _UpcomingCard extends StatelessWidget {
  final TrainingSession s;
  final List<Color> accent;
  final _Status status;
  final double delta; // predicted - best (seconds)
  final double pct;   // % vs baseline
  final String timeLeftText;
  final String accuracyLabel;       // "High · ±0.42s"
  final Color accuracyColor;

  const _UpcomingCard({
    required this.s,
    required this.accent,
    required this.status,
    required this.delta,
    required this.pct,
    required this.timeLeftText,
    required this.accuracyLabel,
    required this.accuracyColor,
    super.key,
  });

  String _deltaText() {
    if (delta.isNaN || delta.isInfinite) return '—';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(2)}s';
  }

  String _pctText() {
    if (pct.isNaN || pct.isInfinite) return '';
    final sign = pct > 0 ? '+' : '';
    return ' ($sign${pct.toStringAsFixed(1)}%)';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, dd MMM').format(s.sessionDate);

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
        border: Border.all(color: accent.last.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top ribbon
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: accent),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: event + date + countdown
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: accent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_available, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${s.distance} • ${s.stroke}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    Wrap(spacing: 8, children: [
                      _chip(dateStr),

                      _chipWithIcon(Icons.hourglass_bottom_rounded, timeLeftText, Colors.blue),
                    ]),

                  ],
                ),

                const SizedBox(height: 10),

                // Details row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BrandColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prediction', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(status.icon, color: status.color, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  s.predictedTime ?? '—',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: status.color),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Δ vs baseline', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 2),
                            Text(
                              '${_deltaText()}${_pctText()}',
                              style: TextStyle(
                                color: status.color.withOpacity(.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Info pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: status.color.withOpacity(.15),
                        child: Icon(status.icon, color: status.color, size: 16),
                      ),
                      label: Text(status.label),
                      backgroundColor: status.color.withOpacity(.10),
                      labelStyle: TextStyle(color: status.color),
                      side: BorderSide(color: status.color.withOpacity(.35)),
                    ),
                    if ((s.competition ?? '').isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.emoji_events_outlined, size: 16, color: Colors.blue),
                        label: Text(s.competition!, overflow: TextOverflow.ellipsis),
                        backgroundColor: Colors.blue.withOpacity(.10),
                      ),
                    Chip(
                      avatar: const Icon(Icons.insights_rounded, size: 16, color: Colors.indigo),
                      label: Text('Accuracy: $accuracyLabel', overflow: TextOverflow.ellipsis),
                      backgroundColor: accuracyColor.withOpacity(.10),
                      labelStyle: TextStyle(color: accuracyColor),
                      side: BorderSide(color: accuracyColor.withOpacity(.35)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t) =>
      Chip(label: Text(t), backgroundColor: BrandColors.subtleBg);

  Widget _chipWithIcon(IconData icon, String t, Color c) => Chip(
        avatar: Icon(icon, size: 16, color: c),
        label: Text(t),
        backgroundColor: c.withOpacity(.08),
        labelStyle: TextStyle(color: c),
        side: BorderSide(color: c.withOpacity(.25)),
      );
}

class _Status {
  final String label;
  final Color color;
  final IconData icon;
  const _Status({required this.label, required this.color, required this.icon});
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('No upcoming predictions yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Save a prediction with a future race date to see it here.', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear History'),
            ),
          ],
        ),
      ),
    );
  }
}
