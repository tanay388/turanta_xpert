import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/shell/xpert_list_group.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart' show ApiException;
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../data/legal_document_api.dart';

/// Onboarding gate: every active legal document must be opened before a partner
/// can upload anything.
///
/// Continue stays disabled until each document has been opened once, so consent
/// is recorded against a document the partner was at least shown, rather than a
/// checkbox they ticked past. Documents whose current version was already
/// accepted count as read, so replacing one PDF does not force a re-read of the
/// rest.
class LegalConsentScreen extends ConsumerStatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  ConsumerState<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends ConsumerState<LegalConsentScreen> {
  final Set<int> _opened = {};
  bool _seeded = false;
  bool _busy = false;
  String? _error;

  void _seed(List<RequiredLegalDocument> docs) {
    if (_seeded) return;
    _seeded = true;
    _opened.addAll(docs.where((d) => d.accepted).map((d) => d.id));
  }

  Future<void> _open(RequiredLegalDocument doc) async {
    await context.push('/legal-document', extra: (doc.name, doc.pdfUrl));
    if (!mounted) return;
    setState(() => _opened.add(doc.id));
  }

  Future<void> _accept(List<RequiredLegalDocument> docs) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(legalDocumentApiProvider)
          .accept(docs.map((d) => d.id).toList());
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;

      final session = ref.read(authProvider).valueOrNull;
      if (session == null) {
        context.go('/login');
      } else if (session.needsKyc) {
        context.go('/kyc');
      } else if (session.isPendingApproval || !session.canUseHome) {
        context.go('/pending-approval');
      } else {
        context.go('/home');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = ref.t('legal.consent.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requiredLegalDocumentsProvider);

    return Scaffold(
      backgroundColor: XpertColors.background,
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Retry(
            message: ref.t('legal.consent.load_error'),
            label: ref.t('splash.retry'),
            onRetry: () => ref.invalidate(requiredLegalDocumentsProvider),
          ),
          data: (status) {
            _seed(status.documents);
            final docs = status.documents;
            final allOpened =
                docs.isNotEmpty && docs.every((d) => _opened.contains(d.id));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    XpertSpacing.lg,
                    XpertSpacing.xl,
                    XpertSpacing.lg,
                    XpertSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: XpertColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(XpertRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.gavel_rounded,
                          size: 22,
                          color: XpertColors.primary,
                        ),
                      ),
                      const SizedBox(height: XpertSpacing.md),
                      Text(
                        ref.t('legal.consent.title'),
                        style: XpertTypography.title.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: XpertSpacing.xs),
                      Text(
                        ref.t('legal.consent.subtitle'),
                        style: XpertTypography.caption.copyWith(
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: XpertSpacing.lg,
                    ),
                    children: [
                      XpertListGroup(
                        children: [
                          for (final doc in docs)
                            _DocumentRow(
                              name: doc.name,
                              read: _opened.contains(doc.id),
                              enabled: !_busy,
                              readLabel: ref.t('legal.consent.read'),
                              unreadLabel: ref.t('legal.consent.tap_to_read'),
                              onTap: () => _open(doc),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(XpertSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: XpertTypography.caption.copyWith(
                            color: XpertColors.danger,
                          ),
                        ),
                        const SizedBox(height: XpertSpacing.sm),
                      ],
                      if (!allOpened)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: XpertSpacing.sm,
                          ),
                          child: Text(
                            ref.t('legal.consent.hint'),
                            textAlign: TextAlign.center,
                            style: XpertTypography.caption.copyWith(
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      AuthPrimaryButton(
                        label: ref.t('legal.consent.cta'),
                        isLoading: _busy,
                        onPressed:
                            allOpened && !_busy ? () => _accept(docs) : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.name,
    required this.read,
    required this.enabled,
    required this.readLabel,
    required this.unreadLabel,
    required this.onTap,
  });

  final String name;
  final bool read;
  final bool enabled;
  final String readLabel;
  final String unreadLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: XpertSpacing.md,
          vertical: XpertSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              read ? Icons.check_circle_rounded : Icons.description_outlined,
              size: 22,
              color: read ? XpertColors.success : XpertColors.muted,
            ),
            const SizedBox(width: XpertSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: XpertTypography.body.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    read ? readLabel : unreadLabel,
                    style: XpertTypography.caption.copyWith(
                      fontSize: 12,
                      color: read ? XpertColors.success : XpertColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: XpertColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({
    required this.message,
    required this.label,
    required this.onRetry,
  });

  final String message;
  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(XpertSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(
                color: XpertColors.danger,
              ),
            ),
            const SizedBox(height: XpertSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(label)),
          ],
        ),
      ),
    );
  }
}
