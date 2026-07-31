import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';

/// View + edit the partner's financial details (bank, PAN, GST, UAN).
/// Editable even after KYC approval via `PATCH /partner/kyc/financial`.
class FinancialDetailsScreen extends ConsumerStatefulWidget {
  const FinancialDetailsScreen({super.key});

  @override
  ConsumerState<FinancialDetailsScreen> createState() =>
      _FinancialDetailsScreenState();
}

class _FinancialDetailsScreenState
    extends ConsumerState<FinancialDetailsScreen> {
  PartnerKyc? _kyc;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String? _error;

  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final _bankName = TextEditingController();
  final _holder = TextEditingController();
  final _pan = TextEditingController();
  final _gst = TextEditingController();
  final _uan = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _account.dispose();
    _ifsc.dispose();
    _bankName.dispose();
    _holder.dispose();
    _pan.dispose();
    _gst.dispose();
    _uan.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kyc = await ref.read(partnerAuthApiProvider).getKyc();
      _kyc = kyc;
      _resetControllers();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetControllers() {
    final k = _kyc;
    _account.text = '';
    _pan.text = '';
    _ifsc.text = k?.bankIfsc ?? '';
    _bankName.text = k?.bankName ?? '';
    _holder.text = k?.accountHolderName ?? '';
    _gst.text = k?.gstNumber ?? '';
    _uan.text = k?.uanNumber ?? '';
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'bankIfsc': _ifsc.text.trim(),
        'bankName': _bankName.text.trim(),
        'accountHolderName': _holder.text.trim(),
        'gstNumber': _gst.text.trim(),
        'uanNumber': _uan.text.trim(),
      };
      // Account number + PAN are masked; only overwrite when re-entered.
      if (_account.text.trim().isNotEmpty) {
        body['bankAccountNumber'] = _account.text.trim();
      }
      if (_pan.text.trim().isNotEmpty) {
        body['panNumber'] = _pan.text.trim();
      }
      final updated =
          await ref.read(partnerAuthApiProvider).updateFinancial(body);
      _kyc = updated;
      _resetControllers();
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.t('financial.saved'))),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        title: Text(ref.t('financial.title')),
        actions: [
          if (!_loading && !_editing)
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: Text(ref.t('financial.edit')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _editing
              ? _buildEdit()
              : _buildView(),
    );
  }

  Widget _buildView() {
    final k = _kyc;
    return ListView(
      padding: const EdgeInsets.all(XpertSpacing.lg),
      children: [
        Text(ref.t('financial.bank'), style: XpertTypography.label),
        const SizedBox(height: XpertSpacing.sm),
        _row(ref.t('financial.holder'), k?.accountHolderName),
        _row(ref.t('financial.bank_name'), k?.bankName),
        _row(ref.t('financial.account_no'), k?.bankAccountNumberMasked),
        _row(ref.t('financial.ifsc'), k?.bankIfsc),
        const SizedBox(height: XpertSpacing.lg),
        Text(ref.t('financial.identity'), style: XpertTypography.label),
        const SizedBox(height: XpertSpacing.sm),
        _row(ref.t('financial.pan'), k?.panNumberMasked),
        _row(ref.t('financial.aadhaar'), k?.aadhaarNumberMasked),
        _row(ref.t('financial.gst'), k?.gstNumber),
        _row(ref.t('financial.uan'), k?.uanNumber),
        if (_error != null) ...[
          const SizedBox(height: XpertSpacing.md),
          Text(
            _error!,
            style: XpertTypography.caption.copyWith(color: XpertColors.danger),
          ),
        ],
      ],
    );
  }

  Widget _buildEdit() {
    final k = _kyc;
    return ListView(
      padding: const EdgeInsets.all(XpertSpacing.lg),
      children: [
        Text(ref.t('financial.bank'), style: XpertTypography.label),
        const SizedBox(height: XpertSpacing.sm),
        _field(_holder, ref.t('financial.holder')),
        _field(_bankName, ref.t('financial.bank_name')),
        _field(
          _account,
          ref.t('financial.account_no'),
          hint: k?.bankAccountNumberMasked,
          keyboardType: TextInputType.number,
        ),
        _field(
          _ifsc,
          ref.t('financial.ifsc'),
          capitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: XpertSpacing.lg),
        Text(ref.t('financial.identity'), style: XpertTypography.label),
        const SizedBox(height: XpertSpacing.sm),
        _field(
          _pan,
          ref.t('financial.pan'),
          hint: k?.panNumberMasked,
          capitalization: TextCapitalization.characters,
        ),
        _field(_gst, ref.t('financial.gst'),
            capitalization: TextCapitalization.characters),
        _field(_uan, ref.t('financial.uan'),
            keyboardType: TextInputType.number),
        if (_error != null) ...[
          const SizedBox(height: XpertSpacing.sm),
          Text(
            _error!,
            style: XpertTypography.caption.copyWith(color: XpertColors.danger),
          ),
        ],
        const SizedBox(height: XpertSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () {
                        _resetControllers();
                        setState(() {
                          _editing = false;
                          _error = null;
                        });
                      },
                child: Text(ref.t('common.cancel')),
              ),
            ),
            const SizedBox(width: XpertSpacing.sm),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: XpertColors.primary,
                  foregroundColor: XpertColors.onPrimary,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ref.t('financial.save')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String label, String? value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: XpertSpacing.sm),
      padding: const EdgeInsets.all(XpertSpacing.md),
      decoration: BoxDecoration(
        color: XpertColors.surface,
        borderRadius: BorderRadius.circular(XpertRadius.md),
        border: Border.all(color: XpertColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: XpertTypography.caption),
          const SizedBox(height: 4),
          Text(
            (value == null || value.isEmpty) ? '—' : value,
            style: XpertTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XpertSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}
