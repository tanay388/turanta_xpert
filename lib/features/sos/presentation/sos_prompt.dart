import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import 'sos_controller.dart';

/// The confirm step in front of an SOS.
///
/// It stays because a bare tap in a pocket would call the ops desk, and a
/// false alarm is what teaches everyone to ignore the next one. Past the
/// confirm nothing more is asked of the helper — the controller retries on its
/// own and the card on Home reports what happened.
Future<void> showSosPrompt(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.sos_rounded, color: XpertColors.danger),
      title: Text(ref.t('home.emergency')),
      content: Text(ref.t('home.emergency_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ref.t('home.emergency_cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: XpertColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ref.t('home.emergency_confirm')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  unawaited(ref.read(sosProvider.notifier).raise());
}
