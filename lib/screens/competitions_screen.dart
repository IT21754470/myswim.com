// lib/screens/competition_screen.dart
// ignore_for_file: deprecated_member_use, unused_element_parameter, unused_element

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// ✅ Logged-in swimmer scope
import 'package:firebase_auth/firebase_auth.dart';

// Screens you already have / created elsewhere
import 'swimmer_performance_screen.dart';
import 'predict_best_finishing_time_screen.dart';
import 'swimmer_dashboard_screen.dart';

// In-memory store
import '../models/swim_history_store.dart';

/// ===== Brand palette (page light; colorful “swim” UI parts) =====
class BrandColors {
  // Page
  static const background = Color(0xFFF6FAFF); // soft light
  static const headline   = Color(0xFF0F172A);

  // AppBar (still light but a touch of color)
  static const headerStart = Color(0xFFBDEBFF); // aqua sky
  static const headerEnd   = Color(0xFFDCEBFF); // pale indigo

  // Light surfaces
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8FAFC);
  static const border     = Color(0xFFD6E6F2);

  // Aquatic accents (more saturated)
  static const primary = Color(0xFF0E7C86); // teal
  static const info    = Color(0xFF0EA5E9); // sky
  static const good    = Color(0xFF10B981); // emerald
  static const warn    = Color(0xFFF59E0B); // amber
  static const accent1 = Color(0xFF3B82F6); // blue

  // Feature card gradients (colorful)
  static const f1Start = Color(0xFF00C6FF); // cyan
  static const f1End   = Color(0xFF0072FF); // deep blue
  static const f2Start = Color(0xFF34D399); // emerald
  static const f2End   = Color(0xFF06B6D4); // teal/cyan
  static const f3Start = Color(0xFFA78BFA); // violet
  static const f3End   = Color(0xFF6366F1); // indigo

  // Snapshot background wash
  static const snapStart = Color(0xFFE6FBFF);
  static const snapEnd   = Color(0xFFE7EEFF);

  // Pills on light (text)
  static const pillText = Color(0xFF064E77); // deeper aqua text
}

/// ------ Snapshot model (driven by real data) ------
class CompetitionStats {
  final String upcoming;      // upcoming competitions count
  final String predictions;   // prediction rows count
  final String trainings;     // training rows count
  CompetitionStats({
    required this.upcoming,
    required this.predictions,
    required this.trainings,
  });
}

Future<CompetitionStats> fetchCompetitionStats({
  required DateTime date,
  required String distance,
  required String stroke,
  String? userId, // ✅ scope by swimmer
}) async {
  await Future.delayed(const Duration(milliseconds: 50)); // keep async shape

  final store = SwimHistoryStore();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // ✅ Filter by logged-in swimmer when available
  final items = store.items.where((r) {
    if (userId == null) return false; // no data if not signed in
    return r.swimmerId == userId;
  }).toList();

  final upcomingCompetitions = items.where((r) =>
      (r.competition?.trim().isNotEmpty ?? false) &&
      (DateTime(r.sessionDate.year, r.sessionDate.month, r.sessionDate.day)
              .isAfter(today) ||
          DateUtils.isSameDay(r.sessionDate, today)));

  final predictionCount = items.where((r) => r.isPrediction).length;
  final trainingCount = items.where((r) => !r.isPrediction).length;

  return CompetitionStats(
    upcoming: upcomingCompetitions.length.toString(),
    predictions: predictionCount.toString(),
    trainings: trainingCount.toString(),
  );
}

