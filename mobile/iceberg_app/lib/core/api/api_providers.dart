import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

// ── Retry-aware fetch helpers ──────────────────────────────────────────────

bool _isNetworkError(DioException e) =>
    e.type == DioExceptionType.connectionError ||
    e.type == DioExceptionType.connectionTimeout ||
    e.type == DioExceptionType.sendTimeout ||
    e.type == DioExceptionType.receiveTimeout;

Future<Map<String, dynamic>> apiGet(String path) async {
  const attempts = 3;
  const delays = [1, 2]; // seconds between retries
  for (var i = 0; i < attempts; i++) {
    try {
      final res = await ApiClient.instance.dio.get(path);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (!_isNetworkError(e) || i == attempts - 1) rethrow;
      await Future.delayed(Duration(seconds: delays[i]));
    }
  }
  throw Exception('unreachable');
}

Future<List<dynamic>> apiGetList(String path) async {
  const attempts = 3;
  const delays = [1, 2];
  for (var i = 0; i < attempts; i++) {
    try {
      final res = await ApiClient.instance.dio.get(path);
      final data = res.data;
      if (data is List) return data;
      if (data is Map && data.containsKey('results')) {
        return data['results'] as List;
      }
      return [];
    } on DioException catch (e) {
      if (!_isNetworkError(e) || i == attempts - 1) rethrow;
      await Future.delayed(Duration(seconds: delays[i]));
    }
  }
  return [];
}

// ── Student dashboard — cached AsyncNotifier ───────────────────────────────
// Shows the last successful response from SharedPreferences immediately on
// launch, then refreshes in the background so the screen is never blank.

class StudentDashNotifier extends AsyncNotifier<Map<String, dynamic>> {
  static const _cacheKey = 'cache_student_dash';
  bool _refreshing = false;
  // Incremented each time build() runs so stale background refreshes are
  // ignored after an explicit reload() or invalidation.
  int _epoch = 0;

  @override
  Future<Map<String, dynamic>> build() async {
    final epoch = ++_epoch;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      _scheduleBackgroundRefresh(prefs, epoch);
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
    return _fetch(prefs);
  }

  Future<Map<String, dynamic>> _fetch(SharedPreferences prefs) async {
    final data = await apiGet('/student/home/');
    prefs.setString(_cacheKey, jsonEncode(data));
    return data;
  }

  void _scheduleBackgroundRefresh(SharedPreferences prefs, int epoch) {
    if (_refreshing) return;
    _refreshing = true;
    Future.microtask(() async {
      try {
        final data = await _fetch(prefs);
        // Only update if no newer build/reload has run
        if (_epoch == epoch) state = AsyncData(data);
      } catch (_) {
        // Silently keep showing cached data on error
      } finally {
        _refreshing = false;
      }
    });
  }

  /// Silently refresh without showing a skeleton — used by the 45s timer
  /// and foreground-resume lifecycle so scrolling is never interrupted.
  Future<void> backgroundRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final epoch = ++_epoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = await _fetch(prefs);
      if (_epoch == epoch) state = AsyncData(data);
    } catch (_) {
      // Keep stale data visible on network error
    } finally {
      _refreshing = false;
    }
  }

  /// Force a fresh fetch; shows skeleton while loading (pull-to-refresh only).
  Future<void> reload() async {
    ++_epoch; // Invalidate any in-flight background refresh
    state = const AsyncLoading();
    final prefs = await SharedPreferences.getInstance();
    try {
      state = AsyncData(await _fetch(prefs));
    } catch (e, st) {
      // Fall back to cached data rather than showing an error screen
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        state = AsyncData(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } else {
        state = AsyncError(e, st);
      }
    }
  }
}

final studentDashProvider =
    AsyncNotifierProvider<StudentDashNotifier, Map<String, dynamic>>(
      StudentDashNotifier.new,
    );

// Student attendance
final studentAttendanceProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/attendance/'),
);

// Student results
final studentResultsProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/results/'),
);

// Student / staff leaves
final leaveProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/leave/'),
);

// Staff dashboard (stats)
final staffStatsProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/stats/'),
);

