import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

/// Asks why a partner is leaving before their shift ends. Moved out of
/// home_screen.dart unchanged.
class EarlyCheckoutSheet extends ConsumerStatefulWidget {
  const EarlyCheckoutSheet({super.key});

  @override
  ConsumerState<EarlyCheckoutSheet> createState() =>
      _EarlyCheckoutSheetState();
}

class _EarlyCheckoutSheetState extends ConsumerState<EarlyCheckoutSheet> {
  String _code = 'PERSONAL_EMERGENCY';
  final _text = TextEditingController();

  static const _reasonCodes = [
    'MEDICAL',
    'FAMILY_EMERGENCY',
    'FEELING_UNWELL',
    'PERSONAL_EMERGENCY',
    'OTHER',
  ];

  String _reasonLabel(String code) =>
      ref.t('home.checkout_reason.${code.toLowerCase()}');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: XpertSpacing.lg,
        right: XpertSpacing.lg,
        top: XpertSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + XpertSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ref.t('home.checkout_reason.title'),
            style: XpertTypography.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: XpertSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _code,
            items: _reasonCodes
                .map((code) => DropdownMenuItem(
                      value: code,
                      child: Text(_reasonLabel(code)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _code = v ?? _code),
          ),
          if (_code == 'OTHER') ...[
            const SizedBox(height: XpertSpacing.sm),
            TextField(
              controller: _text,
              decoration: InputDecoration(
                hintText: ref.t('home.checkout_reason.other_hint'),
              ),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: XpertSpacing.lg),
          FilledButton(
            onPressed: () {
              if (_code == 'OTHER' && _text.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'code': _code,
                'text': _text.text.trim(),
              });
            },
            child: Text(ref.t('home.checkout_reason.confirm_cta')),
          ),
        ],
      ),
    );
  }
}
