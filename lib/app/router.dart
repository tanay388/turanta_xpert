import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/update_required_screen.dart';
import '../core/network/app_version_gate.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_verification_screen.dart';
import '../features/address/presentation/address_screen.dart';
import '../features/auth/presentation/pending_approval_screen.dart';
import '../features/gender/presentation/gender_screen.dart';
import '../features/hub/presentation/hub_selection_screen.dart';
import '../features/home/presentation/attendance_history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/hub/presentation/hub_screen.dart';
import '../features/jobs/presentation/job_detail_screen.dart';
import '../features/jobs/presentation/jobs_screen.dart';
import '../features/kyc/presentation/kyc_wizard_screen.dart';
import '../features/language/presentation/language_selection_screen.dart';
import '../features/leave/presentation/leave_screen.dart';
import '../features/legal/presentation/pdf_viewer_screen.dart';
import '../features/legal/presentation/legal_consent_screen.dart';
import '../features/paisa/presentation/paisa_screen.dart';
import '../features/paisa/presentation/payout_detail_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/financial_details_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/referral/presentation/referral_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/target/presentation/target_screen.dart';
import 'shell/xpert_shell_scaffold.dart';
import 'splash_screen.dart';

class _Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const language = '/language';
  static const gender = '/gender';
  static const hubSelection = '/hub-selection';
  static const legalConsent = '/legal-consent';
  static const kyc = '/kyc';
  static const address = '/address';
  static const pending = '/pending-approval';
  static const home = '/home';
  static const leave = '/leave';
  static const attendance = '/attendance';
  static const jobs = '/jobs';
  static const paisa = '/paisa';
  static const target = '/target';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const profileFinancial = '/profile/financial';
  static const settings = '/settings';
  static const legalDocument = '/legal-document';
  static const hub = '/hub';
  static const referral = '/referral';

  static const Set<String> unauthenticated = {login, otp};

  /// Screens a partner is held on until they clear the gate behind them.
  static const Set<String> gateScreens = {
    language,
    gender,
    hubSelection,
    legalConsent,
    kyc,
    address,
    pending,
  };

  /// Reachable in either direction: the login screen's consent line opens it
  /// before there is a session, and Settings opens it after. It is kept out of
  /// [unauthenticated] deliberately — that set is also what forwards a
  /// *signed-in* partner to their post-auth destination, which would break the
  /// second case.
  static bool isSessionAgnostic(String loc) => loc == legalDocument;
}

/// What a signed-in partner still has to do before the app is theirs.
class PartnerGates {
  const PartnerGates({
    required this.needsLanguage,
    required this.needsGender,
    required this.needsHub,
    required this.needsLegalAcceptance,
    required this.needsKyc,
    required this.needsAddress,
    required this.isPendingApproval,
    required this.canUseHome,
  });

  PartnerGates.of(Session session)
    : needsLanguage = session.needsLanguage,
      needsGender = session.needsGender,
      needsHub = session.needsHub,
      needsLegalAcceptance = session.needsLegalAcceptance,
      needsKyc = session.needsKyc,
      needsAddress = session.needsAddress,
      isPendingApproval = session.isPendingApproval,
      canUseHome = session.canUseHome;

  final bool needsLanguage;
  final bool needsGender;
  final bool needsHub;
  final bool needsLegalAcceptance;
  final bool needsKyc;
  final bool needsAddress;
  final bool isPendingApproval;
  final bool canUseHome;
}

/// The one screen a partner belongs on: the first gate they have not cleared,
/// else home.
String partnerDestination(PartnerGates gates) {
  if (gates.needsLanguage) return _Routes.language;
  if (gates.needsGender) return _Routes.gender;
  if (gates.needsHub) return _Routes.hubSelection;
  if (gates.needsLegalAcceptance) return _Routes.legalConsent;
  if (gates.needsKyc) return _Routes.kyc;
  // Deliberately ahead of the pending gate: a partner waiting on approval is
  // exactly who needs to supply this, because their file cannot be approved
  // without it and the KYC itself is locked.
  if (gates.needsAddress) return _Routes.address;
  if (gates.isPendingApproval || !gates.canUseHome) return _Routes.pending;
  return _Routes.home;
}

