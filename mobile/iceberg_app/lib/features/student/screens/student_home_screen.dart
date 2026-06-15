import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/ice_tokens.dart';
import '../../../shared/widgets/ice_kit.dart';

/// Student Dashboard — rank/tier hero, streak, attendance ring, quick stats,
/// performance trend, Campus Pulse stories and assignment preview.
///
/// Refreshes automatically:
///   - every 45 s while the screen is visible (background polling)
///   - whenever the app returns to the foreground from the background
class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) ref.read(studentDashProvider.notifier).backgroundRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(studentDashProvider.notifier).backgroundRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(studentDashProvider);

    return dash.when(
      loading: () => const PageSkeleton(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(studentDashProvider.notifier).reload(),
      ),
      data: (d) => _Dashboard(d: d),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final Map<String, dynamic> d;
  const _Dashboard({required this.d});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ice;
    final s = ref.watch(stringsProvider);
    final user = ref.watch(authProvider.select((a) => a.user));

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? s('Good Morning')
        : hour < 17
            ? s('Good Afternoon')
            : s('Good Evening');

    final rank = (d['rank'] as num?)?.toInt();
    final tier = (d['tier'] as String?) ?? '';
    final streak = (d['streak_days'] as num?)?.toInt() ?? 0;
    final attendance = (d['attendance_percentage'] as num?)?.toDouble();
    final pending = (d['pending_assignments'] as num?)?.toInt() ?? 0;
    final unread = (d['unread_notifications'] as num?)?.toInt() ?? 0;
    final newWords = (d['new_vocab_words'] as num?)?.toInt() ?? 0;
    final trend = (d['performance_trend'] as List?) ?? [];
    final stories = (d['stories'] as List?) ?? [];
    final assignments = (d['assignments_preview'] as List?) ?? [];
    final classes = (d['classes'] as List?) ?? [];

    return IceRefresh(
      onRefresh: () => ref.read(studentDashProvider.notifier).reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 600,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // ── Rank / tier hero ───────────────────────────────────────────
          IceCard(
            hero: true,
            onTap: () => context.go('/student/leaderboard'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar + greeting row (mirrors teacher header layout) ─
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/student/profile'),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                        child: IceUserAvatar(
                          radius: 22,
                          photoUrl: user?.profilePicUrl,
                          emoji: user?.avatar.isNotEmpty == true
                              ? user!.avatar
                              : null,
                          fallbackText: user?.firstName.isNotEmpty == true
                              ? user!.firstName[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: t.accent),
                              const SizedBox(width: 4),
                              MicroLabel(
                                tier.isEmpty ? s('My standing') : tier,
                                color: t.accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$greeting, ${user?.firstName.isNotEmpty == true ? user!.firstName : s('Student')}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        rank != null ? '#$rank' : '—',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s('Current Momentum'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                          Text(
                            streak > 0
                                ? '$streak-${s('Day Streak')}'
                                : s('Start your streak today'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).moveY(begin: 14, end: 0),
          const SizedBox(height: 20),

          // ── Upcoming lessons ───────────────────────────────────────────
          if (classes.isNotEmpty) ...[
            SectionHeader(s('Upcoming Lessons')),
            for (var i = 0; i < classes.length && i < 4; i++) ...[
              _LessonCard(
                group: classes[i] as Map<String, dynamic>,
                highlight: i == 0,
              ).animate().fadeIn(
                    delay: Duration(milliseconds: 60 + i * 50),
                    duration: 300.ms,
                  ),
              if (i < classes.length - 1 && i < 3)
                const SizedBox(height: 10),
            ],
            const SizedBox(height: 22),
          ],

          // ── Attendance ring ────────────────────────────────────────────
          IceCard(
            onTap: () => context.go('/student/attendance'),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: MicroLabel(s('Attendance')),
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                 child: ProgressRing(
                  value: (attendance ?? 0) / 100,
                  size: 150,
                  strokeWidth: 12,
                  center: Text(
                    attendance != null
                        ? '${attendance.toStringAsFixed(attendance % 1 == 0 ? 0 : 1)}%'
                        : '—',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: t.textHi,
                    ),
                  ),
                 )),
                const SizedBox(height: 14),
                Text(
                  s('Present'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.accentInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s('Target: 90%'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: t.textMid,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 60.ms, duration: 350.ms),
          const SizedBox(height: 14),

          // ── Quick stats ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.assignment_late_outlined,
                  iconColor: t.coral,
                  value: '$pending',
                  label: s('Pending Tasks'),
                  onTap: () => context.go('/student/assignments'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  icon: Icons.mark_email_unread_outlined,
                  iconColor: t.sky,
                  value: '$unread',
                  label: s('Unread Notifs'),
                  onTap: () => context.go('/student/notifications'),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
          const SizedBox(height: 14),

          IceCard(
            onTap: () => context.go('/student/vocabulary'),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    size: 19,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$newWords ${s('New')}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: t.textHi,
                        ),
                      ),
                      Text(
                        s('Vocab Words Ready'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: t.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: t.onAccent,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 140.ms, duration: 350.ms),
          const SizedBox(height: 14),

          // ── Performance trend ──────────────────────────────────────────
          IceCard(
            onTap: () => context.go('/student/progress'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s('Performance Trend'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: t.textHi,
                        ),
                      ),
                    ),
                    StatusBadge(s('Attendance'), tone: BadgeTone.neutral),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  s('8-Week History'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: t.textMid,
                  ),
                ),
                const SizedBox(height: 18),
                RepaintBoundary(
                  child: ColoredBox(
                    color: t.card,
                    child: SizedBox(height: 150, child: _TrendChart(trend: trend)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 180.ms, duration: 350.ms),
          const SizedBox(height: 22),

          // ── Campus Pulse ───────────────────────────────────────────────
          if (stories.isNotEmpty) ...[
            SectionHeader(s('Campus Pulse')),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                cacheExtent: 600,
                itemCount: stories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _PulseCard(story: stories[i] as Map<String, dynamic>),
              ),
            ),
            const SizedBox(height: 22),
          ],

          // ── Assignments preview ────────────────────────────────────────
          SectionHeader(
            s('Assignments'),
            actionLabel: s('View All'),
            onAction: () => context.go('/student/assignments'),
          ),
          if (assignments.isEmpty)
            IceCard(
              child: EmptyState(
                icon: Icons.task_alt_rounded,
                title: s('All caught up!'),
                message: s('No pending assignments right now.'),
              ),
            )
          else
            ...assignments.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentPreview(a: a as Map<String, dynamic>),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Trend chart ─────────────────────────────────────────────────────────────
class _TrendChart extends StatelessWidget {
  final List trend;
  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final t = context.ice;
    final spots = <FlSpot>[];
    for (var i = 0; i < trend.length; i++) {
      final pct = (trend[i]['attendance_pct'] as num?)?.toDouble();
      if (pct != null) spots.add(FlSpot(i.toDouble(), pct));
    }
    if (spots.length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, size: 30, color: t.textLow),
            const SizedBox(height: 8),
            Text(
              'No performance data yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.textMid,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Progress will appear here after results are added.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: t.textLow),
            ),
          ],
        ),
      );
    }
    return LineChart(
      LineChartData(
        backgroundColor: t.card,
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: t.stroke, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    trend[i]['label'] ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: t.textLow,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.32,
            barWidth: 3,
            color: t.accent,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3.5,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: t.accent,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  t.accent.withValues(alpha: 0.28),
                  t.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

// ─── Campus Pulse card ───────────────────────────────────────────────────────
class _PulseCard extends StatelessWidget {
  final Map<String, dynamic> story;
  const _PulseCard({required this.story});

  IconData get _icon => switch (story['story_type']) {
    'event' => Icons.event_rounded,
    'challenge' => Icons.emoji_events_rounded,
    'vocab' => Icons.translate_rounded,
    'tip' => Icons.lightbulb_outline_rounded,
    'update' => Icons.campaign_rounded,
    _ => Icons.campaign_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.ice;
    final created = DateTime.tryParse(story['created_at'] ?? '');
    final when = created == null ? '' : _relative(created);

    return SizedBox(
      width: 240,
      child: IceCard(
        padding: const EdgeInsets.all(16),
        onTap: () => _showDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: t.skySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, size: 16, color: t.sky),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_typeLabel(story['story_type'])}\n$when',
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: t.textLow,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              story['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: t.textHi,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Read More',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14, color: t.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(dynamic type) => switch (type) {
    'event' => 'Event',
    'challenge' => 'Competition',
    'vocab' => 'Vocabulary',
    'tip' => 'Study Tip',
    'update' => 'Teacher Update',
    _ => 'Announcement',
  };

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  void _showDetail(BuildContext context) {
    final t = context.ice;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: t.stroke,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            StatusBadge(_typeLabel(story['story_type']), tone: BadgeTone.sky),
            const SizedBox(height: 12),
            Text(
              story['title'] ?? '',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: t.textHi,
              ),
            ),
            const SizedBox(height: 10),
            if ((story['image_url'] as String?)?.isNotEmpty == true) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  story['image_url'],
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  (story['content'] as String?)?.isNotEmpty == true
                      ? story['content']
                      : 'No further details.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: t.textMid,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if ((story['author_name'] as String?)?.isNotEmpty == true)
              Text(
                '— ${story['author_name']}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.textLow,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Assignment preview row ──────────────────────────────────────────────────
class _AssignmentPreview extends StatelessWidget {
  final Map<String, dynamic> a;
  const _AssignmentPreview({required this.a});

  @override
  Widget build(BuildContext context) {
    final t = context.ice;
    final due = DateTime.tryParse(a['due_date'] ?? '');
    final overdue = a['is_overdue'] == true;
    final dueLabel = due == null
        ? ''
        : overdue
        ? 'Overdue'
        : _dueIn(due);

    return IceCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.go('/student/assignments/${a['id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(dueLabel, color: overdue ? t.coral : t.amber),
          const SizedBox(height: 6),
          Text(
            a['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: t.textHi,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: t.textLow),
              const SizedBox(width: 5),
              Text(
                due != null ? DateFormat('MMM d').format(due) : '',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.textMid,
                ),
              ),
              const Spacer(),
              StatusBadge(
                overdue ? 'Overdue' : 'Submit',
                tone: overdue ? BadgeTone.coral : BadgeTone.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dueIn(DateTime due) {
    final today = DateTime.now();
    final diff = due
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff <= 0) return 'Due Today';
    if (diff == 1) return 'Due Tomorrow';
    return 'In $diff Days';
  }
}

// ── Lesson card (Upcoming Lessons on the dashboard) ──────────────────────────
class _LessonCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool highlight;
  const _LessonCard({required this.group, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final t = context.ice;
    final name = group['name']?.toString() ?? 'Class';
    final course = group['course_name']?.toString() ?? '';
    final room = group['room']?.toString() ?? '';
    final schedule = group['schedule']?.toString() ?? '';
    final meta = [
      if (course.isNotEmpty) course,
      if (room.isNotEmpty) 'Room $room',
    ].join(' · ');

    return IceCard(
      padding: const EdgeInsets.all(14),
      color: highlight ? t.accentSoft : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: highlight ? t.accent : t.inset,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 22,
              color: highlight ? t.onAccent : t.accentInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: t.textHi,
                        ),
                      ),
                    ),
                    if (highlight)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'NEXT',
                          style: TextStyle(
                            color: t.onAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: t.textMid),
                  ),
                ],
                if (schedule.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 13, color: t.textLow),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          schedule,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: t.textLow),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
