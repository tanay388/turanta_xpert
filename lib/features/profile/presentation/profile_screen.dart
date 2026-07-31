import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final profile = session?.profile;
    final name = profile?.displayName ?? 'Partner';
    final phone = profile?.phone ?? session?.phone ?? '—';
    final photo = profile?.photo;
    final shift = profile?.shift;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        title: Text(ref.t('profile.title')),
        actions: [
          TextButton(
            onPressed: () => context.push('/profile/edit'),
            child: Text(ref.t('profile.edit')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(XpertSpacing.lg),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: XpertColors.secondary,
              backgroundImage:
                  photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo == null || photo.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: XpertTypography.title.copyWith(fontSize: 36),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: XpertSpacing.md),
          Text(
            name,
            textAlign: TextAlign.center,
            style: XpertTypography.title.copyWith(fontSize: 24),
          ),
          const SizedBox(height: XpertSpacing.xs),
          Text(
            phone,
            textAlign: TextAlign.center,
            style: XpertTypography.caption,
          ),
          const SizedBox(height: XpertSpacing.xl),
          _InfoTile(
            label: ref.t('profile.name'),
            value: profile?.name?.trim().isNotEmpty == true
                ? profile!.name!
                : '—',
          ),
          _InfoTile(label: ref.t('profile.phone'), value: phone),
          _InfoTile(
            label: ref.t('profile.gender'),
            value: profile?.gender ?? '—',
          ),
          _InfoTile(
            label: ref.t('profile.shift'),
            value: shift != null
                ? '${shift.name} (${shift.displayWindow})'
                : '—',
          ),
          const SizedBox(height: XpertSpacing.lg),
          _MenuTile(
            icon: Icons.map_outlined,
            label: ref.t('hub.title'),
            onTap: () => context.push('/hub'),
          ),
          _MenuTile(
            icon: Icons.account_balance_wallet_outlined,
            label: ref.t('financial.title'),
            onTap: () => context.push('/profile/financial'),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: ref.t('settings.title'),
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: XpertSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => context.push('/profile/edit'),
              icon: const Icon(Icons.edit),
              label: Text(
                ref.t('profile.edit_cta'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: XpertColors.primary,
                foregroundColor: XpertColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: XpertSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              label: Text(ref.t('pending.sign_out')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: XpertSpacing.sm),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(XpertRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(XpertSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: XpertColors.muted),
                const SizedBox(width: XpertSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: XpertTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: XpertColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: XpertSpacing.sm),
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: XpertTypography.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: XpertTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}
