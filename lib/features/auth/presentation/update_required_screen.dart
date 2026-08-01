import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.turanta.turanta_xpert';
// TODO: replace with the real App Store link once the iOS app is published.
const _appStoreUrl = 'https://apps.apple.com/app/id0000000000';

/// Blocking force-update screen — shown when the backend says this build is
/// below the admin-configured minimum. No way back except updating.
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openStore() async {
    final url = (!kIsWeb && Platform.isIOS) ? _appStoreUrl : _playStoreUrl;
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
                Icon(
                  Icons.system_update,
                  size: 64,
                  color: XpertColors.primary,
                ),
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
                  style:
                      XpertTypography.body.copyWith(color: XpertColors.muted),
                ),
                const Spacer(),
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
