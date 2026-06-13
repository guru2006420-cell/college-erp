import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Shared building blocks (match the existing staff portal visual language)
// ════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  // Secondary screens (reached from the More menu / header bell) show a back
  // control; bottom-nav tab screens do not.
  final bool showBack;
  const _Header({required this.title, required this.subtitle, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final canPop = showBack;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 18, 20, 26),
      decoration: const BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.maybePop();
                } else {
                  context.go('/staff/home');
                }
              },
              child: const Row(children: [
                Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                SizedBox(width: 6),
                Text('Back',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(color: Colors.white.withAlpha(165), fontSize: 13)),
      ]),
    );
  }
}

Widget _empty(String msg, IconData icon) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: IceColors.muted),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                  color: IceColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );

Widget _loading() => const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(child: CircularProgressIndicator(color: IceColors.navyDeep)),
    );

Widget _error(Object e) => Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Text('Could not load.\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: IceColors.danger)),
      ),
    );

InputDecoration _dec(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: IceColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IceColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IceColors.border),
      ),
    );

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Resolve a friendly student name from a StudentSummary map.
String _studentName(Map s) {
  final f = (s['first_name'] ?? '').toString().trim();
  final l = (s['last_name'] ?? '').toString().trim();
  final full = '$f $l'.trim();
  return full.isEmpty ? (s['email']?.toString() ?? 'Student') : full;
}

