import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/ice_tokens.dart';
import '../../../shared/widgets/ice_shell.dart';

/// Applies the ICEBERG dark design system (theme mode, accent colour and
/// font size from Settings) to the whole student experience without
/// affecting the staff/admin sections of the app.
class StudentThemeScope extends ConsumerWidget {
  final Widget child;
  const StudentThemeScope({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(settings.textScale)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class StudentShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const StudentShell({super.key, required this.navigationShell});

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  @override
  void initState() {
    super.initState();
    // Pull server-side appearance/notification preferences once per session.
    Future.microtask(
      () => ref.read(appSettingsProvider.notifier).syncFromServer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentThemeScope(
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
          bottomNavigationBar: IceBottomNav(
            index: widget.navigationShell.currentIndex,
            onTap: (i) => widget.navigationShell.goBranch(
              i,
              initialLocation: i == widget.navigationShell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
