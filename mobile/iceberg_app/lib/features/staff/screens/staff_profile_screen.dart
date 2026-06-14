import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/ice_tokens.dart';
import '../../../shared/widgets/ice_kit.dart';
import '../../../shared/widgets/ice_shell.dart';

class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ice;
    final s = ref.watch(stringsProvider);
    final user = ref.watch(authProvider).user;

    return IcePage(
      title: s('Profile'),
      children: [
        // ── Avatar ────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              IceUserAvatar(
                radius: 48,
                photoUrl: user?.profilePicUrl,
                emoji: user?.avatar.isNotEmpty == true ? user!.avatar : null,
                fallbackText: user?.firstName.isNotEmpty == true
                    ? user!.firstName[0].toUpperCase()
                    : 'T',
              ),
              const SizedBox(height: 12),
              Text(
                user?.fullName ?? '',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.textHi,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s('Teacher'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.accentInk,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Info cards ────────────────────────────────────────────
        SectionHeader(s('Account Info')),
        IceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Login ID',
                  value: user?.loginId ?? '—'),
              const SizedBox(height: 12),
              _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? '—'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Appearance ────────────────────────────────────────────
        SectionHeader(s('Appearance')),
        ActionTile(
          icon: Icons.settings_outlined,
          title: s('Settings'),
          subtitle: s('Theme, language, notifications'),
          onTap: () => context.go('/staff/settings'),
        ),

        const SizedBox(height: 16),

        // ── Security ──────────────────────────────────────────────
        SectionHeader(s('Security')),
        ActionTile(
          icon: Icons.lock_outline_rounded,
          title: s('Change Password'),
          subtitle: 'Update your account password',
          onTap: () {
            // Reuse the same change-password flow from settings
            showDialog(
              context: context,
              builder: (_) => const _ChangePasswordDialog(),
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Logout ────────────────────────────────────────────────
        SectionHeader(''),
        IceCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading:
                Icon(Icons.logout_rounded, color: t.coral, size: 22),
            title: Text(
              s('Log out'),
              style: TextStyle(
                color: t.coral,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.ice;
    return Row(
      children: [
        Icon(icon, size: 18, color: t.textMid),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: t.textMid),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.textHi),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Reuse the change-password logic from StudentSettingsScreen in a dialog
class _ChangePasswordDialog extends StatelessWidget {
  const _ChangePasswordDialog();

  @override
  Widget build(BuildContext context) {
    // Delegate to the StudentSettingsScreen's modal by pushing the settings
    // screen which has the change-password bottom sheet.
    // For now, inform user to use the Settings screen.
    final t = context.ice;
    return AlertDialog(
      backgroundColor: t.card,
      title: Text('Change Password',
          style: TextStyle(color: t.textHi, fontWeight: FontWeight.w800)),
      content: Text(
        'Go to Settings → Change Password to update your password.',
        style: TextStyle(color: t.textMid),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK', style: TextStyle(color: t.accent)),
        ),
      ],
    );
  }
}
