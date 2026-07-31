import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';

/// Settings: language switch, WhatsApp / notification toggles, sign out.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _savingPrefs = false;

  Future<void> _setPref({bool? whatsapp, bool? push}) async {
    setState(() => _savingPrefs = true);
    try {
      await ref
          .read(partnerAuthApiProvider)
          .updatePreferences(whatsappOptIn: whatsapp, pushOptIn: push);
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<AppLocale>(
      context: context,
      backgroundColor: XpertColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(XpertRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: XpertSpacing.sm),
            for (final locale in AppLocale.values)
              ListTile(
                title: Text(locale.labelNative),
                subtitle: Text(locale.labelEn),
                onTap: () => Navigator.pop(ctx, locale),
              ),
            const SizedBox(height: XpertSpacing.sm),
          ],
        ),
      ),
    );
    if (selected == null) return;
    try {
      await ref.read(partnerAuthApiProvider).updateLanguage(selected.code);
      await ref.read(localeProvider.notifier).set(selected);
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).valueOrNull?.profile;
    final currentLocale = ref.watch(localeProvider);
    final localeLabel = currentLocale.labelNative;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.all(XpertSpacing.lg),
        children: [
          _Tile(
            icon: Icons.language_rounded,
            title: ref.t('settings.language'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(localeLabel, style: XpertTypography.caption),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: XpertColors.muted),
              ],
            ),
            onTap: _pickLanguage,
          ),
          const SizedBox(height: XpertSpacing.sm),
          _ToggleTile(
            icon: Icons.chat_rounded,
            title: ref.t('settings.whatsapp'),
            value: profile?.whatsappOptIn ?? true,
            enabled: !_savingPrefs,
            onChanged: (v) => _setPref(whatsapp: v),
          ),
          const SizedBox(height: XpertSpacing.sm),
          _ToggleTile(
            icon: Icons.notifications_rounded,
            title: ref.t('settings.notifications'),
            value: profile?.pushOptIn ?? true,
            enabled: !_savingPrefs,
            onChanged: (v) => _setPref(push: v),
          ),
          const SizedBox(height: XpertSpacing.xl),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              label: Text(ref.t('settings.signout')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XpertColors.surface,
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
              Expanded(child: Text(title, style: XpertTypography.label)),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XpertSpacing.md,
        vertical: XpertSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: XpertColors.muted),
          const SizedBox(width: XpertSpacing.md),
          Expanded(child: Text(title, style: XpertTypography.label)),
          Switch(
            value: value,
            activeThumbColor: XpertColors.primary,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