// Staff groups
final staffGroupsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/groups/'),
);

// Admin dashboard
final adminDashProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/admin/home/'),
);

// Admin students list
final adminStudentsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/students/'),
);

// Admin staff list
final adminStaffProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/staff/'),
);

// Admin registration leads
final adminLeadsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/leads/'),
);

// Groups (all roles — branch-scoped on server side)
final groupsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/groups/'),
);

// Courses
final coursesProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/courses/'),
);

// Assignments (role-scoped on server)
final assignmentsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/assignments/'),
);

// Notifications
final notificationsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/notifications/'),
);

// Invoices (student: own; admin: all)
final invoicesProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/invoices/'),
);

// Feedback (student/staff: own; admin: all)
final feedbackProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/feedback/'),
);

// Vocabulary days (student: own groups; released)
final vocabularyProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/vocabulary/'),
);

// Leaderboard (active season)
final leaderboardProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/leaderboard/'),
);

// Admin branches
final adminBranchesProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/branches/'),
);

// Admin stats (for superadmin overview)
final adminStatsProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/admin/stats/'),
);

// Stories (student sees own groups; admin/staff see all)
final storiesProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/stories/'),
);

// Student progress charts
final studentProgressProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/student/progress/'),
);

// Vocabulary quiz for a specific day
final vocabQuizProvider = FutureProvider.family<List<dynamic>, int>(
  (_, pk) => apiGetList('/vocabulary/$pk/quiz/'),
);

// Staff vocabulary days
final staffVocabularyProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/staff/vocabulary/'),
);

// Staff vocabulary day detail
final staffVocabDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>(
      (_, pk) => apiGet('/staff/vocabulary/$pk/'),
    );

// Admin groups list
final adminGroupsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/groups/'),
);

// Admin groups (CRUD endpoint — includes enrolled_count, monthly_fee, start_date)
final adminGroupsManageProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/groups-manage/'),
);

// Staff list (for teacher dropdown in add/edit group)
final adminStaffListProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/staff/'),
);

// Admin users list (HOD accounts — superadmin only)
final adminAdminsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/admin/admins/'),
);

// ── Student mobile app (ICEBERG redesign) ───────────────────────────────────

// Attendance Hub: calendar month + streak + 12-week trend.
// Family key: 'YYYY-MM|groupId' ('' parts allowed).
final attendanceSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, String>((_, key) {
      final parts = key.split('|');
      final qs = <String>[
        if (parts.isNotEmpty && parts[0].isNotEmpty) 'month=${parts[0]}',
        if (parts.length > 1 && parts[1].isNotEmpty) 'group_id=${parts[1]}',
      ].join('&');
      return apiGet('/student/attendance/summary/${qs.isEmpty ? '' : '?$qs'}');
    });

// Downloadable result files
final resultFilesProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/result-files/'),
);

// Vocabulary day detail (words, completion, progress)
final vocabDayProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (_, pk) => apiGet('/vocabulary/$pk/'),
);

// Assignment detail (incl. my_submission)
final assignmentDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>(
      (_, pk) => apiGet('/assignments/$pk/'),
    );

// Leaderboard with scope tabs (overall | group | branch)
final leaderboardScopedProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
      (_, scope) => apiGet('/leaderboard/?scope=$scope'),
    );

// Group chat threads
final messageThreadsProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/messages/'),
);

// Library books
final booksProvider = FutureProvider<Map<String, dynamic>>(
  (_) => apiGet('/books/'),
);

// Staff payments (invoices for teacher's groups)
final staffPaymentsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/staff/payments/'),
);

// ── Teacher portal ───────────────────────────────────────────────────────────
// Group detail incl. enrolled students (for attendance & results rosters).
final groupDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>(
  (_, id) => apiGet('/groups/$id/'),
);

// Existing results for a group (teacher view).
final groupResultsProvider =
    FutureProvider.family<List<dynamic>, int>(
  (_, groupId) => apiGetList('/results/?group_id=$groupId'),
);

// Teacher's own assignments.
final staffAssignmentsProvider = FutureProvider<List<dynamic>>(
  (_) => apiGetList('/assignments/'),
);
