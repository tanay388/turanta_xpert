import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/device_blocked_screen.dart';
import '../features/auth/presentation/update_required_screen.dart';
import '../core/network/app_version_gate.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_verification_screen.dart';
import '../features/auth/presentation/pending_approval_screen.dart';
import '../features/home/presentation/attendance_history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/hub/presentation/hub_screen.dart';
import '../features/jobs/presentation/job_detail_screen.dart';
import '../features/jobs/presentation/jobs_screen.dart';
import '../features/kyc/presentation/kyc_wizard_screen.dart';
import '../features/language/presentation/language_selection_screen.dart';
import '../features/leave/presentation/leave_screen.dart';
import '../features/legal/presentation/pdf_viewer_screen.dart';
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
  static const kyc = '/kyc';
  static const pending = '/pending-approval';
  static const deviceBlocked = '/device-blocked';
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

  /// Reachable in either direction: the login screen's consent line opens it
  /// before there is a session, and Settings opens it after. It is kept out of
  /// [unauthenticated] deliberately — that set is also what forwards a
  /// *signed-in* partner to their post-auth destination, which would break the
  /// second case.
  static bool isSessionAgnostic(String loc) => loc == legalDocument;
}

String? _postAuthDestination(Session session) {
  if (session.deviceMismatch) return _Routes.deviceBlocked;
  if (session.needsLanguage) return _Routes.language;
  if (session.needsKyc) return _Routes.kyc;
  if (session.isPendingApproval || !session.canUseHome) return _Routes.pending;
  return _Routes.home;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefresh(ref);

  return GoRouter(
    initialLocation: _Routes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(path: _Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: _Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: _Routes.otp,
        builder: (_, _) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: _Routes.language,
        builder: (_, _) => const LanguageSelectionScreen(),
      ),
      GoRoute(path: _Routes.kyc, builder: (_, _) => const KycWizardScreen()),
      GoRoute(
        path: _Routes.pending,
        builder: (_, _) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: _Routes.deviceBlocked,
        builder: (_, _) => const DeviceBlockedScreen(),
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
      GoRoute(
        path: _Routes.hub,
        builder: (_, _) => const HubScreen(),
      ),
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
      if (ref.read(appVersionGateProvider).valueOrNull == false) {
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

      final dest = _postAuthDestination(session);

      if (_Routes.unauthenticated.contains(loc)) {
        return dest;
      }

      if (session.deviceMismatch && loc != _Routes.deviceBlocked) {
        return _Routes.deviceBlocked;
      }

      if (!session.deviceMismatch &&
          session.needsLanguage &&
          loc != _Routes.language) {
        return _Routes.language;
      }

      if (!session.deviceMismatch &&
          !session.needsLanguage &&
          session.needsKyc &&
          loc != _Routes.kyc) {
        return _Routes.kyc;
      }

      if (!session.deviceMismatch &&
          !session.needsLanguage &&
          !session.needsKyc &&
          !session.canUseHome &&
          loc != _Routes.pending) {
        return _Routes.pending;
      }

      if (session.canUseHome &&
          !session.needsLanguage &&
          (loc == _Routes.language ||
              loc == _Routes.kyc ||
              loc == _Routes.pending ||
              loc == _Routes.deviceBlocked)) {
        return _Routes.home;
      }

      return null;
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
