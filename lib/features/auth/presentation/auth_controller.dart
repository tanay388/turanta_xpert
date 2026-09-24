import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/auth/session_reset.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/notifications/push_providers.dart';
import '../data/partner_auth_api.dart';

/// Set when the user enters a friend's code on the login screen; consumed
/// once by [AuthController._resolve] on the next profile bootstrap (the
/// backend only applies it for a brand-new partner signup) and cleared
/// after.
final pendingReferralCodeProvider = StateProvider<String?>((ref) => null);

/// Set once the backend has ruled on a referral code, so the first screen the
/// partner lands on can confirm it worked — silence is what made the old flow
/// feel broken. Cleared by whoever shows it.
final referralNoticeProvider = StateProvider<PartnerUser?>((ref) => null);

/// i18n key for why the backend turned a signed-in number away — a customer
/// number used on Xpert, or an account bound to another handset. The session
/// is torn down at once, so the fresh scope is seeded with it (see
/// `SessionEpoch`) and the login screen shows it once, then clears it.
final authRejectionProvider = StateProvider<String?>((ref) => null);

const _rejectionKeys = {
  'ROLE_CONFLICT': 'login.rejected.role',
  'DEVICE_MISMATCH': 'login.rejected.device',
};

class Session {
  const Session({required this.userId, required this.phone, this.profile});

  final String userId;
  final String phone;
  final PartnerUser? profile;

  bool get needsLanguage => profile?.needsLanguage ?? true;
  bool get needsKyc => profile?.needsKyc ?? true;

  /// Asked of everyone, including partners who onboarded before the question
  /// existed. Defaults false so an unloaded profile does not pin them here.
  bool get needsGender {
    final profile = this.profile;
    return profile != null && (profile.gender ?? '').isEmpty;
  }

  /// Which hub a partner works out of, asked right after gender. Partners who
  /// were assigned one by an admin never see it; those who joined before the
  /// question existed are all inactive, so nobody at work is interrupted.
  bool get needsHub {
    final profile = this.profile;
    return profile != null && profile.warehouseId == null;
  }

  /// Defaults false: a partner whose profile has not loaded should not be
  /// pinned to the consent gate by a missing field.
  bool get needsLegalAcceptance => profile?.needsLegalAcceptance ?? false;

  /// Asked of everyone without an address on file, whatever their KYC status —
  /// including a partner waiting on approval, since the address is now the one
  /// thing standing between them and it.
  bool get needsAddress => profile?.needsAddress ?? false;
  bool get isPendingApproval =>
      profile?.isPendingApproval == true && (profile?.kycComplete ?? false);
  bool get canUseHome =>
      profile?.isActive == true && profile?.kycComplete == true;

  Session copyWith({PartnerUser? profile}) {
    return Session(
      userId: userId,
      phone: phone,
      profile: profile ?? this.profile,
    );
  }
}

class AuthController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => _resolve();

  Future<void> bootstrap() async {
    state = const AsyncLoading<Session?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_resolve);
  }

  Future<Session?> _resolve() async {
    final tokens = await TokenStore.instance.read();
    if (tokens == null) return null;
    final api = ref.read(partnerAuthApiProvider);
    try {
      final referralCode = ref.read(pendingReferralCodeProvider);
      final profile = await api.getMe(referralCode: referralCode);
      // One-shot: only meant for this signup's first bootstrap call.
      if (referralCode != null) {
        ref.read(pendingReferralCodeProvider.notifier).state = null;
        if (profile.referralApplied != null) {
          ref.read(referralNoticeProvider.notifier).state = profile;
        }
      }
      await ref.read(localeProvider.notifier).syncFromProfile(profile.language);
      unawaited(_syncPushToken());
      return Session(
        userId: tokens.userId,
        phone: tokens.phone,
        profile: profile,
      );
    } on ApiException catch (e) {
      // Neither is recoverable by retrying, and both used to strand the user on
      // a screen with no way back to login. Drop the session instead.
      final rejection = _rejectionKeys[e.code];
      if (rejection != null) {
        await ref.read(partnerAuthApiProvider).logout().catchError((_) {});
        await endSession(reason: rejection);
        return null;
      }
      if (e.statusCode == 401) {
        await endSession();
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

  /// Ends the session on the server when it can, then wipes everything the
  /// partner left behind on the device.
  Future<void> signOut() async {
    try {
      await ref.read(partnerAuthApiProvider).logout();
    } catch (_) {
      // Signing out must work offline; the session expires server-side.
    }
    await endSession();
  }
}

final authProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
