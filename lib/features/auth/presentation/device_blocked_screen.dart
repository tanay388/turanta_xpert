import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'auth_controller.dart';

class DeviceBlockedScreen extends ConsumerWidget {
  const DeviceBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final message = session?.deviceMismatchMessage ?? ref.t('device.body');

    return Scaffold(
      backgroundColor: XpertColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.phonelink_lock,
                size: 64,
                color: XpertColors.danger.withValues(alpha: 0.85),
              ),
              const SizedBox(height: XpertSpacing.lg),
              Text(
                ref.t('device.title'),
                textAlign: TextAlign.center,
                style: XpertTypography.title,
              ),
              const SizedBox(height: XpertSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: XpertTypography.body.copyWith(color: XpertColors.muted),
              ),
              const SizedBox(height: XpertSpacing.sm),
              Text(
                ref.t('device.support'),
                textAlign: TextAlign.center,
                style: XpertTypography.caption,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                child: Text(ref.t('device.sign_out')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
