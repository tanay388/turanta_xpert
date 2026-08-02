import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/shell/xpert_list_group.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/presentation/auth_controller.dart';

/// Profile.
///
/// A pushed screen, so it keeps a plain app bar — the dark canvas belongs to
/// the tabs a partner lands on, not to everything they open.
///
/// Inside, the four facts about an account used to be four separately bordered
/// cards, one of which repeated the name already set in headline type at the
/// top, and Edit profile appeared twice: once in the app bar and once as a
/// full-width button underneath.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final profile = session?.profile;
    final name = profile?.displayName ?? ref.t('home.default_name');
    final phone = profile?.phone ?? session?.phone ?? '—';
    final shift = profile?.shift;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('profile.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          XpertSpacing.lg,
          XpertSpacing.md,
          XpertSpacing.lg,
          XpertSpacing.xxl,
        ),
        children: [
          _Identity(name: name, phone: phone, photo: profile?.photo),
          const SizedBox(height: XpertSpacing.xl),
          SectionLabel(ref.t('profile.section.account')),
          const SizedBox(height: XpertSpacing.sm),
          XpertListGroup(
            children: [
              XpertListRow(
                icon: Icons.badge_outlined,
                title: ref.t('profile.gender'),
                value: profile?.gender ?? '—',
              ),
              XpertListRow(
                icon: Icons.schedule_rounded,
                title: ref.t('profile.shift'),
                value: shift == null
                    ? '—'
                    : '${shift.name} · ${shift.displayWindow}',
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.xl),
          SectionLabel(ref.t('profile.section.more')),
          const SizedBox(height: XpertSpacing.sm),
          // Navigation, grouped and visually distinct from the facts above —
          // the two used to look identical.
          XpertListGroup(
            children: [
              XpertListRow(
                icon: Icons.map_outlined,
                title: ref.t('hub.title'),
                onTap: () => context.push('/hub'),
              ),
              XpertListRow(
                icon: Icons.account_balance_wallet_outlined,
                title: ref.t('financial.title'),
                onTap: () => context.push('/profile/financial'),
              ),
              XpertListRow(
                icon: Icons.settings_outlined,
                title: ref.t('settings.title'),
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.xl),
          // The one primary action, kept low where a thumb reaches it rather
          // than duplicated up in the app bar.
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () => context.push('/profile/edit'),
              icon: const Icon(Icons.edit_rounded, size: 19),
              label: Text(
                ref.t('profile.edit_cta'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Identity extends ConsumerWidget {
  const _Identity({required this.name, required this.phone, this.photo});

  final String name;
  final String phone;
  final String? photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = photo != null && photo!.isNotEmpty;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();

    return Column(
      children: [
        // The avatar is editable, and now says so — `profile.change_photo`
        // existed as a string with nothing on this screen to attach it to.
        Semantics(
          button: true,
          label: ref.t('profile.change_photo'),
          child: InkWell(
            onTap: () => context.push('/profile/edit'),
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: XpertColors.secondary,
                    image: hasPhoto
                        ? DecorationImage(
                            image: NetworkImage(photo!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: hasPhoto
                      ? null
                      : Text(
                          initials.isEmpty ? 'P' : initials,
                          style: XpertTypography.title.copyWith(fontSize: 30),
                        ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: XpertColors.primary,
                      border: Border.all(color: XpertColors.background, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 13,
                      color: XpertColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: XpertSpacing.md),
        Text(
          name,
          textAlign: TextAlign.center,
          style: XpertTypography.title.copyWith(fontSize: 22),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        // The name and phone are already here in full, which is why the list
        // below no longer repeats them.
        Text(
          phone,
          textAlign: TextAlign.center,
          style: XpertTypography.caption.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}