/// =======================
/// Competition Screen
/// =======================
class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  DateTime selectedDate = DateTime.now();
  String selectedDistance = '100m';
  String selectedStroke = 'Freestyle';

  // ✅ track logged-in swimmer
  String? _uid;
  late final StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() => _uid = user?.uid);
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateOnly = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandColors.headerStart, BrandColors.headerEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.headline),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Competition',
          style: TextStyle(color: BrandColors.headline, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BrandColors.headline),
            onPressed: () => setState(() {}), // re-run loaders
          ),
        ],
      ),
      body: RefreshIndicator(
        color: BrandColors.primary,
        backgroundColor: BrandColors.surface,
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // 🔁 Performance Snapshot (colorful but light)
            _HeaderStatsCard(
              titleText: "Performance Snapshot",
              staticSubtitle: _uid == null
                  ? "Sign in to see your competitions, predictions and training volume."
                  : "At a glance: meets on the calendar, prediction count, and training volume—updated as you add data.",
              dateValue: dateOnly,
              loader: () => fetchCompetitionStats(
                date: selectedDate,
                distance: selectedDistance,
                stroke: selectedStroke,
                userId: _uid, // ✅ pass swimmer
              ),
              contextChips: const [],
            ),

            const SizedBox(height: 20),
            const Text(
              'Choose Feature',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: BrandColors.headline,
              ),
            ),
            const SizedBox(height: 12),

            // 1) Predict best finishing time
            _FeatureCardAqua(
              title: 'Predict best finishing time',
              subtitle: 'Get your estimated finishing time',
              icon: Icons.trending_up,
              start: BrandColors.f1Start,
              end: BrandColors.f1End,
              onTap: _openPredictModal,
            ),
            const SizedBox(height: 10),

            // 2) Swimmer Performance
            _FeatureCardAqua(
              title: 'Swimmer Performance',
              subtitle: 'AI-powered best-time prediction',
              icon: Icons.speed,
              start: BrandColors.f2Start,
              end: BrandColors.f2End,
              onTap: _openSwimmerPerformance,
            ),
            const SizedBox(height: 10),

            // 3) Swimmer Dashboard
            _FeatureCardAqua(
              title: 'Swimmer Dashboard',
              subtitle: 'Upcoming competitions & best predicted time',
              icon: Icons.dashboard_customize_rounded,
              start: BrandColors.f3Start,
              end: BrandColors.f3End,
              onTap: _openSwimmerDashboard,
            ),

            // ——— Only ONE upcoming competitions section (list)
            const SizedBox(height: 22),
            _UpcomingCompetitionsList(currentUserId: _uid),

            const SizedBox(height: 12),
            const _SimpleInfoCard(
              icon: Icons.local_fire_department_outlined,
              title: 'Training Streak',
              body: 'Keep a 5+ day streak to unlock peak readiness insights.',
            ),
          ],
        ),
      ),
    );
  }

  /// 🚀 Navigate to the Swimmer Performance screen
  void _openSwimmerPerformance() {
    Navigator.of(context).pushNamed('/swimmer-performance');
  }

  /// ✅ Swimmer Dashboard
  void _openSwimmerDashboard() {
    Navigator.of(context).pushNamed('/swimmer-dashboard');
  }

  /// Opens the dedicated Best Finishing Time predictor screen
  void _openPredictModal() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PredictBestFinishingTimeScreen()),
    );
  }
}

//// ----------- Reusable UI pieces -----------

class _HeaderStatsCard extends StatelessWidget {
  final Future<CompetitionStats> Function() loader;
  final String titleText;
  final String Function(CompetitionStats stats)? subtitleBuilder; // optional
  final String? staticSubtitle; // fixed subtitle
  final String? dateValue;      // extra mini tile "Date"
  final List<String>? contextChips;