/// Where to send a partner who is at [loc], or null to leave them there.
///
/// One ordered decision, not a rule per gate: as two sets of rules, a partner
/// who could use home but owed a consent was sent from home to the consent
/// screen by one and straight back by the other, until the router gave up.
String? partnerRedirect(PartnerGates gates, String loc) {
  final dest = partnerDestination(gates);
  if (dest != _Routes.home) return loc == dest ? null : dest;
  // Home it is — and the gates behind them are no longer theirs to sit on.
  return _Routes.gateScreens.contains(loc) ? _Routes.home : null;
}

/// A cross-fade with a breath of movement, for screens that share a backdrop.
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefresh(ref);

  return GoRouter(
    initialLocation: _Routes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(path: _Routes.splash, builder: (_, _) => const SplashScreen()),
      // Sign-in and the code step are one flow on one canvas, so they
      // cross-fade: a slide would throw the whole picture sideways to change
      // what is written on the card.
      GoRoute(
        path: _Routes.login,
        pageBuilder: (_, state) =>
            _fadeThrough(state, const LoginScreen()),
      ),
      GoRoute(
        path: _Routes.otp,
        pageBuilder: (_, state) =>
            _fadeThrough(state, const OtpVerificationScreen()),
      ),
      GoRoute(
        path: _Routes.language,
        builder: (_, _) => const LanguageSelectionScreen(),
      ),
      GoRoute(path: _Routes.gender, builder: (_, _) => const GenderScreen()),
      GoRoute(
        path: _Routes.hubSelection,
        builder: (_, _) => const HubSelectionScreen(),
      ),
      GoRoute(
        path: _Routes.legalConsent,
        builder: (_, _) => const LegalConsentScreen(),
      ),
      GoRoute(path: _Routes.kyc, builder: (_, _) => const KycWizardScreen()),
      GoRoute(path: _Routes.address, builder: (_, _) => const AddressScreen()),
      GoRoute(
        path: _Routes.pending,
        builder: (_, _) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/update-required',
        builder: (_, _) => const UpdateRequiredScreen(),
      ),
      // Persistent 5-tab bottom-nav shell for active partners.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            XpertShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _Routes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _Routes.jobs,
                builder: (_, _) => const JobsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _Routes.leave,
                builder: (_, _) => const LeaveScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _Routes.paisa,
                builder: (_, _) => const PaisaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _Routes.target,
                builder: (_, _) => const TargetScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes pushed over the shell (own back button, no bottom bar).
      GoRoute(
        path: '${_Routes.jobs}/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return JobDetailScreen(jobId: id);
        },
      ),
      GoRoute(
        path: '${_Routes.paisa}/cycles/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return PayoutDetailScreen(cycleId: id);
        },
      ),
      GoRoute(
        path: _Routes.attendance,
        builder: (_, _) => const AttendanceHistoryScreen(),
      ),
      GoRoute(path: _Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: _Routes.profileEdit,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: _Routes.profileFinancial,
        builder: (_, _) => const FinancialDetailsScreen(),
      ),
      GoRoute(
        path: _Routes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: _Routes.legalDocument,
        builder: (_, state) {
          final extra = state.extra as (String title, String url);
          return PdfViewerScreen(title: extra.$1, url: extra.$2);
        },
      ),
      GoRoute(path: _Routes.hub, builder: (_, _) => const HubScreen()),
      GoRoute(
        path: _Routes.referral,
        builder: (_, _) => const ReferralScreen(),
      ),
    ],
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final auth = ref.read(authProvider);

      // Force-update gate wins over everything.
      if (loc == '/update-required') return null;
      if (ref.read(appVersionGateProvider).valueOrNull?.supported == false) {
        return '/update-required';
      }

      // Checked before any auth branch: a partner reading the terms should not
      // be pulled elsewhere because their session happened to resolve while
      // the PDF was open.
      if (_Routes.isSessionAgnostic(loc)) return null;

      if (auth.isLoading && loc == _Routes.splash) return null;
      if (auth.hasError && loc == _Routes.splash) return null;

      final session = auth.valueOrNull;
      final signedIn = session != null;

      if (loc == _Routes.splash) return null;

      if (!signedIn && !_Routes.unauthenticated.contains(loc)) {
        return _Routes.login;
      }

      if (!signedIn) return null;

      final gates = PartnerGates.of(session);
      if (_Routes.unauthenticated.contains(loc)) {
        return partnerDestination(gates);
      }
      return partnerRedirect(gates, loc);
    },
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authProvider, (_, _) => notifyListeners());
    _ref.listen(appVersionGateProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
