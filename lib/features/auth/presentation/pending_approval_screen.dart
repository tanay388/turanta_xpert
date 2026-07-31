import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'auth_controller.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: XpertColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                  child: Text(ref.t('pending.sign_out')),
                ),
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: XpertColors.secondary,
                  borderRadius: BorderRadius.circular(XpertRadius.lg),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 40,
                  color: XpertColors.onSurface,
                ),
              ),
              const SizedBox(height: XpertSpacing.xl),
              Text(
                ref.t('pending.title'),
                textAlign: TextAlign.center,
                style: XpertTypography.title.copyWith(fontSize: 28),
              ),
              const SizedBox(height: XpertSpacing.md),
              Text(
                ref.t('pending.body'),
                textAlign: TextAlign.center,
                style: XpertTypography.body.copyWith(color: XpertColors.muted),
              ),
              const SizedBox(height: XpertSpacing.xl),
              OutlinedButton(
                onPressed: () => ref.read(authProvider.notifier).bootstrap(),
                child: Text(ref.t('pending.check')),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
