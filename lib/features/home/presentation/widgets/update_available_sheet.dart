import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/store_links.dart';
import '../../../../core/i18n/context_t.dart';
import '../../../../core/network/app_version_gate.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// Offers an update the partner can decline.
///
/// The sibling of [UpdateRequiredScreen], and deliberately nothing like it:
/// that one blocks because the build is no longer supported, this one only
/// asks. Declining is a real answer, so it dismisses cleanly and stays gone
/// for three days rather than reappearing on the next launch.
Future<void> showUpdateAvailableSheet(
  BuildContext context,
  WidgetRef ref,
  int latestBuild,
) async {
  final update = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: XpertColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(XpertRadius.lg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(XpertSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.system_update, size: 44, color: XpertColors.primary),
            const SizedBox(height: XpertSpacing.md),
            Text(
              ref.t('update.available.title'),
              textAlign: TextAlign.center,
              style: XpertTypography.title.copyWith(fontSize: 19),
            ),
            const SizedBox(height: XpertSpacing.sm),
            Text(
              ref.t('update.available.body'),
              textAlign: TextAlign.center,
              style: XpertTypography.body.copyWith(
                color: XpertColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: XpertSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: Text(ref.t('update.available.cta')),
            ),
            const SizedBox(height: XpertSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text(ref.t('update.available.later')),
            ),
          ],
        ),
      ),
    ),
  );

  // Snooze on decline and on a dismissing tap outside alike — both mean "not
  // now", and only actually leaving for the store should skip the snooze.
  if (update != true) {
    await snoozeUpdateOffer(latestBuild);
    return;
  }

  final url = StoreLinks.forThisPlatform;
  if (url == null) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
