import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/store_links.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';

/// Blocking force-update screen — shown when the backend says this build is
/// below the admin-configured minimum. No way back except updating.
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openStore() async {
    final url = StoreLinks.forThisPlatform;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: XpertColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(XpertSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(Icons.system_update, size: 64, color: XpertColors.primary),
                const SizedBox(height: XpertSpacing.lg),
                Text(
                  ref.t('update.title'),
                  textAlign: TextAlign.center,
                  style: XpertTypography.title,
                ),
                const SizedBox(height: XpertSpacing.md),
                Text(
                  ref.t('update.body'),
                  textAlign: TextAlign.center,
                  style: XpertTypography.body.copyWith(
                    color: XpertColors.muted,
                  ),
                ),
                const Spacer(),
                // Xpert is not on the App Store, so an iPhone has nowhere to
                // be sent. A button that does nothing is worse than none.
                if (StoreLinks.forThisPlatform != null)
                  FilledButton(
                    onPressed: _openStore,
                    child: Text(ref.t('update.cta')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
