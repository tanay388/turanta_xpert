import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/i18n/context_t.dart';
import '../core/theme/xpert_tokens.dart';
import '../features/auth/presentation/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _error;

  // The backend bootstrap call failed, so there is no [Session]/profile to
  // read a phone from — this falls back to the raw Firebase identity so a
  // partner stuck on a role conflict can see which number is signed in.
  String? get _signedInPhone => fb.FirebaseAuth.instance.currentUser?.phoneNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _boot() async {
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).bootstrap();
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.hasError) {
        setState(() => _error = auth.error.toString());
        return;
      }
      final session = auth.valueOrNull;
      if (session == null) {
        context.go('/login');
        return;
      }
      context.go(_destinationFor(session));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  String _destinationFor(Session session) {
    if (session.needsLanguage) return '/language';
    if (session.needsKyc) return '/kyc';
    if (session.isPendingApproval || !session.canUseHome) {
      return '/pending-approval';
    }
    return '/home';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Matches the native splash + logo canvas so the handoff from the
      // OS launch screen into Flutter is seamless.
      backgroundColor: const Color(0xFFF8F8F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(XpertSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(XpertRadius.lg + 8),
                      child: Image.asset(
                        'assets/logo/turanta_xpert_app_logo.png',
                        width: 128,
                        height: 128,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: XpertSpacing.lg),
                    Text(
                      'Turanta Xpert',
                      style: XpertTypography.title.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: XpertSpacing.xs),
                    Text(
                      ref.t('splash.tagline'),
                      style: XpertTypography.caption
                          .copyWith(color: XpertColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XpertSpacing.xl),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: XpertTypography.caption.copyWith(
                    color: XpertColors.danger,
                  ),
                ),
                if (_signedInPhone != null) ...[
                  const SizedBox(height: XpertSpacing.xs),
                  Text(
                    ref.t('splash.signed_in_as', {'phone': _signedInPhone!}),
                    textAlign: TextAlign.center,
                    style: XpertTypography.caption
                        .copyWith(color: XpertColors.muted),
                  ),
                ],
                const SizedBox(height: XpertSpacing.md),
                FilledButton(
                  onPressed: _boot,
                  child: Text(ref.t('splash.retry')),
                ),
                const SizedBox(height: XpertSpacing.sm),
                OutlinedButton(
                  onPressed: _signOut,
                  child: Text(ref.t('splash.sign_out')),
                ),
              ] else
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
