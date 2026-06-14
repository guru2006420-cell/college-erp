import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_state.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/coming_soon_screen.dart';

// Student
import '../../features/student/screens/student_shell.dart';
import '../../features/student/screens/student_home_screen.dart';
import '../../features/student/screens/student_attendance_screen.dart';
import '../../features/student/screens/student_results_screen.dart';
import '../../features/student/screens/student_leave_screen.dart';
import '../../features/student/screens/student_feedback_screen.dart';
import '../../features/student/screens/student_assignments_screen.dart';
import '../../features/student/screens/student_payments_screen.dart';
import '../../features/student/screens/student_notifications_screen.dart';
import '../../features/student/screens/student_vocabulary_screen.dart';
import '../../features/student/screens/student_vocabulary_detail_screen.dart';
import '../../features/student/screens/student_flashcard_screen.dart';
import '../../features/student/screens/student_vocabulary_quiz_screen.dart';
import '../../features/student/screens/student_result_files_screen.dart';
import '../../features/student/screens/student_books_screen.dart';
import '../../features/student/screens/student_leaderboard_screen.dart';
import '../../features/student/screens/student_progress_screen.dart';
import '../../features/student/screens/student_profile_screen.dart';
import '../../features/student/screens/student_settings_screen.dart';
import '../../features/student/screens/student_messages_screen.dart';
import '../../features/student/screens/student_assignment_detail_screen.dart';
import '../../features/student/screens/student_learn_screen.dart';

// Staff
import '../../features/staff/screens/staff_shell.dart';
import '../../features/staff/screens/staff_home_screen.dart';
import '../../features/staff/screens/staff_more_screen.dart';
import '../../features/staff/screens/staff_placeholder_screens.dart';
import '../../features/staff/screens/staff_feature_screens.dart';
import '../../features/staff/screens/staff_profile_screen.dart';

// Shared
import '../../shared/screens/profile_hub_screen.dart';
import '../../shared/screens/messages_screen.dart';

