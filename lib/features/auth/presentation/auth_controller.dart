import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/i18n/locale_provider.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/notifications/push_providers.dart';
import '../data/partner_auth_api.dart';

/// Set when the user enters a friend's code on the login screen; consumed
/// once by [AuthController._resolve] on the next profile bootstrap (the
/// backend only applies it for a brand-new partner signup) and cleared
/// after.
final pendingReferralCodeProvider = StateProvider<String?>((ref) => null);

/// Why a signed-in Firebase identity was rejected by the backend — a customer
/// number used on Xpert, or an account bound to another handset. The session is
/// torn down immediately in both cases, so this is the only surviving trace;
/// the login screen shows it once and clears it.
final authRejectionProvider = StateProvider<String?>((ref) => null);

class Session {
  const Session({required this.firebaseUser, this.profile});

  final fb.User firebaseUser;
  final PartnerUser? profile;

  String get phone => firebaseUser.phoneNumber ?? profile?.phone ?? '';
  String get uid => firebaseUser.uid;

  bool get needsLanguage => profile?.needsLanguage ?? true;
  bool get needsKyc => profile?.needsKyc ?? true;
  bool get isPendingApproval =>
      profile?.isPendingApproval == true && (profile?.kycComplete ?? false);
  bool get canUseHome =>
      profile?.isActive == true && profile?.kycComplete == true;

  Session copyWith({PartnerUser? profile}) {
    return Session(
      firebaseUser: firebaseUser,
      profile: profile ?? this.profile,
    );
  }
}

class AuthController extends AsyncNotifier<Session?> {
  StreamSubscription<fb.User?>? _sub;
  bool _ignoreNext = true;

  @override
  Future<Session?> build() async {
    ref.onDispose(() => _sub?.cancel());

    // Warm up FCM listeners early; token sync happens after auth.
    unawaited(ref.read(pushNotificationServiceProvider).init());

    final auth = fb.FirebaseAuth.instance;
    _ignoreNext = true;
    _sub = auth.authStateChanges().listen((user) async {
      if (_ignoreNext) {
        _ignoreNext = false;
        return;
      }
      if (user == null) {
        state = const AsyncData(null);
        return;
      }
      state = const AsyncLoading();
      try {
        state = AsyncData(await _resolve(user));
      } catch (e, st) {
        state = AsyncError(e, st);
      }
    });

    final current = auth.currentUser;
    if (current == null) return null;
    return _resolve(current);
  }

  Future<void> bootstrap() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading<Session?>().copyWithPrevious(state);
    try {
      state = AsyncData(await _resolve(user));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<Session?> _resolve(fb.User user) async {
    final api = ref.read(partnerAuthApiProvider);
    try {
      final referralCode = ref.read(pendingReferralCodeProvider);
      final profile = await api.getMe(referralCode: referralCode);
      // One-shot: only meant for this signup's first bootstrap call.
      if (referralCode != null) {
        ref.read(pendingReferralCodeProvider.notifier).state = null;
      }
      await ref
          .read(localeProvider.notifier)
          .syncFromProfile(profile.language);
      unawaited(_syncPushToken());
      return Session(firebaseUser: user, profile: profile);
    } on ApiException catch (e) {
      // Neither is recoverable by retrying, and both used to strand the user on
      // a screen with no way back to login. Drop the session instead.
      if (e.code == 'ROLE_CONFLICT' || e.code == 'DEVICE_MISMATCH') {
        ref.read(authRejectionProvider.notifier).state = e.message;
        await fb.FirebaseAuth.instance.signOut();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _syncPushToken() async {
    try {
      final push = ref.read(pushNotificationServiceProvider);
      await push.init();
      await push.syncTokenWithBackend();
    } catch (_) {
      // Push registration must never block auth.
    }
  }

  Future<void> refreshProfile() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final profile = await ref.read(partnerAuthApiProvider).getMe();
    await ref.read(localeProvider.notifier).syncFromProfile(profile.language);
    state = AsyncData(current.copyWith(profile: profile));
  }

  Future<void> signOut() async {
    await fb.FirebaseAuth.instance.signOut();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