  const _HeaderStatsCard({
    required this.loader,
    required this.titleText,
    this.staticSubtitle,
    this.dateValue,
    this.contextChips, this.subtitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompetitionStats>(
      future: loader(),
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final hasErr  = snapshot.hasError;

        final subtitle = staticSubtitle ??
            (waiting
                ? "Loading..."
                : hasErr
                    ? "Could not load. Pull to refresh."
                    : (subtitleBuilder != null
                        ? subtitleBuilder!(snapshot.data!)
                        : "Snapshot"));

        // Tiles (counts + always Date)
        final tiles = <Widget>[
          _StatPillAqua(
            label: 'Upcoming',
            value: waiting || hasErr ? '—' : snapshot.data!.upcoming,
            icon: Icons.event_available,
            color: BrandColors.info,
          ),
          _StatPillAqua(
            label: 'Predictions',
            value: waiting || hasErr ? '—' : snapshot.data!.predictions,
            icon: Icons.query_stats,
            color: BrandColors.accent1,
          ),
          _StatPillAqua(
            label: 'Trainings',
            value: waiting || hasErr ? '—' : snapshot.data!.trainings,
            icon: Icons.fitness_center,
            color: BrandColors.good,
          ),
          _StatPillAqua(
            label: 'Date',
            value: dateValue ?? '—',
            icon: Icons.calendar_today,
            color: BrandColors.warn,
            isWide: true,
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BrandColors.border),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BrandColors.snapStart, BrandColors.snapEnd],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BrandColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BrandColors.border),
                    ),
                    child: const Icon(Icons.sports_motorsports,
                        color: BrandColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.headline,
                      ),
                    ),
                  ),
                  Icon(Icons.assessment_outlined,
                      color: Colors.black.withOpacity(.45)),
                ],
              ),

              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(0.75))),
              const SizedBox(height: 12),

              // Pills
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles,
              ),

              if ((contextChips ?? []).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: contextChips!
                      .map((c) => Chip(
                            label: Text(c),
                            backgroundColor: BrandColors.surfaceAlt,
                            side: const BorderSide(color: BrandColors.border),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatPillAqua extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isWide;

  const _StatPillAqua({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: isWide ? 170 : 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(.45)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(.18), color.withOpacity(.08)],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BrandColors.pillText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCardAqua extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color start;
  final Color end;
  final VoidCallback onTap;

  const _FeatureCardAqua({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.start,
    required this.end,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [start, end],
            ),
            border: Border.all(color: end.withOpacity(.45)),
            boxShadow: [
              BoxShadow(
                color: start.withOpacity(0.22),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: end.withOpacity(.55)),
                ),
                child: Icon(icon, color: end),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BrandColors.headline,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.black.withOpacity(.72)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: end, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SimpleInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BrandColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BrandColors.border),
            ),
            child: Icon(icon, color: BrandColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.headline,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: TextStyle(color: Colors.black.withOpacity(.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =====================================
/// Full list of upcoming competitions (scoped to swimmer)
/// =====================================
class _UpcomingCompetitionsList extends StatefulWidget {
  final String? currentUserId;
  const _UpcomingCompetitionsList({this.currentUserId});

  @override
  State<_UpcomingCompetitionsList> createState() => _UpcomingCompetitionsListState();
}

class _UpcomingCompetitionsListState extends State<_UpcomingCompetitionsList> {
  final _store = SwimHistoryStore();

  @override
  void initState() {
    super.initState();
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

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  int _daysUntil(DateTime target) {
    final today = _ymd(DateTime.now());
    final t = _ymd(target);
    return t.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserId == null) {
      return const _SimpleInfoCard(
        icon: Icons.lock_outline,
        title: "Upcoming Competitions",
        body: "Sign in to see your upcoming competitions.",
      );
    }

    final today = _ymd(DateTime.now());

    // ✅ Only THIS swimmer, future (>= today), has competition name
    final list = _store.items
        .where((r) =>
            r.swimmerId == widget.currentUserId &&
            (r.competition?.trim().isNotEmpty ?? false) &&
            !_ymd(r.sessionDate).isBefore(today))
        .toList()
      ..sort((a, b) => _ymd(a.sessionDate).compareTo(_ymd(b.sessionDate)));

    if (list.isEmpty) {
      return const _SimpleInfoCard(
        icon: Icons.calendar_month_outlined,
        title: "Upcoming Competitions",
        body: "No upcoming competitions found for your account.",
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.event_available, color: BrandColors.primary),
              const SizedBox(width: 8),
              const Text(
                "Upcoming Competitions",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BrandColors.headline),
              ),
              const Spacer(),
              _CountBadge(count: list.length),
            ],
          ),
          const SizedBox(height: 10),

          // List
          ...List.generate(list.length, (i) {
            final s = list[i];
            final days = _daysUntil(s.sessionDate);
            final dateStr = DateFormat('EEE, dd MMM yyyy').format(s.sessionDate);
            final event = '${s.distance} • ${s.stroke}';

            return Padding(
              padding: EdgeInsets.only(bottom: i == list.length - 1 ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BrandColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BrandColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.competition ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: BrandColors.headline,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            days >= 0 ? '$days d' : '—',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          avatar: const Icon(Icons.hourglass_bottom_rounded, size: 16),
                          backgroundColor: Colors.teal.withOpacity(.08),
                          side: BorderSide(color: Colors.teal.withOpacity(.25)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Info chips
                    Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.event, size: 16, color: Colors.indigo),
                          label: Text(dateStr),
                          backgroundColor: Colors.indigo.withOpacity(.06),
                        ),
                        Chip(
                          avatar: const Icon(Icons.pool_rounded, size: 16, color: Colors.blueGrey),
                          label: Text(event),
                          backgroundColor: Colors.blueGrey.withOpacity(.06),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.accent1.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BrandColors.accent1.withOpacity(.45)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: BrandColors.pillText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}