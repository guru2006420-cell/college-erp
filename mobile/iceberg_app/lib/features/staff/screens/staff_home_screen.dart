import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/auth/auth_state.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
const _bg     = Color(0xFF081A20);
const _surf   = Color(0xFF0F2530);
const _card   = Color(0xFF132D38);
const _stroke = Color(0xFF1E3D4A);
const _lime   = Color(0xFFDFFF2F);
const _amber  = Color(0xFFFFB020);
const _green  = Color(0xFF4CAF50);
const _white  = Colors.white;
const _muted  = Color(0xFF7A9BAA);

class StaffHomeScreen extends ConsumerWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = ref.watch(authProvider).user;
    final stats  = ref.watch(staffStatsProvider);
    final groups = ref.watch(staffGroupsProvider);

    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Teacher';
    final initials = (() {
      final full = '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
      if (full.isEmpty) return 'T';
      return full.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    })();

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(staffStatsProvider.future),
            ref.refresh(staffGroupsProvider.future),
          ]);
        },
        color: _lime,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── User card ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surf,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _stroke),
                  ),
                  child: Row(children: [
                    // Avatar with lime ring
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _lime, width: 2.5),
                      ),
                      child: CircleAvatar(
                        backgroundColor: _card,
                        child: Text(initials,
                            style: const TextStyle(
                                color: _lime,
                                fontWeight: FontWeight.w900,
                                fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('SUPERVISOR',
                            style: TextStyle(
                                color: _muted, fontSize: 11, fontWeight: FontWeight.w600,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            children: [
                              TextSpan(text: '$greeting, ', style: const TextStyle(color: _white)),
                              TextSpan(text: firstName, style: const TextStyle(color: _lime)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            // ── Stats 2×2 grid ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: stats.when(
                  loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: _lime))),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (d) => Column(children: [
                    Row(children: [
                      Expanded(child: _StatCard(
                        badge: 'Total', badgeColor: _muted,
                        value: '${d['total_students'] ?? 0}',
                        valueColor: _white,
                        label: 'Total Students',
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        badge: 'Today', badgeColor: _lime,
                        value: '${d['sessions_today'] ?? 0}',
                        valueColor: _lime,
                        label: 'Attendance Taken',
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _StatCard(
                        badge: 'Action', badgeColor: _amber,
                        value: '${d['pending_results'] ?? 0} groups',
                        valueColor: _white,
                        label: 'Pending Results',
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        badge: 'New', badgeColor: _green,
                        value: '${d['pending_leaves'] ?? 0}',
                        valueColor: _white,
                        label: 'Leave Requests',
                      )),
                    ]),
                  ]),
                ),
              ),
            ),

            // ── Quick Actions ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Quick Actions',
                      style: TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _QuickAction(
                      icon: Icons.how_to_reg_rounded,
                      label: 'Take\nAttendance',
                      onTap: () => context.push('/staff/attendance'),
                    ),
                    _QuickAction(
                      icon: Icons.bar_chart_rounded,
                      label: 'Add\nResult',
                      onTap: () => context.push('/staff/results'),
                    ),
                    _QuickAction(
                      icon: Icons.assignment_rounded,
                      label: 'New\nAssignment',
                      onTap: () => context.push('/staff/assignments'),
                    ),
                    _QuickAction(
                      icon: Icons.beach_access_rounded,
                      label: 'Request\nLeave',
                      onTap: () => context.push('/staff/leave'),
                    ),
                  ]),
                ]),
              ),
            ),

            // ── Today's Schedule ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(children: [
                  const Expanded(
                    child: Text("Today's Schedule",
                        style: TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/staff/classes'),
                    child: const Text('View Full Calendar',
                        style: TextStyle(color: _lime, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),

            groups.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: _lime)))),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (list) {
                if (list.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No classes scheduled.', style: TextStyle(color: _muted))),
                    ),
                  );
                }
                final times = ['08:00 AM', '10:00 AM', '12:00 PM', '02:00 PM', '04:00 PM'];
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final g = list[i];
                      final isNow = i == 0;
                      final time = times[i % times.length];
                      return _ScheduleItem(
                        time: time,
                        name: g['name']?.toString() ?? 'Group',
                        subtitle: [
                          g['course_name']?.toString(),
                          g['room'] != null ? 'Room ${g['room']}' : null,
                        ].where((e) => e != null && e.isNotEmpty).join(' · '),
                        isNow: isNow,
                        onAttendance: () => context.push('/staff/attendance'),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String badge, value, label;
  final Color badgeColor, valueColor;
  const _StatCard({
    required this.badge, required this.badgeColor,
    required this.value, required this.valueColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.topRight,
          child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Quick action button ───────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: _card, shape: BoxShape.circle,
            border: Border.all(color: _stroke),
          ),
          child: Icon(icon, color: _white, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Schedule row ──────────────────────────────────────────────────────────────
class _ScheduleItem extends StatelessWidget {
  final String time, name, subtitle;
  final bool isNow;
  final VoidCallback onAttendance;
  const _ScheduleItem({
    required this.time, required this.name, required this.subtitle,
    required this.isNow, required this.onAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: isNow ? _lime : Colors.transparent, width: 3),
          top: BorderSide(color: _stroke),
          right: BorderSide(color: _stroke),
          bottom: BorderSide(color: _stroke),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        SizedBox(
          width: 72,
          child: Text(time, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(name, style: const TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (isNow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _lime)),
                  child: const Text('NOW', style: TextStyle(color: _lime, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
            ]),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ]),
        ),
        if (isNow) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAttendance,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _surf, borderRadius: BorderRadius.circular(20), border: Border.all(color: _stroke)),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.how_to_reg_rounded, color: _white, size: 13),
                SizedBox(width: 4),
                Text('Attendance', style: TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
