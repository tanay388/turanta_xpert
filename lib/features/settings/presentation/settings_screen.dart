import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/shell/xpert_list_group.dart';
import '../../../app/shell/xpert_sections.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../legal/data/legal_document_api.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Settings: language, alert preferences, legal documents, sign out.
///
/// Everything used to be one flat run of tiles at identical weight, with a
/// bare caption for the legal heading and the two toggles unexplained. It is
/// now grouped by what the settings are for, and sign out asks before it acts.
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _pickLanguage() async {
    final current = ref.read(localeProvider);
    final selected = await showModalBottomSheet<AppLocale>(
      context: context,
      backgroundColor: XpertColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(XpertRadius.sheetTop),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: XpertSpacing.md),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: XpertColors.border,
                  borderRadius: BorderRadius.circular(XpertRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: XpertSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: XpertSpacing.lg),
              child: Text(
                ref.t('settings.language'),
                style: XpertTypography.title.copyWith(fontSize: 18),
              ),
            ),
            const SizedBox(height: XpertSpacing.sm),
            for (final locale in AppLocale.values)
              ListTile(
                title: Text(
                  locale.labelNative,
                  style: XpertTypography.label.copyWith(
                    fontWeight: locale == current
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  locale.labelEn,
                  style: XpertTypography.caption.copyWith(fontSize: 12),
                ),
                // Which one is on was previously not shown at all.
                trailing: locale == current
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: XpertColors.primary,
                      )
                    : null,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmSignOut() async {
    // Signing out was a single unguarded tap, on this screen and on Profile.
    // It ends the session and sends the partner back to an OTP.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.t('settings.signout.confirm.title')),
        content: Text(ref.t('settings.signout.confirm.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('leave.no')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: XpertColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('settings.signout')),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).valueOrNull?.profile;
    final localeLabel = ref.watch(localeProvider).labelNative;
    final legalDocuments = ref.watch(legalDocumentsProvider);
    final version = ref.watch(_appVersionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          XpertSpacing.lg,
          XpertSpacing.md,
          XpertSpacing.lg,
          XpertSpacing.xl,
        ),
        children: [
          SectionLabel(ref.t('settings.section.preferences')),
          const SizedBox(height: XpertSpacing.sm),
          XpertListGroup(
            children: [
              XpertListRow(
                icon: Icons.language_rounded,
                title: ref.t('settings.language'),
                value: localeLabel,
                onTap: _pickLanguage,
              ),
              // Both toggles now say what they actually control.
              XpertListRow(
                icon: Icons.chat_rounded,
                title: ref.t('settings.whatsapp'),
                subtitle: ref.t('settings.whatsapp.hint'),
                trailing: Switch(
                  value: profile?.whatsappOptIn ?? true,
                  activeThumbColor: XpertColors.primary,
                  onChanged: _savingPrefs
                      ? null
                      : (v) => _setPref(whatsapp: v),
                ),
              ),
              XpertListRow(
                icon: Icons.notifications_rounded,
                title: ref.t('settings.notifications'),
                subtitle: ref.t('settings.notifications.hint'),
                trailing: Switch(
                  value: profile?.pushOptIn ?? true,
                  activeThumbColor: XpertColors.primary,
                  onChanged: _savingPrefs ? null : (v) => _setPref(push: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.xl),
          SectionLabel(ref.t('settings.legal.title')),
          const SizedBox(height: XpertSpacing.sm),
          legalDocuments.when(
            data: (docs) => docs.isEmpty
                ? const SizedBox.shrink()
                : XpertListGroup(
                    children: [
                      for (final doc in docs)
                        XpertListRow(
                          icon: Icons.description_outlined,
                          title: doc.name,
                          onTap: () => context.push(
                            '/legal-document',
                            extra: (doc.name, doc.pdfUrl),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: XpertSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Text(
              ref.t('settings.legal.error'),
              style: XpertTypography.caption,
            ),
          ),
          const SizedBox(height: XpertSpacing.xl),
          SectionLabel(ref.t('settings.section.account')),
          const SizedBox(height: XpertSpacing.sm),
          XpertListGroup(
            children: [
              XpertListRow(
                icon: Icons.logout_rounded,
                title: ref.t('settings.signout'),
                tone: XpertColors.danger,
                trailing: const SizedBox.shrink(),
                onTap: _confirmSignOut,
              ),
            ],
          ),
          const SizedBox(height: XpertSpacing.lg),
          // Worth having when a partner is on the phone to support about a bug.
          if (version != null)
            Text(
              ref.t('settings.version', {'version': version}),
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(fontSize: 11.5),
            ),
        ],
      ),
    );
  }
}
