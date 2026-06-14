import 'dart:async';

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

class StaffHomeScreen extends ConsumerStatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  // Cache last good data so background refreshes never flash the skeleton.
  Map<String, dynamic>? _cachedStats;
  List<dynamic>? _cachedGroups;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) {
        ref.invalidate(staffStatsProvider);
        ref.invalidate(staffGroupsProvider);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(staffStatsProvider);
      ref.invalidate(staffGroupsProvider);
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
    final stats = ref.watch(staffStatsProvider);
    final groups = ref.watch(staffGroupsProvider);

    // Keep a local copy of the last successful fetch so we can show stale
    // data during background refreshes instead of flashing the skeleton.
    ref.listen(staffStatsProvider, (_, next) {
      if (next.valueOrNull != null) _cachedStats = next.valueOrNull;
    });
    ref.listen(staffGroupsProvider, (_, next) {
      if (next.valueOrNull != null) _cachedGroups = next.valueOrNull;
    });

    // Show skeleton only on the very first load (no cached data yet).
    final initialLoad = _cachedStats == null && _cachedGroups == null;
    if (initialLoad && (stats.isLoading || groups.isLoading)) {
      return const PageSkeleton();
    }
    if (stats.hasError && _cachedStats == null) {
      return ErrorState(
        error: stats.error,
        onRetry: () => ref.invalidate(staffStatsProvider),
      );
    }

    return _Dashboard(
      stats: _cachedStats ?? stats.valueOrNull ?? {},
      groups: _cachedGroups ?? groups.valueOrNull ?? [],
      groupsAsync: groups,
      ref: ref,
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final Map<String, dynamic> stats;
  final List<dynamic> groups;
  final AsyncValue<List<dynamic>> groupsAsync;
  final WidgetRef ref;

  const _Dashboard({
    required this.stats,
    required this.groups,
    required this.groupsAsync,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final t = context.ice;
    final s = innerRef.watch(stringsProvider);
    final user = innerRef.watch(authProvider).user;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? s('Good Morning')
        : hour < 17
            ? s('Good Afternoon')
            : s('Good Evening');

    final firstName = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : s('Teacher');
    final initials = (() {
      final full =
          '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
      if (full.isEmpty) return 'T';
      return full
          .split(' ')
          .where((p) => p.isNotEmpty)
          .take(2)
          .map((p) => p[0])
          .join()
          .toUpperCase();
    })();

    final totalStudents = (stats['total_students'] as num?)?.toInt() ?? 0;
    final sessionsToday = (stats['sessions_today'] as num?)?.toInt() ?? 0;
    final pendingResults = (stats['pending_results'] as num?)?.toInt() ?? 0;
    final pendingLeaves = (stats['pending_leaves'] as num?)?.toInt() ?? 0;
    final stories = innerRef.watch(storiesProvider).valueOrNull ?? [];

    return IceRefresh(
      onRefresh: () async {
        await Future.wait([
          innerRef.refresh(staffStatsProvider.future),
          innerRef.refresh(staffGroupsProvider.future),
          innerRef.refresh(storiesProvider.future),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // ── Hero card ────────────────────────────────────────────────
          IceCard(
            hero: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/staff/profile'),
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
                          radius: 24,
                          photoUrl: user?.profilePicUrl,
                          emoji: user?.avatar.isNotEmpty == true
                              ? user!.avatar
                              : null,
                          fallbackText: initials,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MicroLabel(
                            s('SUPERVISOR'),
                            color: t.accent,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$greeting, $firstName',
                            style: const TextStyle(
                              fontSize: 18,
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
                        s('Staff'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          value: '$totalStudents',
                          label: s('Students'),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.12)),
                      Expanded(
                        child: _HeroStat(
                          value: '$sessionsToday',
                          label: s('Sessions Today'),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.12)),
                      Expanded(
                        child: _HeroStat(
                          value: '$pendingLeaves',
                          label: s('Leave Req.'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).moveY(begin: 14, end: 0),
          const SizedBox(height: 14),

          // ── Today's Schedule (visible on open) ────────────────────────
          SectionHeader(
            s("Today's Schedule"),
            actionLabel: s('View All'),
            onAction: () => context.push('/staff/classes'),
          ),
          groupsAsync.when(
            loading: () => const SkeletonBox(height: 80),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => innerRef.invalidate(staffGroupsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return IceCard(
                  child: EmptyState(
                    icon: Icons.calendar_today_rounded,
                    title: s('No classes scheduled'),
                    message: s('Your groups will appear here once assigned.'),
                  ),
                );
              }
              final times = [
                '08:00 AM',
                '10:00 AM',
                '12:00 PM',
                '02:00 PM',
                '04:00 PM',
              ];
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    _ScheduleCard(
                      group: list[i] as Map<String, dynamic>,
                      time: times[i % times.length],
                      isNow: i == 0,
                      onAttendance: () => context.push('/staff/attendance'),
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: 60 + i * 50),
                          duration: 300.ms,
                        ),
                    if (i < list.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 22),

          // ── Stat row ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.pending_actions_rounded,
                  iconColor: t.amber,
                  value: '$pendingResults',
                  label: s('Pending Results'),
                  onTap: () => context.push('/staff/results'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  icon: Icons.beach_access_rounded,
                  iconColor: t.sky,
                  value: '$pendingLeaves',
                  label: s('Leave Requests'),
                  onTap: () => context.push('/staff/leave'),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
          const SizedBox(height: 14),

          // ── Quick Actions ─────────────────────────────────────────────
          SectionHeader(s('Quick Actions')),
          IceCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _QuickAction(
                    icon: Icons.how_to_reg_rounded,
                    label: s('Attendance'),
                    color: t.accentInk,
                    onTap: () => context.push('/staff/attendance'),
                  ),
                  _QuickAction(
                    icon: Icons.bar_chart_rounded,
                    label: s('Results'),
                    color: t.amber,
                    onTap: () => context.push('/staff/results'),
                  ),
                  _QuickAction(
                    icon: Icons.assignment_rounded,
                    label: s('Assignment'),
                    color: t.sky,
                    onTap: () => context.push('/staff/assignments'),
                  ),
                  _QuickAction(
                    icon: Icons.beach_access_rounded,
                    label: s('Leave'),
                    color: t.mint,
                    onTap: () => context.push('/staff/leave'),
                  ),
                  _QuickAction(
                    icon: Icons.chat_rounded,
                    label: s('Messages'),
                    color: t.accent,
                    onTap: () => context.push('/staff/messages'),
                  ),
                  _QuickAction(
                    icon: Icons.class_outlined,
                    label: s('My Classes'),
                    color: t.coral,
                    onTap: () => context.push('/staff/classes'),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 140.ms, duration: 350.ms),
          const SizedBox(height: 22),

          // ── Campus Pulse ──────────────────────────────────────────────
          if (stories.isNotEmpty) ...[
            SectionHeader(s('Campus Pulse')),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: stories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _PulseCard(story: stories[i] as Map<String, dynamic>),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

// ── Hero stat item (inside the gradient card) ─────────────────────────────────
class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      );
}

// ── Quick action button ───────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.ice.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Schedule card ─────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final String time;
  final bool isNow;
  final VoidCallback onAttendance;
  const _ScheduleCard({
    required this.group,
    required this.time,
    required this.isNow,
    required this.onAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.ice;
    final name = group['name']?.toString() ?? 'Group';
    final subtitle = [
      group['course_name']?.toString(),
      group['room'] != null ? 'Room ${group['room']}' : null,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');

    return IceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: isNow ? t.accentSoft : null,
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isNow ? t.accentInk : t.textMid,
                  ),
                ),
                if (isNow) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NOW',
                      style: TextStyle(
                        color: t.onAccent,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Group info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: t.textHi,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: t.textMid),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Attendance CTA for current class
          if (isNow)
            GestureDetector(
              onTap: onAttendance,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.how_to_reg_rounded,
                        color: t.onAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Attend',
                      style: TextStyle(
                        color: t.onAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Icon(Icons.chevron_right_rounded, color: t.textLow, size: 20),
        ],
      ),
    );
  }
}

// ── Campus Pulse card ─────────────────────────────────────────────────────────
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
                  story['image_url'] as String,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  (story['content'] as String?)?.isNotEmpty == true
                      ? story['content'] as String
                      : 'No further details.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: t.textMid,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