/// Routing by role:
///   - Student (user_type 3) → full /student/* experience
///   - Staff   (user_type 2) → teacher portal /staff/*
///   - Admin   (user_type 1) → /coming-soon (admin web portal handles them)
///
/// Each role's sub-screens are nested inside the role's StatefulShellRoute
/// branches so the bottom navigation bar persists and back-navigation works.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);

  return GoRouter(
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.matchedLocation;

      if (auth.status == AuthStatus.loading) return '/splash';

      if (auth.status == AuthStatus.unauthenticated) {
        return path == '/login' ? null : '/login';
      }

      final user = auth.user!;

      // Admin → coming-soon wall (admin dashboard ships on the web portal).
      if (user.isAdmin) {
        return path == '/coming-soon' ? null : '/coming-soon';
      }

      // Staff (teachers) → teacher portal.
      if (user.isStaff) {
        if (path.startsWith('/staff')) return null;
        return '/staff/home';
      }

      // Students → student app; bounce off auth/transitional routes.
      if (path == '/login' ||
          path == '/splash' ||
          path == '/coming-soon' ||
          path.startsWith('/staff')) {
        return '/student/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/coming-soon', builder: (_, __) => const ComingSoonScreen()),

      // ── Staff shell (5 bottom-nav branches) ──────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StaffShell(navigationShell: navigationShell),
        branches: [
          // 0 · Dashboard
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/staff/home',
              builder: (_, __) => const StaffHomeScreen(),
            ),
          ]),
          // 1 · Attendance + update
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/staff/attendance',
              builder: (_, __) => const StaffAttendanceScreen(),
              routes: [
                GoRoute(
                  path: 'update',
                  builder: (_, __) => const StaffUpdateAttendanceScreen(),
                ),
              ],
            ),
          ]),
          // 2 · Results
          StatefulShellBranch(routes: [
            GoRoute(path: '/staff/results', builder: (_, __) => const StaffResultsScreen()),
          ]),
          // 3 · Assignments
          StatefulShellBranch(routes: [
            GoRoute(path: '/staff/assignments', builder: (_, __) => const StaffAssignmentsScreen()),
          ]),
          // 4 · Profile
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/staff/profile',
              builder: (_, __) => const ProfileHubScreen(),
              routes: [
                GoRoute(
                  path: 'avatar',
                  builder: (_, __) => const StaffAvatarScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),
      // Staff standalone screens (pushed full-screen; each shows its own back affordance).
      GoRoute(path: '/staff/classes',       builder: (_, __) => const StaffClassesScreen()),
      GoRoute(path: '/staff/more',          builder: (_, __) => const StaffMoreScreen()),
      GoRoute(path: '/staff/vocabulary',    builder: (_, __) => const StaffVocabularyScreen()),
      GoRoute(
        path: '/staff/vocabulary/:id',
        builder: (_, state) => StaffVocabularyDetailScreen(
            vocabId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/staff/leave',         builder: (_, __) => const StaffLeaveScreen()),
      GoRoute(path: '/staff/feedback',      builder: (_, __) => const StaffFeedbackScreen()),
      GoRoute(path: '/staff/payments',      builder: (_, __) => const StaffPaymentsScreen()),
      GoRoute(path: '/staff/notifications', builder: (_, __) => const StaffNotificationsScreen()),
      GoRoute(path: '/staff/settings',      builder: (_, __) => const StudentSettingsScreen()),
      GoRoute(path: '/staff/messages',      builder: (_, __) => const MessagesScreen()),

      // ── Student shell (5 bottom-nav branches) ────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudentShell(navigationShell: navigationShell),
        branches: [
          // 0 · Dashboard + its drill-downs
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/home',
                builder: (_, __) => const StudentHomeScreen(),
              ),
              GoRoute(
                path: '/student/notifications',
                builder: (_, __) => const StudentNotificationsScreen(),
              ),
              GoRoute(
                path: '/student/messages',
                builder: (_, __) => const StudentMessagesScreen(),
                routes: [
                  GoRoute(
                    path: ':groupId',
                    builder: (_, state) => StudentChatScreen(
                      groupId:
                          int.tryParse(state.pathParameters['groupId']!) ?? 0,
                      groupName: state.uri.queryParameters['name'] ?? 'Chat',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/student/assignments',
                builder: (_, __) => const StudentAssignmentsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => StudentAssignmentDetailScreen(
                      assignmentId:
                          int.tryParse(state.pathParameters['id']!) ?? 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 1 · Progress + Attendance Hub
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/progress',
                builder: (_, __) => const StudentProgressScreen(),
              ),
              GoRoute(
                path: '/student/attendance',
                builder: (_, __) => const StudentAttendanceScreen(),
              ),
            ],
          ),
          // 2 · Vocabulary
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/vocabulary',
                builder: (_, __) => const StudentVocabularyScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => StudentVocabularyDetailScreen(
                      vocabId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'flashcards',
                        builder: (_, state) => StudentFlashcardScreen(
                          vocabId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'learn',
                        builder: (_, state) => StudentLearnScreen(
                          vocabId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'quiz',
                        builder: (_, state) => StudentVocabularyQuizScreen(
                          dayId:
                              int.tryParse(state.pathParameters['id'] ?? '') ??
                              0,
                          dayTitle:
                              state.uri.queryParameters['title'] ??
                              'Vocabulary Quiz',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 3 · Leaderboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/leaderboard',
                builder: (_, __) => const StudentLeaderboardScreen(),
              ),
            ],
          ),
          // 4 · Profile + student services
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/profile',
                builder: (_, __) => const StudentProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, __) => const StudentEditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'avatar',
                    builder: (_, __) => const StudentAvatarScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/student/settings',
                builder: (_, __) => const StudentSettingsScreen(),
              ),
              GoRoute(
                path: '/student/results',
                builder: (_, __) => const StudentResultsScreen(),
              ),
              GoRoute(
                path: '/student/result-files',
                builder: (_, __) => const StudentResultFilesScreen(),
              ),
              GoRoute(
                path: '/student/library',
                builder: (_, __) => const StudentBooksScreen(),
              ),
              GoRoute(
                path: '/student/books',
                builder: (_, __) => const StudentBooksScreen(),
              ),
              GoRoute(
                path: '/student/payments',
                builder: (_, __) => const StudentPaymentsScreen(),
              ),
              GoRoute(
                path: '/student/leave',
                builder: (_, __) => const StudentLeaveScreen(),
              ),
              GoRoute(
                path: '/student/feedback',
                builder: (_, __) => const StudentFeedbackScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

// ── Splash screen ──────────────────────────────────────────────────────────────

const _kNavy = Color(0xFF050F1A);

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Phase 1: logo (0 → 500 ms)
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Phase 2: each of 6 icons gets its own window (450 → 1300 ms, 130 ms apart)
  late final List<Animation<double>> _iconScales;
  late final List<Animation<double>> _iconFades;

  // Phase 3: tagline (1250 → 1600 ms)
  late final Animation<double> _tagFade;

  static const _icons = ['📚', '📅', '📝', '💳', '🏆', '📖'];
  static const _totalMs = 1800;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    )..forward();

    double t(int ms) => ms / _totalMs;

    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(t(0), t(500), curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(t(0), t(500), curve: Curves.easeOutCubic),
      ),
    );

    _iconScales = List.generate(_icons.length, (i) {
      final start = 450 + i * 130;
      final end = start + 260;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(t(start), t(end.clamp(0, _totalMs)),
              curve: Curves.easeOutBack),
        ),
      );
    });
    _iconFades = List.generate(_icons.length, (i) {
      final start = 450 + i * 130;
      final end = start + 180;
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(t(start), t(end.clamp(0, _totalMs)),
            curve: Curves.easeOut),
      );
    });

    _tagFade = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(t(1250), t(1600), curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.2,
            colors: [Color(0xFF0A1F35), Color(0xFF071629), _kNavy],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Main content column
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo block ──────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: const _IcebergLogo(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // ── Feature icons ───────────────────────────────────────
                  SizedBox(
                    width: 280,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          _icons.length,
                          (i) => Opacity(
                            opacity: _iconFades[i].value,
                            child: Transform.scale(
                              scale: _iconScales[i].value,
                              child: Text(
                                _icons[i],
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // ── Tagline ─────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _tagFade,
                    builder: (_, __) => Opacity(
                      opacity: _tagFade.value,
                      child: const Text(
                        'Learn. Track. Grow.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.0,
                          color: Color(0xFF7DCFE8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IcebergLogo extends StatelessWidget {
  const _IcebergLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: 180,
      height: 180,
      fit: BoxFit.contain,
    );
  }
}