/// A reusable group picker fed by the teacher's own groups.
class _GroupDropdown extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _GroupDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(staffGroupsProvider);
    return groups.when(
      loading: () => const LinearProgressIndicator(color: IceColors.navyDeep),
      error: (e, _) => Text('Could not load groups: $e',
          style: const TextStyle(color: IceColors.danger)),
      data: (list) {
        if (list.isEmpty) {
          return const Text('No groups are assigned to you yet.',
              style: TextStyle(color: IceColors.muted));
        }
        return DropdownButtonFormField<int>(
          value: value,
          isExpanded: true,
          decoration: _dec('Group'),
          items: [
            for (final g in list)
              DropdownMenuItem(
                value: g['id'] as int,
                child: Text(
                  '${g['name']}${g['course_name'] != null ? ' · ${g['course_name']}' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  1 · Classes  — list groups, tap to see the enrolled roster
// ════════════════════════════════════════════════════════════════════════════

class StaffClassesScreen extends ConsumerWidget {
  const StaffClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(staffGroupsProvider);
    return Scaffold(
      backgroundColor: IceColors.bg,
      body: RefreshIndicator(
        color: IceColors.navyDeep,
        onRefresh: () => ref.refresh(staffGroupsProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: _Header(title: 'My Classes', subtitle: 'Groups you teach'),
            ),
            groups.when(
              loading: () => SliverToBoxAdapter(child: _loading()),
              error: (e, _) => SliverToBoxAdapter(child: _error(e)),
              data: (list) {
                if (list.isEmpty) {
                  return _empty('No groups assigned', Icons.class_outlined);
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _ClassCard(group: list[i] as Map<String, dynamic>),
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

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> group;
  const _ClassCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RosterSheet(
          groupId: group['id'] as int,
          groupName: (group['name'] ?? 'Group').toString(),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: IceColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: IceColors.navyDeep.withAlpha(20),
                borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.group_rounded, color: IceColors.navyDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group['name']?.toString() ?? 'Group',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                [
                  group['course_name'],
                  group['schedule'],
                  group['room'] != null ? 'Room ${group['room']}' : null,
                ].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
                style: const TextStyle(fontSize: 12.5, color: IceColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: IceColors.muted),
        ]),
      ),
    );
  }
}

class _RosterSheet extends ConsumerWidget {
  final int groupId;
  final String groupName;
  const _RosterSheet({required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: IceColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: IceColors.border,
                borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(children: [
              const Icon(Icons.people_alt_rounded, color: IceColors.navyDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$groupName · Students',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Expanded(
            child: detail.when(
              loading: () => _loading(),
              error: (e, _) => _error(e),
              data: (d) {
                final students = (d['enrolled_students'] as List?) ?? [];
                if (students.isEmpty) {
                  return const Center(
                    child: Text('No students enrolled yet.',
                        style: TextStyle(color: IceColors.muted)),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = students[i] as Map<String, dynamic>;
                    return Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: IceColors.border)),
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: IceColors.navyDeep.withAlpha(20),
                          child: Text(
                            _studentName(s).characters.first.toUpperCase(),
                            style: const TextStyle(
                                color: IceColors.navyDeep,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_studentName(s),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        if ((s['status']?.toString() ?? '') != 'active')
                          Text(s['status']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 11, color: IceColors.warning)),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  2 · Attendance  — pick group + date, mark each student
// ════════════════════════════════════════════════════════════════════════════

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});
  @override
  ConsumerState<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen> {
  static const _bg     = Color(0xFF081A20);
  static const _surf   = Color(0xFF0F2530);
  static const _card   = Color(0xFF132D38);
  static const _stroke = Color(0xFF1E3D4A);
  static const _lime   = Color(0xFFDFFF2F);
  static const _white  = Colors.white;
  static const _muted  = Color(0xFF7A9BAA);

  int? _groupId;
  DateTime _date = DateTime.now();
  final Map<int, String> _status = {}; // studentId -> 'P'/'L'/'A'
  bool _saving = false;

  Future<void> _save(List students) async {
    if (_groupId == null) return;
    setState(() => _saving = true);
    final records = [
      for (final s in students)
        {
          'student_id': s['id'],
          'status': () {
            final st = _status[s['id'] as int] ?? 'P';
            return st == 'P' ? 1 : st == 'L' ? 2 : 0;
          }(),
        },
    ];
    try {
      await ApiClient.instance.dio.post('/attendance/', data: {
        'group_id': _groupId,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'records': records,
      });
      if (mounted) _toast(context, 'Attendance saved.');
    } on DioException catch (e) {
      if (mounted) {
        _toast(context, e.response?.data?['detail']?.toString() ?? 'Could not save.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int get _presentCount => _status.values.where((v) => v == 'P').length;
  int get _lateCount    => _status.values.where((v) => v == 'L').length;
  int get _absentCount  => _status.values.where((v) => v == 'A').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Take Attendance',
                  style: TextStyle(color: _white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Record student presence for today\'s session.',
                  style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 16),
              // Group + Date row
              Row(children: [
                Expanded(child: _DarkGroupDropdown(value: _groupId, onChanged: (v) => setState(() { _groupId = v; _status.clear(); }))),
                const SizedBox(width: 10),
                Expanded(child: _DarkDatePicker(date: _date, onPick: (d) => setState(() => _date = d))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          // Student list
          Expanded(child: _groupId == null
            ? Center(child: Text('Select a group to begin.', style: TextStyle(color: _muted)))
            : Consumer(builder: (context, ref, _) {
                final detail = ref.watch(groupDetailProvider(_groupId!));
                return detail.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
                  error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
                  data: (d) {
                    final students = (d['enrolled_students'] as List?) ?? [];
                    if (students.isEmpty) return Center(child: Text('No students enrolled.', style: TextStyle(color: _muted)));
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = students[i] as Map<String, dynamic>;
                        final id = s['id'] as int;
                        final initials = _studentName(s).characters.first.toUpperCase();
                        return Container(
                          decoration: BoxDecoration(
                            color: _card, borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _stroke),
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Row(children: [
                            CircleAvatar(radius: 18, backgroundColor: _surf,
                              child: Text(initials, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_studentName(s), style: const TextStyle(color: _white, fontWeight: FontWeight.w600, fontSize: 14)),
                              if (s['student_id'] != null)
                                Text('${s['student_id']}', style: const TextStyle(color: _muted, fontSize: 11)),
                            ])),
                            _DarkStatusToggle(
                              value: _status[id] ?? 'P',
                              onChanged: (v) => setState(() => _status[id] = v),
                            ),
                          ]),
                        );
                      },
                    );
                  },
                );
              }),
          ),
          // Bottom summary + submit
          if (_groupId != null)
            Consumer(builder: (context, ref, _) {
              final detail = ref.watch(groupDetailProvider(_groupId!));
              final students = detail.maybeWhen(data: (d) => (d['enrolled_students'] as List?) ?? [], orElse: () => const []);
              if (students.isEmpty) return const SizedBox.shrink();
              return Container(
                color: _surf,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _SummaryChip('Present', _presentCount, Colors.green),
                    _SummaryChip('Late', _lateCount, const Color(0xFFFFB020)),
                    _SummaryChip('Absent', _absentCount, Colors.red),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lime,
                        foregroundColor: const Color(0xFF081A20),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : () => _save(students),
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF081A20)))
                          : const Icon(Icons.check_rounded),
                      label: const Text('Submit Attendance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

class _DarkGroupDropdown extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _DarkGroupDropdown({required this.value, required this.onChanged});

  static const _card   = Color(0xFF132D38);
  static const _stroke = Color(0xFF1E3D4A);
  static const _lime   = Color(0xFFDFFF2F);
  static const _muted  = Color(0xFF7A9BAA);
  static const _white  = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(staffGroupsProvider);
    return groups.when(
      loading: () => const LinearProgressIndicator(color: _lime),
      error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
      data: (list) {
        if (list.isEmpty) return const Text('No groups', style: TextStyle(color: _muted));
        return DropdownButtonFormField<int>(
          value: value,
          isExpanded: true,
          dropdownColor: _card,
          style: const TextStyle(color: _white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Group',
            labelStyle: const TextStyle(color: _muted),
            filled: true,
            fillColor: _card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _stroke)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _stroke)),
          ),
          items: [for (final g in list) DropdownMenuItem(value: g['id'] as int, child: Text('${g['name']}', overflow: TextOverflow.ellipsis))],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _DarkDatePicker extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DarkDatePicker({required this.date, required this.onPick});

  static const _card   = Color(0xFF132D38);
  static const _stroke = Color(0xFF1E3D4A);
  static const _muted  = Color(0xFF7A9BAA);
  static const _white  = Colors.white;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: now.subtract(const Duration(days: 60)),
          lastDate: now.add(const Duration(days: 30)),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _stroke),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, color: _muted, size: 16),
          const SizedBox(width: 8),
          Text(DateFormat('MMM d, yyyy').format(date), style: const TextStyle(color: _white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _DarkStatusToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DarkStatusToggle({required this.value, required this.onChanged});

  static const _lime   = Color(0xFFDFFF2F);
  static const _stroke = Color(0xFF1E3D4A);
  static const _bg     = Color(0xFF081A20);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final opt in ['P', 'L', 'A'])
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onChanged(opt),
            child: Container(
              width: 34, height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value == opt ? _lime : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: value == opt ? _lime : _stroke, width: 1.5),
              ),
              child: Text(opt, style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12,
                color: value == opt ? _bg : _stroke,
              )),
            ),
          ),
        ),
    ]);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$count', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Color(0xFF7A9BAA), fontSize: 11)),
    ]);
  }
}

/// Update-attendance entry point reuses the same screen.
class StaffUpdateAttendanceScreen extends StatelessWidget {
  const StaffUpdateAttendanceScreen({super.key});
  @override
  Widget build(BuildContext context) => const StaffAttendanceScreen();
}

// ════════════════════════════════════════════════════════════════════════════
//  3 · Results  — pick group, enter test/exam/comment per student
// ════════════════════════════════════════════════════════════════════════════

class StaffResultsScreen extends ConsumerStatefulWidget {
  const StaffResultsScreen({super.key});
  @override
  ConsumerState<StaffResultsScreen> createState() => _StaffResultsScreenState();
}

class _StaffResultsScreenState extends ConsumerState<StaffResultsScreen> {
  int? _groupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IceColors.bg,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: _Header(
                title: 'Results',
                subtitle: 'Record test & exam scores',
                showBack: true),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _GroupDropdown(
                value: _groupId,
                onChanged: (v) => setState(() => _groupId = v),
              ),
            ),
          ),
          if (_groupId == null)
            _empty('Pick a group to begin', Icons.grade_outlined)
          else
            _roster(),
        ],
      ),
    );
  }

  Widget _roster() {
    final detail = ref.watch(groupDetailProvider(_groupId!));
    final results = ref.watch(groupResultsProvider(_groupId!));
    return detail.when(
      loading: () => SliverToBoxAdapter(child: _loading()),
      error: (e, _) => SliverToBoxAdapter(child: _error(e)),
      data: (d) {
        final students = (d['enrolled_students'] as List?) ?? [];
        if (students.isEmpty) {
          return _empty('No students enrolled', Icons.person_off_outlined);
        }
        final byStudent = <int, Map<String, dynamic>>{};
        results.maybeWhen(
          data: (list) {
            for (final r in list) {
              byStudent[(r as Map)['student'] as int] =
                  r as Map<String, dynamic>;
            }
          },
          orElse: () {},
        );
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList.separated(
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = students[i] as Map<String, dynamic>;
              final existing = byStudent[s['id'] as int];
              return _ResultRow(
                name: _studentName(s),
                existing: existing,
                onTap: () => _editResult(s, existing),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _editResult(
      Map<String, dynamic> student, Map<String, dynamic>? existing) async {
    final testC =
        TextEditingController(text: existing?['test']?.toString() ?? '');
    final examC =
        TextEditingController(text: existing?['exam']?.toString() ?? '');
    final commentC =
        TextEditingController(text: existing?['comment']?.toString() ?? '');
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(_studentName(student),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: testC,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Test'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: examC,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Exam'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: commentC,
              maxLines: 2,
              decoration: _dec('Comment', hint: 'Optional'),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: IceColors.navyDeep),
              onPressed: saving
                  ? null
                  : () async {
                      setLocal(() => saving = true);
                      try {
                        await ApiClient.instance.dio.post('/results/', data: {
                          'student_id': student['id'],
                          'group_id': _groupId,
                          'test': int.tryParse(testC.text.trim()) ?? 0,
                          'exam': int.tryParse(examC.text.trim()) ?? 0,
                          'comment': commentC.text.trim(),
                        });
                        ref.invalidate(groupResultsProvider(_groupId!));
                        if (dctx.mounted) Navigator.pop(dctx);
                        if (mounted) _toast(context, 'Result saved.');
                      } on DioException catch (e) {
                        setLocal(() => saving = false);
                        if (dctx.mounted) {
                          _toast(
                              dctx,
                              e.response?.data?['detail']?.toString() ??
                                  'Could not save.');
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String name;
  final Map<String, dynamic>? existing;
  final VoidCallback onTap;
  const _ResultRow(
      {required this.name, required this.existing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final has = existing != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: IceColors.border)),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (has) ...[
            _scorePill('T', existing!['test']),
            const SizedBox(width: 6),
            _scorePill('E', existing!['exam']),
          ] else
            const Text('Tap to add',
                style: TextStyle(fontSize: 12, color: IceColors.muted)),
          const SizedBox(width: 6),
          const Icon(Icons.edit_rounded, size: 18, color: IceColors.navyDeep),
        ]),
      ),
    );
  }

  Widget _scorePill(String k, dynamic v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: IceColors.navyDeep.withAlpha(18),
            borderRadius: BorderRadius.circular(8)),
        child: Text('$k ${v ?? 0}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: IceColors.navyDeep)),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  4 · Assignments  — list own assignments, create new
// ════════════════════════════════════════════════════════════════════════════

class StaffAssignmentsScreen extends ConsumerStatefulWidget {
  const StaffAssignmentsScreen({super.key});
  @override
  ConsumerState<StaffAssignmentsScreen> createState() => _StaffAssignmentsScreenState();
}

class _StaffAssignmentsScreenState extends ConsumerState<StaffAssignmentsScreen> {
  static const _bg     = Color(0xFF081A20);
  static const _card   = Color(0xFF132D38);
  static const _stroke = Color(0xFF1E3D4A);
  static const _lime   = Color(0xFFDFFF2F);
  static const _muted  = Color(0xFF7A9BAA);
  static const _white  = Colors.white;

  String _filter = 'Active';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(staffAssignmentsProvider);
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _lime,
        foregroundColor: _bg,
        onPressed: () => _createDialog(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Assignments', style: TextStyle(color: _white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Manage and track student assignments', style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 14),
              // Filter chips
              Row(children: [
                for (final f in ['Active', 'Scheduled', 'Drafts'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _filter == f ? _lime : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _filter == f ? _lime : _stroke),
                        ),
                        child: Text(f, style: TextStyle(
                          color: _filter == f ? _bg : _muted,
                          fontSize: 13, fontWeight: FontWeight.w700,
                        )),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              color: _lime,
              onRefresh: () => ref.refresh(staffAssignmentsProvider.future),
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(child: Text('No assignments yet.', style: TextStyle(color: _muted)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _DarkAssignmentCard(a: list[i] as Map<String, dynamic>),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    int? groupId;
    final titleC = TextEditingController();
    final descC = TextEditingController();
    DateTime? due;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) => AlertDialog(
          backgroundColor: _card,
          title: const Text('New assignment', style: TextStyle(fontWeight: FontWeight.w800, color: _white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DarkGroupDropdown(value: groupId, onChanged: (v) => setLocal(() => groupId = v)),
              const SizedBox(height: 10),
              TextField(
                controller: titleC,
                style: const TextStyle(color: _white),
                decoration: InputDecoration(
                  labelText: 'Title', labelStyle: const TextStyle(color: _muted),
                  filled: true, fillColor: const Color(0xFF081A20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _stroke)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _stroke)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descC, maxLines: 3,
                style: const TextStyle(color: _white),
                decoration: InputDecoration(
                  labelText: 'Description', labelStyle: const TextStyle(color: _muted),
                  hintText: 'Optional', hintStyle: const TextStyle(color: _muted),
                  filled: true, fillColor: const Color(0xFF081A20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _stroke)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _stroke)),
                ),
              ),
              const SizedBox(height: 10),
              _DarkDatePicker(date: due ?? DateTime.now(), onPick: (d) => setLocal(() => due = d)),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dctx), child: const Text('Cancel', style: TextStyle(color: _muted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _lime, foregroundColor: _bg),
              onPressed: saving ? null : () async {
                if (groupId == null || titleC.text.trim().isEmpty) {
                  _toast(dctx, 'Pick a group and enter a title.');
                  return;
                }
                setLocal(() => saving = true);
                try {
                  await ApiClient.instance.dio.post('/assignments/', data: {
                    'group': groupId,
                    'title': titleC.text.trim(),
                    'description': descC.text.trim(),
                    if (due != null) 'due_date': DateFormat('yyyy-MM-dd').format(due!),
                  });
                  ref.invalidate(staffAssignmentsProvider);
                  if (dctx.mounted) Navigator.pop(dctx);
                } on DioException catch (e) {
                  setLocal(() => saving = false);
                  if (dctx.mounted) _toast(dctx, e.response?.data?['detail']?.toString() ?? 'Could not create.');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkAssignmentCard extends StatelessWidget {
  final Map<String, dynamic> a;
  const _DarkAssignmentCard({required this.a});

  static const _bg     = Color(0xFF081A20);
  static const _card   = Color(0xFF132D38);
  static const _stroke = Color(0xFF1E3D4A);
  static const _lime   = Color(0xFFDFFF2F);
  static const _muted  = Color(0xFF7A9BAA);
  static const _white  = Colors.white;

  @override
  Widget build(BuildContext context) {
    final due = a['due_date']?.toString();
    final groupName = a['group_name']?.toString();
    final submitted = a['submitted_count'] as int? ?? 0;
    final total = a['total_students'] as int? ?? 30;
    final progress = total > 0 ? submitted / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.assignment_rounded, color: Color(0xFF7A9BAA), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['title']?.toString() ?? 'Assignment',
                  style: const TextStyle(color: _white, fontWeight: FontWeight.w800, fontSize: 15)),
              if (due != null && due.isNotEmpty)
                Text('Due $due', style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
          ),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: '$submitted', style: const TextStyle(color: _lime, fontWeight: FontWeight.w900, fontSize: 16)),
              TextSpan(text: ' /$total', style: const TextStyle(color: _muted, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        // Tags
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (groupName != null)
            _Tag(groupName.toUpperCase()),
          if (a['subject'] != null)
            _Tag(a['subject'].toString().toUpperCase()),
        ]),
        const SizedBox(height: 10),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: _bg,
            valueColor: const AlwaysStoppedAnimation(_lime),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Submitted', style: TextStyle(color: _muted, fontSize: 10)),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  static const _bg     = Color(0xFF081A20);
  static const _stroke = Color(0xFF1E3D4A);
  static const _white  = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _stroke),
      ),
      child: Text(label, style: const TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  5 · Vocabulary  — list days, create day, manage words
// ════════════════════════════════════════════════════════════════════════════

class StaffVocabularyScreen extends ConsumerWidget {
  const StaffVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(staffVocabularyProvider);
    return Scaffold(
      backgroundColor: IceColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: IceColors.navyDeep,
        onPressed: () => _createDayDialog(context, ref),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New day', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: IceColors.navyDeep,
        onRefresh: () => ref.refresh(staffVocabularyProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: _Header(
                  title: 'Vocabulary',
                  subtitle: 'Word sets for your groups',
                  showBack: true),
            ),
            days.when(
              loading: () => SliverToBoxAdapter(child: _loading()),
              error: (e, _) => SliverToBoxAdapter(child: _error(e)),
              data: (list) {
                if (list.isEmpty) {
                  return _empty('No vocabulary days yet', Icons.menu_book_outlined);
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _VocabDayCard(day: list[i] as Map<String, dynamic>),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDayDialog(BuildContext context, WidgetRef ref) async {
    int? groupId;
    final dayC = TextEditingController();
    final titleC = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('New vocabulary day',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _GroupDropdown(
                  value: groupId, onChanged: (v) => setLocal(() => groupId = v)),
              const SizedBox(height: 10),
              TextField(
                  controller: dayC,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Day number', hint: 'e.g. 1')),
              const SizedBox(height: 10),
              TextField(
                  controller: titleC,
                  decoration: _dec('Title', hint: 'Optional')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dctx),
                child: const Text('Cancel')),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: IceColors.navyDeep),
              onPressed: saving
                  ? null
                  : () async {
                      final dayNum = int.tryParse(dayC.text.trim());
                      if (groupId == null || dayNum == null) {
                        _toast(dctx, 'Pick a group and a day number.');
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        // release_at is required; release immediately.
                        await ApiClient.instance.dio
                            .post('/staff/vocabulary/create/', data: {
                          'group': groupId,
                          'day_number': dayNum,
                          'title': titleC.text.trim(),
                          'release_at':
                              DateTime.now().toUtc().toIso8601String(),
                        });
                        ref.invalidate(staffVocabularyProvider);
                        if (dctx.mounted) Navigator.pop(dctx);
                      } on DioException catch (e) {
                        setLocal(() => saving = false);
                        if (dctx.mounted) {
                          _toast(
                              dctx,
                              e.response?.data?['detail']?.toString() ??
                                  'Could not create.');
                        }
                      }
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabDayCard extends StatelessWidget {
  final Map<String, dynamic> day;
  const _VocabDayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final released = day['is_released'] == true;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StaffVocabularyDetailScreen(
            vocabId: (day['id'] as int).toString()),
      )),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: IceColors.border)),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: IceColors.navyDeep.withAlpha(20),
                borderRadius: BorderRadius.circular(13)),
            child: Text('${day['day_number'] ?? '?'}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: IceColors.navyDeep)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  (day['title']?.toString().isNotEmpty ?? false)
                      ? day['title'].toString()
                      : 'Day ${day['day_number']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                  '${day['group_name'] ?? ''} · ${day['word_count'] ?? 0} words',
                  style: const TextStyle(fontSize: 12.5, color: IceColors.muted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: (released ? IceColors.success : IceColors.warning)
                    .withAlpha(22),
                borderRadius: BorderRadius.circular(20)),
            child: Text(released ? 'Released' : 'Scheduled',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: released ? IceColors.success : IceColors.warning)),
          ),
        ]),
      ),
    );
  }
}

class StaffVocabularyDetailScreen extends ConsumerWidget {
  final String vocabId;
  const StaffVocabularyDetailScreen({super.key, required this.vocabId});

  int get _id => int.tryParse(vocabId) ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(staffVocabDetailProvider(_id));
    return Scaffold(
      backgroundColor: IceColors.bg,
      appBar: AppBar(
        backgroundColor: IceColors.navyDeep,
        foregroundColor: Colors.white,
        title: const Text('Vocabulary day'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: IceColors.navyDeep,
        onPressed: () => _addWordDialog(context, ref),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add word', style: TextStyle(color: Colors.white)),
      ),
      body: detail.when(
        loading: () => _loading(),
        error: (e, _) => _error(e),
        data: (d) {
          final words = (d['words'] as List?) ?? [];
          return RefreshIndicator(
            color: IceColors.navyDeep,
            onRefresh: () => ref.refresh(staffVocabDetailProvider(_id).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                    (d['title']?.toString().isNotEmpty ?? false)
                        ? d['title'].toString()
                        : 'Day ${d['day_number']}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${d['group_name'] ?? ''} · ${words.length} words',
                    style: const TextStyle(color: IceColors.muted)),
                const SizedBox(height: 16),
                if (words.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No words yet. Tap “Add word”.',
                          style: TextStyle(color: IceColors.muted)),
                    ),
                  )
                else
                  ...words.map((w) =>
                      _WordTile(id: _id, word: w as Map<String, dynamic>)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addWordDialog(BuildContext context, WidgetRef ref) async {
    final wordC = TextEditingController();
    final meaningC = TextEditingController();
    final exampleC = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add word',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: wordC, decoration: _dec('Word')),
              const SizedBox(height: 10),
              TextField(controller: meaningC, decoration: _dec('Meaning')),
              const SizedBox(height: 10),
              TextField(
                  controller: exampleC,
                  maxLines: 2,
                  decoration: _dec('Example', hint: 'Optional')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dctx),
                child: const Text('Cancel')),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: IceColors.navyDeep),
              onPressed: saving
                  ? null
                  : () async {
                      if (wordC.text.trim().isEmpty ||
                          meaningC.text.trim().isEmpty) {
                        _toast(dctx, 'Word and meaning are required.');
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        await ApiClient.instance.dio
                            .post('/staff/vocabulary/$_id/words/', data: {
                          'word': wordC.text.trim(),
                          'meaning': meaningC.text.trim(),
                          'example_sentence': exampleC.text.trim(),
                        });
                        ref.invalidate(staffVocabDetailProvider(_id));
                        ref.invalidate(staffVocabularyProvider);
                        if (dctx.mounted) Navigator.pop(dctx);
                      } on DioException catch (e) {
                        setLocal(() => saving = false);
                        if (dctx.mounted) {
                          _toast(
                              dctx,
                              e.response?.data?['detail']?.toString() ??
                                  'Could not add.');
                        }
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordTile extends ConsumerWidget {
  final int id;
  final Map<String, dynamic> word;
  const _WordTile({required this.id, required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IceColors.border)),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(word['word']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(word['meaning']?.toString() ?? '',
                style: const TextStyle(fontSize: 13, color: IceColors.muted)),
            if ((word['example_sentence']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('“${word['example_sentence']}”',
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: IceColors.muted)),
            ],
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: IceColors.danger, size: 20),
          onPressed: () async {
            try {
              await ApiClient.instance.dio
                  .delete('/staff/vocabulary/$id/words/${word['id']}/');
              ref.invalidate(staffVocabDetailProvider(id));
              ref.invalidate(staffVocabularyProvider);
            } on DioException {
              if (context.mounted) _toast(context, 'Could not delete.');
            }
          },
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  6 · Leave  — apply + history (own staff leave)
// ════════════════════════════════════════════════════════════════════════════

class StaffLeaveScreen extends ConsumerStatefulWidget {
  const StaffLeaveScreen({super.key});
  @override
  ConsumerState<StaffLeaveScreen> createState() => _StaffLeaveScreenState();
}

class _StaffLeaveScreenState extends ConsumerState<StaffLeaveScreen> {
  DateTime? _date;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_date == null || _reason.text.trim().isEmpty) {
      _toast(context, 'Pick a date and add a reason.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.dio.post('/leave/', data: {
        'date': DateFormat('yyyy-MM-dd').format(_date!),
        'message': _reason.text.trim(),
      });
      ref.invalidate(leaveProvider);
      if (mounted) {
        setState(() {
          _reason.clear();
          _date = null;
        });
        _toast(context, 'Leave request submitted.');
      }
    } on DioException {
      if (mounted) _toast(context, 'Could not submit. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaves = ref.watch(leaveProvider);
    return Scaffold(
      backgroundColor: IceColors.bg,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: _Header(title: 'Leave', subtitle: 'Request time off', showBack: true),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(children: [
                _DatePickerField(
                    date: _date,
                    label: 'Date',
                    onPick: (d) => setState(() => _date = d)),
                const SizedBox(height: 12),
                TextField(
                    controller: _reason,
                    maxLines: 3,
                    decoration: _dec('Reason', hint: 'Briefly explain…')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: IceColors.navyDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Submit request'),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('History',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ]),
            ),
          ),
          leaves.when(
            loading: () => SliverToBoxAdapter(child: _loading()),
            error: (e, _) => SliverToBoxAdapter(child: _error(e)),
            data: (list) {
              if (list.isEmpty) {
                return _empty('No leave requests', Icons.event_busy_outlined);
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _LeaveCard(leave: list[i] as Map<String, dynamic>),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  const _LeaveCard({required this.leave});

  @override
  Widget build(BuildContext context) {
    final st = leave['status'];
    final (label, color) = switch (st) {
      1 => ('Approved', IceColors.success),
      -1 => ('Rejected', IceColors.danger),
      _ => ('Pending', IceColors.warning),
    };
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IceColors.border)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(fmtDate(leave['date']?.toString()),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ]),
        if ((leave['message']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(leave['message'].toString(),
              style: const TextStyle(fontSize: 13, color: IceColors.muted)),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  7 · Feedback  — send to admin + view replies (own staff feedback)
// ════════════════════════════════════════════════════════════════════════════

class StaffFeedbackScreen extends ConsumerStatefulWidget {
  const StaffFeedbackScreen({super.key});
  @override
  ConsumerState<StaffFeedbackScreen> createState() =>
      _StaffFeedbackScreenState();
}

class _StaffFeedbackScreenState extends ConsumerState<StaffFeedbackScreen> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_text.text.trim().isEmpty) {
      _toast(context, 'Write your feedback first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.dio
          .post('/feedback/', data: {'feedback': _text.text.trim()});
      ref.invalidate(feedbackProvider);
      if (mounted) {
        setState(() => _text.clear());
        _toast(context, 'Feedback sent.');
      }
    } on DioException {
      if (mounted) _toast(context, 'Could not send. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(feedbackProvider);
    return Scaffold(
      backgroundColor: IceColors.bg,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: _Header(
                title: 'Feedback',
                subtitle: 'Send a note to administration',
                showBack: true),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(children: [
                TextField(
                    controller: _text,
                    maxLines: 4,
                    decoration: _dec('Your feedback',
                        hint: 'Share a suggestion or concern…')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: IceColors.navyDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Send feedback'),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Previous feedback',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ]),
            ),
          ),
          items.when(
            loading: () => SliverToBoxAdapter(child: _loading()),
            error: (e, _) => SliverToBoxAdapter(child: _error(e)),
            data: (list) {
              if (list.isEmpty) {
                return _empty('No feedback yet', Icons.rate_review_outlined);
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _FeedbackCard(fb: list[i] as Map<String, dynamic>),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> fb;
  const _FeedbackCard({required this.fb});

  @override
  Widget build(BuildContext context) {
    final reply = fb['reply']?.toString() ?? '';
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IceColors.border)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fb['feedback']?.toString() ?? '',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: IceColors.text)),
        if (reply.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: IceColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IceColors.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.reply_rounded,
                  size: 16, color: IceColors.navyDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reply,
                    style: const TextStyle(
                        fontSize: 13, color: IceColors.text)),
              ),
            ]),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Awaiting reply',
                style: TextStyle(
                    fontSize: 11.5,
                    color: IceColors.muted,
                    fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Shared date-picker field
// ════════════════════════════════════════════════════════════════════════════

class _DatePickerField extends StatelessWidget {
  final DateTime? date;
  final String label;
  final ValueChanged<DateTime> onPick;
  const _DatePickerField({
    required this.date,
    this.label = 'Date',
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? now,
          firstDate: now.subtract(const Duration(days: 60)),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: _dec(label),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 16, color: IceColors.muted),
          const SizedBox(width: 8),
          Text(
            date != null
                ? DateFormat('MMM d, yyyy').format(date!)
                : 'Select date',
            style: TextStyle(
                color: date != null ? IceColors.text : IceColors.muted,
                fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}
