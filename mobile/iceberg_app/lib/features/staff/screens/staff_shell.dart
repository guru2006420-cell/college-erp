import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/ice_tokens.dart';
import '../../../shared/widgets/ice_shell.dart';

class StaffShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const StaffShell({super.key, required this.navigationShell});

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appSettingsProvider.notifier).syncFromServer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformDark,
    };
    final theme = buildIceTheme(dark: dark, accent: settings.accentColor);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Theme(
        data: theme,
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(settings.textScale)),
            child: Builder(
              builder: (themed) => Scaffold(
                backgroundColor: themed.ice.bg,
                drawer: const IceDrawer(),
                appBar: const IceHeader(),
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: widget.navigationShell,
                  ),
                ),
                bottomNavigationBar: _StaffBottomNav(
                  index: widget.navigationShell.currentIndex,
                  onTap: (i) => widget.navigationShell.goBranch(
                    i,
                    initialLocation: i == widget.navigationShell.currentIndex,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffBottomNav extends ConsumerWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _StaffBottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ice;
    const items = [
      (Icons.grid_view_rounded, 'Dashboard'),
      (Icons.event_available_rounded, 'Attendance'),
      (Icons.bar_chart_rounded, 'Results'),
      (Icons.assignment_outlined, 'Assignments'),
      (Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.isDark ? const Color(0xFF0A2024) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: t.stroke)),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: t.isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(items.length, (i) {
              final active = i == index;
              final (icon, label) = items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  child: active
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: t.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        t.accent.withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(icon,
                                  color: t.onAccent, size: 21),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: t.textMid, size: 22),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: t.textLow,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            }),
            ),
          ),
        ),
      ),
    );
  }
}
